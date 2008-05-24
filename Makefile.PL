
# $Id: Makefile.PL,v 1.16 2008/05/24 18:10:37 Martin Exp $

use inc::Module::Install;

name('I18N-Charset');
version_from('lib/I18N/Charset.pm');

author('Martin Thurn <mthurn@cpan.org>');
license('perl');

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

