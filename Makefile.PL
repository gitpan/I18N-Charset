
# $Id: Makefile.PL,v 1.17 2008/06/29 02:12:37 Martin Exp $

use inc::Module::Install;

name('I18N-Charset');
all_from('lib/I18N/Charset.pm');

requires( perl => '5.004' );
recommends('App::Info::Lib::Iconv');
recommends('Encode');
test_requires('IO::Capture::Stderr' => 0);
requires('IO::String');
recommends('Jcode');
recommends('Unicode::Map');
recommends('Unicode::Map8');
recommends('Unicode::MapUTF8');
# Test::More is needed for `make test`:
test_requires('Test::More');
test_recommends('Test::Pod');
test_recommends('Test::Pod::Coverage');

WriteAll();

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

