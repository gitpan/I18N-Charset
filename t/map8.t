#!./perl
#
# map8.t - tests for Unicode::Map8 functionality of I18N::Charset
#

use I18N::Charset;
use Test::More;

if (eval "require Unicode::Map8")
  {
  plan tests => 23;
  }
else
  {
  plan skip_all => 'Unicode::Map8 is not installed';
  } # unless


#================================================
# TESTS FOR map8 routines
#================================================

my @aa;
#---- selection of examples which should all result in undef -----------
ok(!defined map8_charset_name(), '');         # no argument
ok(!defined map8_charset_name(undef), '');    # undef argument
ok(!defined map8_charset_name(""), '');       # empty argument
ok(!defined map8_charset_name("junk"), '');   # illegal code
ok(!defined map8_charset_name(\@aa), '');     # illegal argument

#---- some successful examples -----------------------------------------
ok(map8_charset_name("ASMO_449")          eq "ASMO_449", '');
ok(map8_charset_name("ISO_9036")          eq "ASMO_449", '');
ok(map8_charset_name("arabic7")          eq "ASMO_449", '');
ok(map8_charset_name("iso-ir-89")          eq "ASMO_449", '');
ok(map8_charset_name("ISO-IR-89")          eq "ASMO_449", '');
ok(map8_charset_name("ISO - ir _ 89")          eq "ASMO_449", '');

#---- an iana example that ONLY works with Unicode::Map8 installed -----
ok(iana_charset_name("cp1251")            eq "windows-1251", '');

#---- some aliasing examples -------------------------------------------
ok(!defined(I18N::Charset::add_map8_alias("alias1" => "junk")), '');
ok(!defined map8_charset_name("alias1"), '');

ok(I18N::Charset::add_map8_alias("alias2" => "ES2")      eq "ES2", '');
ok(map8_charset_name("alias2") eq "ES2", '');

ok(I18N::Charset::add_map8_alias("alias3" => "iso-ir-85") eq "ES2", '');
ok(map8_charset_name("alias3") eq "ES2", '');

ok(map8_charset_name("Ebcdic cp FI")       eq "IBM278", '');
ok(map8_charset_name("IBM278")             eq "IBM278", '');
ok(I18N::Charset::add_map8_alias("my278" => "IBM278") eq "IBM278", '');
ok(map8_charset_name("My 278")         eq "IBM278", '');
ok(map8_charset_name("cp278")          eq "IBM278", '');

exit 0;

__END__
