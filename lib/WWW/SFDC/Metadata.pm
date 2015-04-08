package WWW::SFDC::Metadata;

use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use Logging::Trivial;
use WWW::SFDC::SessionManager;

use Moo;
with "MooX::Singleton", "WWW::SFDC::Role::Session";

use SOAP::Lite;

=head1 NAME

WWW::SFDC::Metadata - Perl wrapper for the Salesforce.com Metadata API

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

 my $client = Sophos::sfdc->instance(creds => {
   username => 'foo',
   password => 'bar',
   url => 'https://login.salesforce.com'
 });

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

=cut

has 'pollInterval', is => 'rw', default => 20;
has 'apiVersion', is => 'ro', default => 33;

has 'uri',
  is => 'ro',
  default => "http://soap.sforce.com/2006/04/metadata";

sub _extractURL {
  return $_[1]->{metadataServerUrl};
}

=head1 METHODS

=head2 listMetadata @queries

Accepts a list of types and folders, such as

   {type => "CustomObject"},
   {type => "Report", folder => "FooReports"}

and generates a list of file names suitable for turning into a WWW::SFDC::Manifest.

=cut

sub listMetadata {

  my $self = shift; #remaining elements of @_ are queries;

  INFO "Listing Metadata...\t";

  my @result;
  my @queryData = map {SOAP::Data->new(name => "queries", value => $_)} @_;

  # listMetadata can only handle 3 requests at a time, so we chunk them.
  while (my @items = splice @queryData, 0, 3) {
    push @result, $$_{fileName} for $self->_call('listMetadata', @items);
  }

  return @result;
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


  return $self->_call(
    'retrieve',
    SOAP::Data->name(
      retrieveRequest => {
	# a lower value than 31 means no status is retrieved, causing an error.
	apiVersion => $self->apiVersion(),
	unpackaged => \SOAP::Data->value(@queryData)
      })
   )->{id};

}

# Uses the id to request a status update from SFDC, and returns
# undef unless there's something to give back, in which case it
# returns the base64 encoded zip file from the response.

sub _checkRetrieval {
  my ($self, $id) = @_;
  ERROR "No ID was passed in!" unless $id;

  my $result = $self->_call(
    'checkRetrieveStatus',
    SOAP::Data->name("asyncProcessId" => $id)
   );

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

  my $result = $self->_call(
    'checkDeployStatus',
    SOAP::Data->name("id" => $id),
    SOAP::Data->name("includeDetails" => "true")
   );

  INFO "Deployment status:\t".$$result{status};
  return 1 if $$result{status} eq "Succeeded";
  return undef if $$result{status} =~ /Queued|Pending|InProgress/;
  # useful deployment error here please
  ERROR "Check Deploy had an unexpected result: ".Dumper $result;
}

sub deployMetadata {
  my ($self, $zip, $deployOptions) = @_;

  my $result = $self->_call(
    'deploy',
    SOAP::Data->name( zipfile => $zip),
    ($deployOptions ? SOAP::Data->name(DeployOptions=>$deployOptions) : ())
   );

  INFO "Deployment status:\t".$$result{state};

  #do..until guarantees that sleep() executes at least once.
  do {sleep $self->pollInterval} until $self->_checkDeployment($$result{id});

  return $$result{id};

}

=head2 deployRecentValidation $id

Calls deployRecentValidation with your successfully-validated deployment.

=cut

sub deployRecentValidation {
  my ($self, $id) = @_;

  chomp $id;

  return $self->_call(
    'deployRecentValidation',
    SOAP::Data->name(validationID => $id)
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
