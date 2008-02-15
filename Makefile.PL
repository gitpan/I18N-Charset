
# $Id: Makefile.PL,v 1.15 2007/11/24 03:10:48 Daddy Exp $

use inc::Module::Install;

name('I18N-Charset');
version_from('lib/I18N/Charset.pm');

author('Martin Thurn <mthurn@cpan.org>');
license('perl');

requires( perl => '5.004' );
recommends('App::Info::Lib::Iconv');
recommends('Encode');
build_requires('IO::Capture::Stderr' => 0);
requires('IO::String');
recommends('Jcode');
recommends('Unicode::Map');
recommends('Unicode::Map8');
recommends('Unicode::MapUTF8');
# Test::More is needed for `make test`:
build_requires('Test::More');
recommends('Test::Pod');
recommends('Test::Pod::Coverage');

&WriteAll;

sub MY::postamble
  {
  my $ret = <<'PART0';
coverage :
	$(MAKE) HARNESS_PERL_SWITCHES=-MDevel::Cover coverage_slave
coverage_slave : test
	cover
PART0
  return $ret;
  } # MY::postamble

__END__

