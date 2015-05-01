package WWW::SFDC::Role::Session;

use 5.12.0;
use strict;
use warnings;

use Moo::Role;

use WWW::SFDC::SessionManager;

=head1 NAME

WWW::SFDC::Role::Session - Provides a transparent interface to WWW::SFDC::SessionManager


=head1 VERSION

Version 0.1

=cut

our $version = '0.1';

=head1 SYNOPSIS

    package Example;
    use Moo;
    with "WWW::SFDC::Role::Session";

    sub _extractURL {
      # this is a required method. $_[0] is self, as normal.
      # $_[1] is the loginResult hash, which has a serverUrl as
      # well as a metadataServerUrl defined.
      return $_[1]->{serverUrl};
    }

    # uri is a required property, containing the default namespace
    # for the SOAP request.
    has 'uri', is => 'ro', default => 'urn:partner.soap.salesforce.com';

    sub doSomething {
      my $self = shift;
      # this uses the above-defined uri and url, and generates
      # a new sessionId upon an INVALID_SESSION_ID error:
      return $self->_call('method', @_);
    }

    1;

=cut

requires qw'_extractURL';

has 'creds',
  is => 'ro',
  trigger => sub {WWW::SFDC::SessionManager->instance(shift->creds())};

has 'url',
  is => 'ro',
  lazy => 1,
  builder => '_buildURL';

has 'pollInterval',
  is => 'rw',
  default => 15;

sub _buildURL {
  my $self = shift;
  return $self->_extractURL(WWW::SFDC::SessionManager->instance()->loginResult());
}

sub _call {
  my $self = shift;
  my $req = WWW::SFDC::SessionManager->instance()->call($self->url(), $self->uri(), @_);

  return $req->result(),
    (defined $req->paramsout() ? $req->paramsout() : ()),
    (defined $req->headers() ? $req->headers() : ());
}

sub _sleep {
  my $self = shift;
  sleep $self->pollInterval;
}

1;

__END__

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Role::Session

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
