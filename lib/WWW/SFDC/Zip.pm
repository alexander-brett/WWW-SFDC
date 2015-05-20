package WWW::SFDC::Zip;

use 5.12.0;
use strict;
use warnings;

use Data::Dumper;
use File::Path qw(mkpath);
use File::Spec::Functions qw(splitpath);
use IO::Compress::Zip qw{$ZipError zip :constants};
use IO::File;
use IO::Uncompress::Unzip qw($UnzipError);
use Log::Log4perl ':easy';
use MIME::Base64;

=head1 NAME

WWW::SFDC::Zip - Utilities for manipulating base64 encoded zip files.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use WWW::SFDC::Zip qw"unzip makezip";

    makezip $srcDirectory, @listOfFiles;

    unzip $destDirectory, $base64encodedzipfile, &unzipTimeChanges

=head1 EXPORT

Can export unzip and makezip.

=cut

BEGIN {
  use Exporter;
  our @ISA = qw(Exporter);
  our @EXPORT_OK = qw(unzip makezip);
}

=head1 SUBROUTINES

=head2 unzip $destFolder, $dataString, $callback

Takes a some base64 $data and turns it into a file tree, starting
at $dest. It does this by turning unpackaged/ into $dest/ whilst
unzipping, so the data needs to come from an above-defined retrieve
request.

Whilst each file is in memory, this function calls:

 $callback->($filename, $content)

In this way, you can use $calback to modify or remove files before
they get written to disk.

=cut

sub unzip {
  # you need to understand IO::Uncompress::unzip
  # for this function
  my ($dest, $data, $callback) = @_;
  INFO "Unzipping files to $dest";
  DEBUG "Data to unzip" => $data;
  LOGDIE "No destination!" unless $dest;

  $data = decode_base64 $data;
  my $unzipper = IO::Uncompress::Unzip->new(\$data)
    or LOGDIE "Couldn't unzip data";

  my $status;

  do {
    my $header = $unzipper->getHeaderInfo();
    my (undef, $folder, $name) = splitpath($header->{Name});
    $folder =~ s/unpackaged/$dest/;

    # create folder on disk unless it exists already
    mkpath($folder) or LOGDIE "Couldn't mkdir $folder: $!" unless -d $folder;

    # skip if the file is a folder, exit on error
    $status < 0 ? last : next if $name =~ /\/$/;

    # read content into memory
    my $buffer;
    my $content;
    $content .= $buffer while ($status = $unzipper->read($buffer)) > 0;
    my $path = "$folder/$name";

    # use callback, if defined
    $content = $callback->($path, $content) if $callback;

    if ($content) {
      # open target for writing
      my $fh = IO::File->new($path, "w") or LOGDIE "Couldn't write to $path: $!";
      $fh->binmode();
      $fh->write($content);
      $fh->close();
      # update time on target
      my $stored_time = $header->{'Time'};
      utime ($stored_time, $stored_time, $path) or LOGDIE "Couldn't touch $path: $!";
    }
  } until ($status = $unzipper->nextStream()) < 1;

  return "Success";
}

=head2 makezip \%options, @fileList

Creates and returns a zip stream from the file list
given. Replaces unpackaged/ with $options{basedir} if set.

=cut

sub makezip {
  my ($baseDir, @files) = @_;

  TRACE "File list before grep: " . Dumper \@files;
  LOGDIE "It is invalid to call makezip with no files." unless scalar @files;

  $baseDir =~ s{(?<![/\\])$}{/};

  @files = grep {-e $_ && !-d $_}
    map {$baseDir.$_}
    @files;

  DEBUG "File list for zipping: " . Dumper \@files;
  INFO "Writing zip file with ". scalar(@files) ." files";

  my $result;

  zip
    \@files => \$result,
    FilterName => sub { s/$baseDir// if $baseDir; },
    Level => 9,
    Minimal => 1,
    BinModeIn => 1,
    or LOGDIE "zip failed: $ZipError";

  eval {
    open my $FH, '>', 'data_perl.zip' or die;
    binmode $FH;
    print $FH $result;
    close $FH;
  };

  return encode_base64 $result;
}

1;

__END__

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC::Zip

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
