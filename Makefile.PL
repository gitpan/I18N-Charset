
# $Id: Makefile.PL,v 1.19 2011-11-01 01:08:56 Martin Exp $

use inc::Module::Install;

my $sFnamePM = q{lib/I18N/Charset.pm};
all_from($sFnamePM);

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
recommends('Test::Pod');
recommends('Test::Pod::Coverage');

WriteAll();

sub MY::postamble
  {
  my $ret = <<'PART0';
coverage :
	$(MAKE) HARNESS_PERL_SWITCHES=-MDevel::Cover coverage_slave
coverage_slave : test
	cover
PART0
  my $sFnameIANA = q{IANA-docs/character-sets};
  if (-f $sFnameIANA)
    {
    # This must be the author's environment
    $ret .= <<"PART1";

CHARSETPM = $sFnamePM
IANA = $sFnameIANA

prep : \$(CHARSETPM)
\$(CHARSETPM) : \$(IANA)
	\$(FULLPERL) prep.pl \$(IANA) \$@
PART1
    } # if
  return $ret;
  } # MY::postamble

__END__

