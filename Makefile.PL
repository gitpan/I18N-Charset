use inc::Module::Install;

name('I18N-Charset');
version_from('lib/I18N/Charset.pm');

author('Martin Thurn <mthurn@cpan.org>');
license('perl');

requires( perl => '5.004' );
requires('IO::String');
recommends('App::Info::Lib::Iconv');
recommends('Encode');
recommends('Unicode::Map');
recommends('Unicode::Map8');
recommends('Unicode::MapUTF8');

# Test::More is needed for `make test`:
include_deps('Test::More', 5.004);
build_requires('Test::More');

check_nmake();      # check and download nmake.exe for Win32
&Makefile->write;
