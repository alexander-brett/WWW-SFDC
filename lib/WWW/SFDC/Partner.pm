package WWW::SFDC::Partner;

use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use Logging::Trivial;
use Scalar::Util 'blessed';
use WWW::SFDC::SessionManager;

use Moo;
with "MooX::Singleton", "WWW::SFDC::Role::Session";

use SOAP::Lite readable => 1;
SOAP::Lite->import( +trace => [qw(debug)]) if DEBUG;

=head1 NAME

WWW::SFDC::Partner - Wrapper around the Salesforce.com Partner API

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';


=head1 SYNOPSIS

    my @objects = WWW::SFDC::Partner->instance(creds => {
        username => "foo",
        password => "bar",
        url      => "url",
    })->query("SELECT field, ID FROM Object__c WHERE conditions");

    WWW::SFDC::Partner->instance()->update(
        map { $_->{field} =~ s/baz/bat/ } @objects
    );

=cut

has 'pollInterval',
  is => 'rw',
  default => 10;

has 'uri',
  is => 'ro',
  default => "urn:partner.soap.sforce.com";

sub _extractURL { return $_[1]->{serverUrl} }

=head2 query

    say $_->{Id} for WWW::SFDC::Partner->instance()->query($queryString);

=cut

sub query {
  my ($self, $query) = @_;
  INFO "Executing SOQL query: ".$query;

  my $result = $self->_call(
    'query',
    SOAP::Data->name(queryString => $query),
);

  return ref $result->{records} eq 'ARRAY'
    ? map {$self->_cleanUpSObject($_)} @{$result->{records}}
    : ( $self->_cleanUpSObject($result->{records}) );
}

sub _cleanUpSObject {
  my ($self, $obj) = @_;
  return () unless $obj;
  my %copy = %$obj; # strip the class from $obj
  $copy{Id} = $copy{Id}->[0] if ref $copy{Id} eq "ARRAY";
  return \%copy;
}

=head2 create

    say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->update(
      {type => 'thing', Id => 'foo', Field__c => 'bar', Name => 'baz'}
      {type => 'otherthing', Id => 'bam', Field__c => 'bas', Name => 'bat'}
    );

=cut

sub _prepareSObjects {
  my $self = shift;
  # prepares an array of objects for an update or insert call by converting
  # it to an array of SOAP::Data

  DEBUG "objects for operation" => @_;

  return map {
      my $obj = $_;
      my @type;
      if ($obj->{type}) {
        @type = SOAP::Data->name('type' => $obj->{type});
        delete $obj->{type};
      }

      SOAP::Data->name(sObjects => \SOAP::Data->value(
        @type,
        map {
          (blessed ($obj->{$_}) and blessed ($obj->{$_}) eq 'SOAP::Data')
            ? $obj->{$_}
            : SOAP::Data->name($_ => $obj->{$_})
        } keys $obj
      ))
    } @_;
}


sub create {
  my $self = shift;

  return $self->_call(
    'create',
    $self->_prepareSObjects(@_)
   );
}

=head2 update

    say "$$_{id}:\t$$_{success}" for WWW::SFDC::Partner->instance()->update(
      {type => 'thing', Id => 'foo', Field__c => 'bar', Name => 'baz'}
      {type => 'otherthing', Id => 'bam', Field__c => 'bas', Name => 'bat'}
    );

Returns an array that looks like [{success => 1, id => 'id'}, {}...] with LOWERCASE keys.

=cut

sub update {
  my $self = shift;

  DEBUG "Objects for update" => @_;
  INFO "Updating objects";

  return $self->_call(
    'update',
    $self->_prepareSObjects(@_)
   );
}

=head2 setPassword

    WWW::SFDC::Partner->instance()->setPassword(Id=>$ID, Password=$newPassword);

=cut

sub setPassword {
  my ($self, %params) = @_;
  ERROR "You must provide an Id and Password" unless $params{Id} and $params{Password};
  INFO "Setting password for user $params{Id}";
  return $self->_call(
    'setPassword',
    SOAP::Data->name(userID => $params{Id}),
    SOAP::Data->name(password => $params{Password}),
   );
}

1;

__END__

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Partner

You can also look for information at L<https://github.com/alexander-brett/WWW-SFDC>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Alexander Brett.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


=cut
