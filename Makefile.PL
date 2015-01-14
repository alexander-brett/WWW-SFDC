use 5.12.0;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'WWW::SFDC',
    AUTHOR           => q{Alexander Brett <alex@alexander-brett.co.uk>},
    VERSION_FROM     => 'lib/WWW/SFDC.pm',
    ABSTRACT_FROM    => 'lib/WWW/SFDC.pm',
    LICENSE          => 'MIT',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.12.0,
    CONFIGURE_REQUIRES => {
      'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
      'File::Slurp' => 0,
      'Logging::Trivial' => 0,
      'Test::Exception' => 0,
      'Config::Properties' => 0,
      'Test::More' => 0,
    },
    PREREQ_PM => {
      'Logging::Trivial' => 0,
      'Moo' => 0,
      'MooX::Singleton' => 0,
      'SOAP::Lite' => 0,
      'XML::Parser' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'WWW-SFDC-*' },
);
