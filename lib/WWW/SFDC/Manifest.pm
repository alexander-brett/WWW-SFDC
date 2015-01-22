package WWW::SFDC::Manifest;

use 5.12.0;
use strict;
use warnings;

use XML::Parser;
use Scalar::Util qw(blessed);
use List::Util qw(first);
use Data::Dumper;
use Logging::Trivial;

use Moo;

has 'manifest', is => 'rw', default => sub { {} };
has 'isDeletion', is => 'ro';
has 'srcDir', is => 'rw', default => 'src';
has 'apiVersion', is => 'rw', default => 31;

=head1 NAME

WWW::SFDC::Manifest - utility functions for Salesforce Metadata API interactions

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

This module is used to read SFDC manifests from disk, add files to them,
and get a structure suitable for passing into WWW::SFDC::Metadata functions.

   my $Manifest = WWW::SFDC::Manifest
        ->new()
        ->readFromFile("filename")
        ->add(
            WWW::SFDC::Manifest->new()->readFromFile("anotherFile")
        )->add({Document => ["bar/foo.png"]});

   my $HashRef = $Manifest->manifest();
   my $XMLString = $Manifest->getXML();

=head1 CONFIG

These hashes store information about different metadata types.

=over 4

=item %needsMetaFile

Stores 1 if the given metadata type requires a metadata file, for example:
C<< bar() if $needsMetaFile{"foo"}; >>

=cut

my %needsMetaFile = map {$_ => 1} qw{
				      classes components  documents
				      email   pages   staticresources
				      triggers
				  };

my %hasFolders = map {$_ => 1} qw{
				   reports documents email
			       };

=item %getEnding

Stores the file ending for the metadata type, if there is one. For
instance, foo.png and foo.baz are both valid document file endings,
but a profile can only be called foo.profile, so
$getEnding{"documents"} = undef.

NB that two of these values are UNDEFINED because I don't know what
the value is.

The absence of a key from this hash indicates that that value is a
subcomponent, which is to say that the name is always everything
following the final /.

=cut

my %getEnding = (
  "applications"       => ".app",
  "approvalProcesses" => ".approvalProcess",
  "classes"            => ".cls",
  "components"         => ".component",
  "datacategorygroups" => "UNDEFINED",
  "documents"          => undef,
  "email"              => ".email",
  "flows"              => "UNDEFINED",
  "groups"             => ".group",
  "homePageComponents" => ".homePageComponent",
  "homePageLayouts"    => ".homePageLayout",
  "labels"             => ".labels",
  "layouts"            => ".layout",
  "objects"            => ".object",
  "pages"              => ".page",
  "permissionsets"     => ".permissionset",
  "portals"            => ".portal",
  "profiles"           => ".profile",
  "queues"             => ".queue",
  "quickActions"       => ".quickAction",
  "remoteSiteSettings" => ".remoteSite",
  "reportTypes"        => ".reportType",
  "reports"            => ".report",
  "sites"              => ".site",
  "staticresources"    => ".resource",
  "tabs"               => ".tab",
  "triggers"           => ".trigger",
  "weblinks"           => ".weblink",
  "workflows"          => ".workflow"
 );

=item %getName

Stores the metadata api name corresponding to the folder name on disk.
For instance, the metadata name corresponding to the applications/
folder is CustomApplication, but the name corresponding to flows/ is 
Flow.

=cut

