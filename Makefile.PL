# Makefile.PL for I18N-Charset distribution
#
# Filename:	Makefile.PL
# Author:	Martin Thurn
# Created:	1998-07-14

use ExtUtils::MakeMaker;

&WriteMakefile(
               NAME         => 'I18N::Charset',
               VERSION_FROM => 'lib/I18N/Charset.pm',
               PREREQ_PM => {
                             App::Info::Lib::Iconv => 0,
                             IO::String => 0,
                             Test::Simple => 0,
                             Test::More => 0,
                            },
              );

# Th-th-th-that's all, folks!
