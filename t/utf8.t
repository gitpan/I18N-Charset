#!perl -w

# utf8.t - tests for Unicode::MapUTF8 functionality of I18N::Charset


use I18N::Charset;
use Test::More;

unless (eval "require Unicode::MapUTF8")
  {
  plan skip_all => 'Unicode::MapUTF8 is not installed';
  } # unless

plan tests => 21;

# These should fail gracefully:
my @aa;
ok(!defined umu8_charset_name(), '');         # no argument
ok(!defined umu8_charset_name(undef), '');    # undef argument
ok(!defined umu8_charset_name(""), '');       # empty argument
ok(!defined umu8_charset_name("junk"), '');   # illegal code
ok(!defined umu8_charset_name(\@aa), '');     # illegal argument

SKIP:
  {
  skip 'Unicode::MapUTF8 version is too old (1.09 is good)', 16 unless eval '(1.08 < ($Unicode::MapUTF8::VERSION || 0))';

  # Plain old IANA names:
  ok(umu8_charset_name("Unicode-2-0-utf-8") eq "utf8", 'Unicode-2-0-utf-8');
  ok(umu8_charset_name("UCS-2") eq "ucs2", 'UCS-2');
  ok(umu8_charset_name("U.C.S. 4") eq "ucs4", 'U.C.S. 4');
 SKIP:
    {
    skip 'Unicode::Map is not installed', 2 unless eval 'require Unicode::Map';
    # Unicode::Map aliases:
    # Unicode::Map names with dummy mib:
    ok(umu8_charset_name("Adobe Ding Bats") eq "ADOBE-DINGBATS", 'Adobe Ding Bats');
    ok(umu8_charset_name("M.S. Turkish") eq "MS-TURKISH", 'M.S. Turkish');
    } # SKIP block for Unicode::Map8 module
 SKIP:
    {
    skip 'Unicode::Map8 is not installed', 7 unless eval 'require Unicode::Map8';
    # Unicode::Map8 aliases:
    ok(umu8_charset_name("Windows-1-2-5-1") eq "cp1251", 'windows-1-2-5-1');
    ok(umu8_charset_name("windows-1252") eq "cp1252", 'windows-1252 eq');
    ok(umu8_charset_name("win-latin-1") eq "cp1252", 'win-latin-1');
    ok(umu8_charset_name("windows-1252") ne "cp1253", 'windows-1252 ne');
    ok(umu8_charset_name("windows-1253") eq "cp1253", 'windows-1253');
    # Unicode::Map8 names with dummy mib:
    ok(umu8_charset_name("Adobe Zapf Ding Bats") eq "Adobe-Zapf-Dingbats", 'Adobe Zapf Ding Bats');
    ok(umu8_charset_name(" c p 1 0 0 7 9 ") eq "cp10079", ' c p 1 0 0 7 9 ');
    } # SKIP block for Unicode::Map8 module
 SKIP:
    {
    skip 'Jcode is not installed', 4 unless eval 'require Jcode';
    ok(umu8_charset_name("Shift_JIS") eq "sjis", 'Shift_JIS');
    ok(umu8_charset_name("sjis") eq "sjis", 'sjis');
    ok(umu8_charset_name("x-sjis") eq "sjis", 'x-sjis');
    ok(umu8_charset_name("x-x-sjis") eq "sjis", 'x-x-sjis');
    } # SKIP block for Jcode module
  } # SKIP block for VERSION of Unicode::Map8 module

exit 0;

my @as = &Unicode::MapUTF8::utf8_supported_charset();
@TESTS = map { 'defined iana_charset_name("'. $_ .'")' } @as;

plan tests => scalar(@TESTS);

foreach (@TESTS)
  {
  ok($_);
  } # foreach

exit 0;

__END__