my %getName = (
  "applications" => "CustomApplication",
  "approvalProcesses" => "ApprovalProcess",
  "classes" => "ApexClass",
  "components" => "ApexComponent",
  "datacategorygroups" => "DataCategoryGroup",
  "documents" => "Document",
  "email" => "EmailTemplate",
  "flows" => "Flow",
  "groups" => "Group",
  "homePageComponents" => "HomePageComponent",
  "homePageLayouts" => "HomePageLayout",
  "labels" => "CustomLabels",
  "layouts" => "Layout",
  "objects" => "CustomObject",
  "pages" => "ApexPage",
  "permissionsets" => "PermissionSet",
  "portals" => "Portal",
  "profiles" => "Profile",
  "queues" => "Queue",
  "quickActions" => "QuickAction",
  "remoteSiteSettings" => "RemoteSiteSetting",
  "reportTypes" => "ReportType",
  "reports" => "Report",
  "sites" => "CustomSite",
  "staticresources" => "StaticResource",
  "tabs" => "CustomTab",
  "triggers" => "ApexTrigger",
  "weblinks" => "CustomPageWebLink",
  "workflows" => "Workflow",
  #subcomponents
  "actionOverrides" => "ActionOverride",
  "alerts" => "WorkflowAlert",
  "businessProcesses" => "BusinessProcess",
  "fieldSets" => "FieldSet",
  "fieldUpdates" => "WorkflowFieldUpdate",
  "fields" => "CustomField",
  "listViews" => "ListView",
  "outboundMessages" => "WorkflowOutboundMessage",
  "recordTypes" => "RecordType",
  "rules" => "WorkflowRule",
  "tasks" => "WorkflowTask",
  "validationRules" => "ValidationRule",
  "webLinks" => "WebLink",
 );

sub _getDiskName {
  my ($self, $query) = @_;
  return first {$getName{$_} eq $query} keys %getName;
}

sub _getName {
  my ($query) = @_;
  return $getName{$query};
}

=back

=head1 METHODS

=over 4

=item splitLine($line)

Takes a string representing a file on disk, such as "email/foo/bar.email-meta.xml",
and returns a hash containing the metadata type, folder name, file name, and
file extension, excluding -meta.xml.

This takes into account the extensions defined above; for instance, for a document
called foo.png, the name is "foo.png" and the extension is "", because
$getName{document} is "*", whereas for an object called "foo.object", the name is "foo".

=cut

sub splitLine {
  my ($self,$line) = @_;

  ERROR "No line!" unless $line;

  # clean up the line
  $line =~ s/.*src\///;
  $line =~ s/[\n\r]//;

  my %result = ("extension" => "");

  ($result{"type"}) = $line =~ /^(\w+)\// or ERROR "Line $line doesn't have a type.";
  $result{"folder"} = $1 if $line =~ /\/(\w+)\//;

  my $extension = $getEnding{$result{"type"}};

  if ($line =~ /\/(\w+)-meta.xml/) {
    $result{"name"} = $1
  } elsif (!defined $extension) {
    ($result{"name"}) = $line =~ /\/([^\/]*?)(-meta\.xml)?$/;
    # This is because components get passed back from listDeletions with : replacing .
    $result{"name"} =~ s/:/./;
  } elsif ($line =~ /\/([^\/]*?)($extension)(-meta\.xml)?$/) {
    $result{"name"} = $1;
    $result{"extension"} = $2;
  }

  ERROR "Line $line doesn't have a name." unless $result{"name"};

  return \%result;
}

=item getFilesForLine($line)

Takes a string representing a file on disk, such as "email/foo/bar.email",
and returns a list representing all the files needed in the zip file for
that file to be successfully deployed, for example:

- email/foo-meta.xml
- email/foo/bar.email
- email/foo/bar.email-meta.xml

=cut

sub getFilesForLine {
  my ($self, $line) = @_;
  my @output = ();

  return unless $line;

  my %split = %{$self->splitLine($line)};

  if ($split{"folder"}) {
    push @output, "$split{type}/$split{folder}-meta.xml";
    push @output, "$split{type}/$split{folder}/$split{name}$split{extension}";

    push @output,
      "$split{type}/$split{folder}/$split{name}$split{extension}-meta.xml"
      if $needsMetaFile{$split{"type"}};

  } else {
    push @output, "$split{type}/$split{name}$split{extension}";

    push @output, "$split{type}/$split{name}$split{extension}-meta.xml"
      if $needsMetaFile{$split{"type"}};
  }

  return @output;
}

=item getFileList(@list)

