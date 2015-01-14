package WWW::SFDC::Metadata;

use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use Logging::Trivial;
use WWW::SFDC::Login;

use Moo;
with "MooX::Singleton";

use SOAP::Lite;
SOAP::Lite->import( +trace => [qw(debug)]) if DEBUG;

=head1 NAME

WWW::SFDC::Metadata - Perl wrapper for the Salesforce.com Metadata API

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 my $client = Sophos::sfdc->instance(
   username => 'foo',
   password => 'bar',
   url => 'https://login.salesforce.com'
 );

 my $manifest = $client->listMetadata(
   {type => "CustomObject"},
   {type => "Report", folder => "FooReports"}
 );

 my $base64zipstring = $client->retrieveMetadata(
   $manifest
 );

 $client->deployMetadata(
   $base64zipstring,
   {checkOnly => 'true'}
 );

For more in-depth examples, see t/WWW/SFDC/Metadata.t

=head1 PROPERTIES

=over 4

=item username

=item password

=item url

The Salesforce login url:

 - https://login.salesforce.com for a live environment
 - https://test.salesforce.com for a sandbox

NB the lack of a trailing slash.

=back

=cut

has 'apiVersion',
  is => 'ro',
  default => '31.0';

has 'username', is => 'ro';
has 'password', is => 'ro';
has 'url', is => 'ro', default => "http://test.salesforce.com";
has 'pollInterval', is => 'rw', default => 20;

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
    })->uri("http://soap.sforce.com/2006/04/metadata");
  };

has '_metadataClient',
  is => 'rw',
  lazy => 1,
  default => sub {
    my ($self) = @_;
    return SOAP::Lite->readable(1)->proxy(
      $self->_loginResult()->{"metadataServerUrl"}
     )->default_ns("http://soap.sforce.com/2006/04/metadata");
  };

=head1 METHODS

=head2 listMetadata @queries

Accepts a list of types and folders, such as

   {type => "CustomObject"},
   {type => "Report", folder => "FooReports"}

and generates a manifest structure suitable for passing into retrieveMetadata().

=cut

sub listMetadata {

  my $self = shift; #remaining elements of @_ are queries;

  INFO "Listing Metadata...\t";

  my %result;
  my @queryData = map {SOAP::Data->new(name => "queries", value => $_)} @_;

  # listMetadata can only handle 3 requests at a time, so we chunk them.
  while (my @items = splice @queryData, 0, 3) {

    my $req = $self->_metadataClient()->call(
      'listMetadata',
      @items,
      $self->_sessionHeader()
     );

    DEBUG "listMetadata request" => $req;
    ERROR "List Metadata Failed: " . $req->faultstring if $req->fault;

    push @{ $result{$$_{type}} }, $$_{fullName}
      for $req->paramsout(), $req->result();
  }

  return \%result;
}



=head2 retrieveMetadata $manifest

Sets up a retrieval from then checks it until done. Returns the
same data as checkRetrieval. Requires a manifest of the form:

 my $manifest = {
   "ApexClass" => ["MyApexClass"],
   "CustomObject" => ["*", "Account", "User", 'Opportunity"],
   "Profile" => ["*"]
  };

=cut

# Sets up an asynchronous metadata retrieval request and
# returns just the id, for checking later. Accepts a manifest.

sub _startRetrieval {
  INFO "Starting retrieval\n";

  my ($self, $manifest) = @_;

  ERROR "For a retrieval the API version must be 31 or greater" if $self->apiVersion < 31;

  # These maps basically preserve the structure passed in,
  # translating it to salesforce's special package.xml structure.
  my @queryData = map {
    SOAP::Data->name (
      types => \SOAP::Data->value(
	map {SOAP::Data->name(members => $_) } @{ $$manifest{$_} },
	SOAP::Data->name(name => $_ )
       )
     )
    } keys %$manifest;


  my $request = $self->_metadataClient()->call(
    'retrieve',
    SOAP::Data->name(
      retrieveRequest => {
	# a lower value than 31 means no status is retrieved, causing an error.
	apiVersion => $self->apiVersion(),
	unpackaged => \SOAP::Data->value(@queryData)
      }),
    $self->_sessionHeader()
   );

  DEBUG "Retrieve metadata request" => $request;
  ERROR "Retrieve Metadata Failed: ".$request->faultstring if $request->fault;
  return $request->result()->{id};
}

# Uses the id to request a status update from SFDC, and returns
# undef unless there's something to give back, in which case it
# returns the base64 encoded zip file from the response.

sub _checkRetrieval {
  my ($self, $id) = @_;
  ERROR "No ID was passed in!" unless $id;

  my $request = $self->_metadataClient()->call(
    'checkRetrieveStatus',
    SOAP::Data->name("asyncProcessId" => $id),
    $self->_sessionHeader()
   );

  ERROR "Check Retrieve Failed: ". $request->faultstring if $request->fault;
  my $result = $request->result();
  INFO "Status:" . $$result{status};

  return $result->{zipFile} if $$result{status} eq "Succeeded";
  return undef if $$result{status} =~ /Pending|InProgress/;
  ERROR "Check Retrieve had an unexpected result: ".$$result{message};
}


sub retrieveMetadata {

  my ($self, $manifest) = @_;
  ERROR "This method must be called with a manifest" unless $manifest;

  my $requestId = $self->_startRetrieval($manifest);

  my $result;

  do { sleep $self->pollInterval } until $result = $self->_checkRetrieval($requestId);

  return $result;
}



=head2 deployMetadata $zipString, \%deployOptions

Takes a base64 zip file and deploys it. Deploy options will be
passed verbatim into the request; see the metadata developer
guide for a description.

=cut

#Check up on an async deployment request. Returns 1 when complete.
sub _checkDeployment {
  my ($self, $id) = @_;
  ERROR "No ID was passed in" unless $id;

  my $request = $self->_metadataClient()->call(
    'checkDeployStatus',
    SOAP::Data->name("id" => $id),
    SOAP::Data->name("includeDetails" => "true"),
    $self->_sessionHeader()
   );

  DEBUG "Deploy request" => $request;
  ERROR "Check Deploy Failed: ". $request->faultstring if $request->fault;
  my $result = $request->result();
  INFO "Deployment status:\t".$$result{status};
  return 1 if $$result{status} eq "Succeeded";
  return undef if $$result{status} =~ /Queued|Pending|InProgress/;
  # useful deployment error here please
  ERROR "Check Deploy had an unexpected result: ".Dumper $result;
}

sub deployMetadata {
  my ($self, $zip, $deployOptions) = @_;

  my $options = SOAP::Data->name(DeployOptions=>$deployOptions) if $deployOptions;
  my $request = $self->_metadataClient()->call(
    'deploy',
    SOAP::Data->name( zipfile => $zip),
    $options,
    $self->_sessionHeader()
   );

  ERROR "Deploy Metadata Failed: ".$request->faultstring if $request->fault;
  my $result = $request->result();
  INFO "Deployment status:\t".$$result{state};

  #do..until guarantees that sleep() executes at least once.
  do {sleep $self->pollInterval} until $self->_checkDeployment($$result{id});

}

sub isSandbox {
  my $self = shift;
  return $self->_loginResult->{sandbox} eq  "true";
}

1;

__END__

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Metadata

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
