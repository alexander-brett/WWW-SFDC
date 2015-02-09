package WWW::SFDC::Tooling;

use 5.12.0;
use strict;
use warnings;

use Logging::Trivial;
use WWW::SFDC::SessionManager;

use Moo;
with 'MooX::Singleton', 'WWW::SFDC::Role::Session';

=head1 NAME

WWW::SFDC::Tooling - Wrapper around SFDC Tooling API

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

   my $result = SFDC::tooling->instance(creds => {
    username => $USER,
    password => $PASS,
    url => $URL
   })->executeAnonymous("System.debug(1);");

Note that $URL is the _login_ URL, not the Tooling API endpoint URL - which gets calculated internally.

=cut

has 'uri',
  is => 'ro',
  default => 'urn:tooling.soap.sforce.com';

sub _extractURL {
  return $_[1]->{serverUrl} =~ s{/u/}{/T/}r;
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
    SOAP::Data->name(string => $code)
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

  my $result = $self->_call(
    'query',
    SOAP::Data->name(queryString => $query)
   );

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
