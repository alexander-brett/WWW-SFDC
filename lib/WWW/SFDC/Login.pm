package WWW::SFDC::Login;

use 5.12.0;
use strict;

use Logging::Trivial;

use Moo;
with 'MooX::Singleton';

use SOAP::Lite ;
SOAP::Lite->import( +trace => [qw(debug)]) if DEBUG;

=head1 NAME

WWW::SFDC::Login - Shared login class for Salesforce.com APIs

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    my $sessionId = WWW::SFDC::Login->instance({
        username => "foo",
        password => "bar",
        url      => "baz",
    })->loginResult()->{"sessionId"};

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES

=cut

has 'username',
  is => 'ro',
  required => 1;

has 'password',
  is => 'ro',
  required => 1;

has 'url',
  is => 'ro',
  required => 1,
  isa => sub { $_[0] =~ s/\/$// or 1; }, #remove trailing slash
  default => "http://test.salesforce.com";

has 'apiVersion',
  is => 'ro',
  isa => sub { ERROR "The API version must be >= 31" unless $_[0] >= 31},
  default => '31.0';

has 'loginResult',
  is => 'rw',
  lazy => 1,
  builder => '_login';

sub _login {
  my ($self) = @_;

  INFO "Logging in...\t";

  $SOAP::Constants::PATCH_HTTP_KEEPALIVE=1;
  my $request = SOAP::Lite
    ->proxy($self->url()."/services/Soap/u/".$self->apiVersion())
    ->readable(1)
    ->ns("urn:partner.soap.sforce.com","urn")
    ->call(
      'login',
      SOAP::Data->name("username")->value($self->username()),
      SOAP::Data->name("password")->value($self->password())
     );

  DEBUG "request" => $request;
  ERROR "Login Failed: ".$request->faultstring if $request->fault;
  return $request->result();
}

1;

__END__

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Login

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
