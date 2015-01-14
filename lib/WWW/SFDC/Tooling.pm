package WWW::SFDC::Tooling;

use 5.12.0;
use strict;
use warnings;

use Logging::Trivial;
use WWW::SFDC::Login;

use Moo;
with 'MooX::Singleton';

use SOAP::Lite readable => 1;
SOAP::Lite->import( +trace => [qw(debug)]);# if DEBUG;

=head1 NAME

WWW::SFDC::Tooling - Wrapper around SFDC Tooling API

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

   my $result = SFDC::tooling->instance(
    username => "bar",
    password => "baz",
    url => "url"
   )->executeAnonymous("System.debug(1);");

=cut

has 'apiVersion',
  is => 'ro',
  isa => sub { ERROR "The API version must be >= 31" unless $_[0] >= 31},
  default => '31.0';

has 'username', is => 'ro';

has 'password', is => 'ro';

has 'url', is => 'ro', default => "http://test.salesforce.com"; #remove trailing slash

has 'pollInterval',
  is => 'rw',
  default => 10;

has '_loginResult',
  is => 'ro',
  lazy => 1,
  default => sub {
    my $self = shift;
    WWW::SFDC::Login->instance(
      username => $self->username,
      password => $self->password,
      url      => $self->url,
      apiVersion => $self->apiVersion,
     )->loginResult();
   };

has '_sessionHeader',
  is => 'rw',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return SOAP::Header->name("SessionHeader" => {
      "sessionId" => $self->_loginResult()->{"sessionId"}
    })->uri("urn:tooling.soap.sforce.com");
  };

has '_toolingClient',
  is => 'rw',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my $endpoint = $self->_loginResult()->{"serverUrl"};
    $endpoint =~ s{/u/}{/T/};

    return SOAP::Lite->readable(1)
      ->proxy($endpoint)
      ->default_ns("urn:tooling.soap.sforce.com");
  };

sub _call {
  my ($self, @stuff) = @_;
  my $req = $self->_toolingClient()->call(@stuff, $self->_sessionHeader());

  DETAIL "Operation request" => $req;
  ERROR "$stuff[0] Failed: " . $req->faultstring if $req->fault;

  return defined $req->paramsout() ? ($req->result(),$req->paramsout()): $req->result();
}

=head1 METHODS

=head2 create

=cut

sub create {
  ...
}

=head2 delete

=cut

sub delete {
  ...
}

=head2 describeGlobal

=cut

sub describeGlobal {
  ...
}

=head2 describeSObjects

=cut

sub describeSObjects {
  ...
}

=head2 executeAnonymous

    WWW::SFDC::Tooling->instance()->executeAnonymous("system.debug(1);")

=cut

sub executeAnonymous {
  my ($self, $code) = @_;
  my $result = $self->_call(
    'executeAnonymous',
    SOAP::Data->name(string => $code),
    $self->_sessionHeader
   );

  ERROR "ExecuteAnonymous failed to compile: " . $result->{compileProblem}
    if $result->{compiled} eq "false";

  ERROR "ExecuteAnonymous failed to complete: " . $result->{exceptionMessage}
    if $result->{success} eq "false";

  return $result;
}

=head2 query

=cut

sub query {
  my ($self, $query) = @_;
  INFO "Executing SOQL query: ".$query;

  my $result = $self->_call('query', SOAP::Data->name(queryString => $query));

  return map {my %copy = %$_; \%copy; }
    ref $result->{records} eq 'ARRAY' ? @{$result->{records}} : $result->{records}
    if defined $result->{records};

  return undef;
}

=head2 retrieve

=cut

sub retrieve {
  ...
}

=head2 runTests

=cut

sub runTests {
  ...
}

=head2 runTestsAsynchronous

=cut

sub runTestsAsynchronous {
  my ($self, @ids) = @_;

  return $self->_call('runTestsAsynchronous', join ",", @ids);
}

=head2 update

=cut

sub update {
  ...
}

=head2 upsert

=cut

sub upsert {
 ...
}

1;

__END__

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Tooling

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

1; # End of WWW::SFDC::Tooling
