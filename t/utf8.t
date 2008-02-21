# $Id: utf8.t,v 1.10 2008/02/21 03:33:06 Daddy Exp $
# utf8.t - tests for Unicode::MapUTF8 functionality of I18N::Charset

use strict;

use Test::More 'no_plan';

BEGIN { use_ok('I18N::Charset') };

# These should fail gracefully:
my @aa;
ok(!defined umu8_charset_name(), q{});         # no argument
ok(!defined umu8_charset_name(undef), q{});    # undef argument
ok(!defined umu8_charset_name(q{}), q{});      # empty argument
ok(!defined umu8_charset_name('junk'), q{});   # illegal code
ok(!defined umu8_charset_name(\@aa), q{});     # illegal argument

SKIP:
  {
  skip 'Unicode::MapUTF8 is not installed', 16 unless eval 'require Unicode::MapUTF8';

 SKIP:
    {
    skip 'Unicode::MapUTF8 version is too old (1.09 is good)', 16 unless eval '(1.08 < ($Unicode::MapUTF8::VERSION || 0))';

    # Plain old IANA names:
    is(umu8_charset_name('Unicode-2-0-utf-8'), 'utf8', 'Unicode-2-0-utf-8');
    is(umu8_charset_name('UCS-2'), 'ucs2', 'UCS-2');
    is(umu8_charset_name('U.C.S. 4'), 'ucs4', 'U.C.S. 4');
 SKIP:
      {
      skip 'Unicode::Map is not installed', 2 unless eval 'require Unicode::Map';
      # Unicode::Map aliases:
      # Unicode::Map names with dummy mib:
      is(umu8_charset_name('Adobe Ding Bats'), 'ADOBE-DINGBATS', 'Adobe Ding Bats');
      is(umu8_charset_name('M.S. Turkish'), 'MS-TURKISH', 'M.S. Turkish');
      } # SKIP block for Unicode::Map8 module
 SKIP:
      {
      skip 'Unicode::Map8 is not installed', 7 unless eval 'require Unicode::Map8';
      # Unicode::Map8 aliases:
      is(umu8_charset_name('Windows-1-2-5-1'), 'cp1251', 'windows-1-2-5-1');
      is(umu8_charset_name('windows-1252'), 'cp1252', 'windows-1252 eq');
      is(umu8_charset_name('win-latin-1'), 'cp1252', 'win-latin-1');
      isnt(umu8_charset_name('windows-1252'), 'cp1253', 'windows-1252 ne');
      is(umu8_charset_name('windows-1253'), 'cp1253', 'windows-1253');
      # Unicode::Map8 names with dummy mib:
      is(umu8_charset_name('Adobe Zapf Ding Bats'), 'Adobe-Zapf-Dingbats', 'Adobe Zapf Ding Bats');
      is(umu8_charset_name(' c p 1 0 0 7 9 '), 'cp10079', ' c p 1 0 0 7 9 ');
      } # SKIP block for Unicode::Map8 module
 SKIP:
      {
      skip 'Jcode is not installed', 4 unless eval 'require Jcode';
      is(umu8_charset_name('Shift_JIS'), 'sjis', 'Shift_JIS');
      is(umu8_charset_name('sjis'), 'sjis', 'sjis');
      is(umu8_charset_name('x-sjis'), 'sjis', 'x-sjis');
      is(umu8_charset_name('x-x-sjis'), 'sjis', 'x-x-sjis');
      } # SKIP block for Jcode module
    } # SKIP block for VERSION of Unicode::MapUTF8 module
  } # SKIP block for existence of Unicode::MapUTF8 module

exit 0;

__END__

