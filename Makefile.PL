#!/usr/bin/env perl

use ExtUtils::MakeMaker;

sub MY::postamble {
   package MY;
   "\npredist: all\n" .
#   "\tcvs2cl\n" .
   "\t\$(MAKE) manifest\n" .
   "\t\$(MAKE) tardist\n"
}

WriteMakefile(
   MAKEFILE => 'Makefile',
   VERSION_FROM => 'lib/Bryar/DataSource/SVNRepos.pm',
   NAME => 'Bryar::DataSource::SVNRepos',
   PREREQ_PM => {
      'SVN::Core' => '0',
      'Time::Piece' => '0',
      'Bryar' => '0.26',
   },
   dist => {
      COMPRESS     =>'gzip',
      SUFFIX       =>'gz',
      DIST_DEFAULT => 'predist',
   },
);