Applies getFilesForLine to each item of the input and returns
the output, deduplicated.

=cut

sub getFileList {
  my $self = shift;
  my @result;
  for my $key (keys %{$self->manifest}) {
    my $type = $self->_getDiskName($key);
    my $ending = $getEnding{$type} || "";

    for my $value (@{ $self->manifest->{$key}}) {
      if ($hasFolders{$type} and $value !~ /\//) {
	push @result, "$type/$value-meta.xml";
      } else {
	push @result, "$type/$value$ending";
	push @result, "$type/$value$ending-meta.xml" if $needsMetaFile{$type};
      }
    }
  }
  return @result;
}

=item dedupe($listref)

Returns a list reference to a deduped version of the list
reference passed in.

=cut

sub dedupe {
  my ($self) = @_;
  my %result;
  for my $key (keys %{$self->manifest}) {
    my %deduped = map {$_ => 1} @{$self->manifest->{$key}};
    $result{$key} = [sort keys %deduped];
  }
  $self->manifest(\%result);
  return $self;
}

=item add($manifest)

=cut

sub add {
  my ($self, $new) = @_;

  my %result;

  if (defined blessed $new and blessed $new eq blessed $self) {
    push @{$self->manifest->{$_}}, @{$new->manifest->{$_}} for keys %{$new->manifest};
  } else {
    push @{$self->manifest->{$_}}, @{$new->{$_}} for keys %$new;
  }

  return $self->dedupe();
}

=item addList($isDeletion, @list)

Creates a list of components, sorted by type, suitable for turning
into a manifest file

=cut

sub addList {
  my ($self, @lines) = @_;
  my %result = %{ $self->manifest };

  for (@lines) {
    my %split = %{$self->splitLine($_)};
    my $type = $getName{$split{type}} or warn "couldn't find a name for $split{type}";

    if ($split{folder}) {
      push @{$result{$type}}, $split{folder} unless $self->isDeletion;
      push @{$result{$type}}, "$split{folder}/$split{name}";
    } else {
      push @{$result{$type}}, $split{name};
    }
  }

  return $self->add(\%result);

}

=item readFromFile $location

Reads a salesforce package manifest and returns a hash
ready to be fed into Sophos::sfdc::retrieveMetadata.

=cut

sub readFromFile {
  my ($self, $fileName) = @_;

  my $root = XML::Parser->new(Style=>"Tree")->parsefile($fileName)->[1];
  my %result;

  do {
    my $node = $_;
    my ($name, @members);
    for (grep {$_%2} 0..$#$node) {
      $name = $node->[$_+1]->[2] if $node->[$_] eq 'name';
      push @members, $node->[$_+1]->[2] if $node->[$_] eq 'members';
    }
    push @{$result{$name}}, @members;
  } for map {$_->{value}} grep {$_->{key} eq 'types'}
    map {+{key => $root->[$_], value => $root->[$_+1]}} # split into key/value pairs
    grep {$_%2} 1..$#$root; # ignore first element

  $self->manifest(\%result);
  DEBUG "Manifest read from file" => $self->manifest;

  return $self;
}

=item writeToFile $location

Writes the manifest's xml representation to the given file.

=cut

sub writeToFile {
  my ($self, $fileName) = @_;
  open my $fh, ">", $fileName;
  print $fh $self->getXML();
  return $self;
}

=item getXML($mapref)

=cut

sub getXML {
  my ($self) = @_;
  my $result = "<?xml version='1.0' encoding='UTF-8'?>";
  $result .= "<Package xmlns='http://soap.sforce.com/2006/04/metadata'>";

  for my $key (sort keys %{$self->manifest}) {
    $result .= "<types>";
    $result .= "<name>$key</name>";
    $result .= "<members>$_</members>" for @{$self->manifest->{$key}};
    $result .= "</types>";
  }

  $result .= "<version>".$self->apiVersion."</version></Package>";
  return $result;
}


1;

__END__

=back

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Manifest

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
