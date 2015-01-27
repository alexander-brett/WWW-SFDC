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

sub _buildURL {
  my $self = shift;
  return $self->_extractURL(WWW::SFDC::SessionManager->instance()->loginResult());
}

sub _call {
  my $self = shift;

  my $req = WWW::SFDC::SessionManager->instance()->call($self->url(), $self->uri(), @_);

  return defined $req->paramsout() ? ($req->result(),$req->paramsout()): $req->result();
}

1;
