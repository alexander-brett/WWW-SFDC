package WWW::SFDC;

1; # this is a documentation module

__END__

=head1 NAME

WWW::SFDC - Wrappers arount the Salesforce.com APIs.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

WWW::SFDC provides a set of packages which you can use to build useful
interactions with Salesforce.com's many APIs. Initially it was intended
for the construction of powerful and flexible deployment tools.

=head1 CONTENTS

 - WWW::SFDC::Login    - this is mainly an internal class for login caching.
 - WWW::SFDC::Manifest
 - WWW::SFDC::Metadata
 - WWW::SFDC::Partner
 - WWW::SFDC::Tooling
 - WWW::SFDC::Zip

=head1 METADATA API EXAMPLES

The following provides a starting point for a simple retrieval tool.
Notice that after the initial setup of WWW::SFDC::Metadata the login
credentials are cached. In this example, you'd use
_retrieveTimeMetadataChanges to remove files you didn't want to track,
change sandbox outbound message endpoints to production, or similar.

Notice that I've tried to keep the interface as fluent as possible in
all of these modules - every method which doesn't have an obvious
return value returns $self.

    package ExampleRetrieval;

    use WWW::SFDC::Metadata;
    use WWW::SFDC::Manifest;
    use WWW::SFDC::Zip qw'unzip';

    WWW::SFDC::Metadata->instance(
      password  => $password,
      username  => $username,
      url       => $url
    );

    my $manifest = WWW::SFDC::Manifest
      ->readFromFile($manifestFile)
      ->add(
        WWW::SFDC::Metadata
          ->instance()
          ->listMetadata(
            {type => 'Document', folder => 'Apps'},
            {type => 'Document', folder => 'Developer_Documents'},
            {type => 'EmailTemplate', folder => 'Asset'},
            {type => 'ApexClass'}
          )
      );

    unzip
      $destDir,
      WWW::SFDC::Metadata->instance()->retrieveMetadata($manifest->manifest()),
      \&_retrieveTimeMetadataChanges;

Here's a similar example for deployments. You'll want to construct
@filesToDeploy and $deployOptions context-sensitively!

     package ExampleDeployment;

     use WWW::SFDC::Metadata;
     use WWW::SFDC::Manifest;
     use WWW::SFDC::Zip qw'makezip';

     my $manifest = WWW::SFDC::Manifest
       ->new()
       ->addList(@filesToDeploy)
       ->writeToFile($srcDir.'package.xml');

     my $zip = makezip
       $srcDir,
       $manifest->getFileList(),
       'package.xml';

    my $deployOptions = {
       singlePackage => 'true',
       rollbackOnError => 'true',
       checkOnly => 'true'
    };

    WWW::SFDC::Metadata->instance(
     username=>$username,
     password=>$password,
     url=>$url
   )->deployMetadata $zip, $deployOptions;

=head1 PARTNER API EXAMPLE

To unsanitise some users' email address and change their profiles
on a new sandbox, you might do something like this:

    package ExampleUserSanitisation;

    use WWW::SFDC::Partner;
    use List::Util qw'first';

    WWW::SFDC::Partner->instance(
      username => $username,
      password => $password,
      url => $url
    );

    my @users = (
      {User => alexander.brett, Email => alex@example.com, Profile => $profileId},
      {User => another.user, Email => a.n.other@example.com, Profile => $profileId},
    );

    WWW::SFDC::Partner->instance()->update(
      map {
        my $row = $_;
        my $original = first {$row->{Username} =~ /$$_{User}/} @users;
        +{
           Id => $row->{Id},
           ProfileId => $original->{Profile},
           Email => $original->{Email},
        }
      } WWW::SFDC::Partner->instance()->query(
          "SELECT Id, Username FROM User WHERE "
          . (join " OR ", map {"Username LIKE '%$_%'"} map {$_->{User}} @inputUsers)
        )
    );

=head1 AUTHOR

Alexander Brett, C<< <alex at alexander-brett.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests at L<https://github.com/alexander-brett/WWW-SFDC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::SFDC
    perldoc WWW::SFDC::Metadata
    ...

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
