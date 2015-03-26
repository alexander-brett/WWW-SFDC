package WWW::SFDC::Manifest;

use 5.12.0;
use strict;
use warnings;

use XML::Parser;
use Scalar::Util qw(blessed);
use List::Util qw'first reduce pairmap pairgrep pairfirst';
use Data::Dumper;
use Logging::Trivial;
use WWW::SFDC::Constants qw(needsMetaFile hasFolders getEnding getDiskName getName);

use Moo;

has 'manifest', is => 'rw', default => sub { {} };
has 'isDeletion', is => 'ro';
has 'srcDir', is => 'rw', default => 'src';
has 'apiVersion', is => 'rw', default => 33;

=head1 NAME

WWW::SFDC::Manifest - utility functions for Salesforce Metadata API interactions

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

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

=cut

# _splitLine($line)

# Takes a string representing a file on disk, such as "email/foo/bar.email-meta.xml",
# and returns a hash containing the metadata type, folder name, file name, and
# file extension, excluding -meta.xml.

sub _splitLine {
  my ($self, $line) = @_;

  ERROR "No line!" unless $line;

  # clean up the line
  $line =~ s/.*src\///;
  $line =~ s/[\n\r]//g;

  my %result = ("extension" => "");

  ($result{"type"}) = $line =~ /^(\w+)\// or ERROR "Line $line doesn't have a type.";
  $result{"folder"} = $1 if $line =~ /\/(\w+)\//;

  my $extension = getEnding($result{"type"});

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

# _getFilesForLine($line)

# Takes a string representing a file on disk, such as "email/foo/bar.email",
# and returns a list representing all the files needed in the zip file for
# that file to be successfully deployed, for example:

# - email/foo-meta.xml
# - email/foo/bar.email
# - email/foo/bar.email-meta.xml

sub _getFilesForLine {
  my ($self, $line) = @_;

  return () unless $line;

  my %split = %{$self->_splitLine($line)};

  return map {"$split{type}/$_"} (
    $split{"folder"}
    ?(
      "$split{folder}-meta.xml",
      "$split{folder}/$split{name}$split{extension}",
      (needsMetaFile($split{"type"}) ? "$split{folder}/$split{name}$split{extension}-meta.xml" : ())
     )
    :(
      "$split{name}$split{extension}",
      (needsMetaFile($split{"type"}) ? "$split{name}$split{extension}-meta.xml" : ())
     )
   )
}


# _dedupe($listref)

# Returns a list reference to a _deduped version of the list
# reference passed in.

sub _dedupe {
  my ($self) = @_;
  my %result;
  for my $key (keys %{$self->manifest}) {
    my %_deduped = map {$_ => 1} @{$self->manifest->{$key}};
    $result{$key} = [sort keys %_deduped];
  }
  $self->manifest(\%result);
  return $self;
}

=back

=head1 METHODS

=over 4

=item getFileList(@list)

Returns a list of files needed to deploy this manifest. Use this to construct
a .zip file.

=cut

sub getFileList {
  my $self = shift;

  return map {
    my $type = getDiskName($_);
    my $ending = getEnding($type) || "";

    map {
      if (hasFolders($type) and $_ !~ /\//) {
	"$type/$_-meta.xml";
      } else {
	"$type/$_$ending", (needsMetaFile($type) ? "$type/$_$ending-meta.xml" : () );
      }
    } @{ $self->manifest->{$_} }
  } keys %{$self->manifest};
}

=item add($manifest)

Adds an existing manifest object or hash to this one.

=cut

sub add {
  my ($self, $new) = @_;

  if (defined blessed $new and blessed $new eq blessed $self) {
    push @{$self->manifest->{$_}}, @{$new->manifest->{$_}} for keys %{$new->manifest};
  } else {
    push @{$self->manifest->{$_}}, @{$new->{$_}} for keys %$new;
  }

  return $self->_dedupe();
}

=item addList($isDeletion, @list)

Adds a list of components or file paths to the manifest file.

=cut

sub addList {
  my $self = shift;

  return reduce {$a->add($b)} $self, map {
    DEBUG "adding..." => $_;
    +{ getName($$_{type}) => [
      defined $$_{folder}
      ? (($self->isDeletion ? () : $$_{folder}), "$$_{folder}/$$_{name}")
      : ($$_{name})
     ]}
  } map {$self->_splitLine($_)} @_;
}

=item readFromFile $location

Reads a salesforce package manifest and adds it to the current object, then
returns it.

=cut

sub readFromFile {
  my ($self, $fileName) = @_;

  return reduce {$a->add($b)} $self, map {+{
    do {
      pairmap {$b->[2]} pairfirst {$a eq 'name'} @$_
    } => [
      pairmap {$b->[2]} pairgrep {$a eq 'members'} @$_
     ]
  }}
    pairmap {[splice @{$b}, 1]} pairgrep {$a eq 'types'}
    splice @{
      XML::Parser->new(Style=>"Tree")->parsefile($fileName)->[1]
      }, 1;
}

=item writeToFile $location

Writes the manifest's XML representation to the given file and returns
the manifest object.

=cut

sub writeToFile {
  my ($self, $fileName) = @_;
  open my $fh, ">", $fileName;
  print $fh $self->getXML();
  return $self;
}

=item getXML($mapref)

Returns the XML representation for this manifest.

=cut

sub getXML {
  my ($self) = @_;
  return join "", (
    "<?xml version='1.0' encoding='UTF-8'?>",
    "<Package xmlns='http://soap.sforce.com/2006/04/metadata'>",
    (
      map {(
	"<types>",
	"<name>$_</name>",
	( map {"<members>$_</members>"} @{$self->manifest->{$_}} ),
	"</types>",
       )} sort keys %{$self->manifest}
     ),
    "<version>",$self->apiVersion,"</version></Package>"
   );
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
