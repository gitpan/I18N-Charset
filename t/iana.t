#!./perl
#
# iana.t - tests for Locale::Country
#

use I18N::Charset;
use Test::Simple tests => 24;

#================================================
# TESTS FOR iana routines
#================================================

my @aa;
#---- selection of examples which should all result in undef -----------
ok(!defined iana_charset_name(), 'no arg');
ok(!defined iana_charset_name(undef), 'undef argument');
ok(!defined iana_charset_name(""), 'empty argument');
ok(!defined iana_charset_name("junk"), 'junk argument');
ok(!defined iana_charset_name("None"), 'None argument');
ok(!defined iana_charset_name(\@aa), 'arrayref argument');     # illegal argument

 #---- some successful examples -----------------------------------------
ok(iana_charset_name("Windows-1-2-5-1") eq "windows-1251", 'windows-1-2-5-1');
ok(iana_charset_name("windows-1252") eq "windows-1252", 'windows-1252 eq');
ok(iana_charset_name("win-latin-1") eq "windows-1252", 'win-latin-1');
ok(iana_charset_name("windows-1252") ne "windows-1253", 'windows-1252 ne');
ok(iana_charset_name("windows-1253") eq "windows-1253", 'windows-1253');
ok(iana_charset_name("Shift_JIS") eq "Shift_JIS", '');
ok(iana_charset_name("sjis") eq "Shift_JIS", '');
ok(iana_charset_name("x-sjis") eq "Shift_JIS", '');
ok(iana_charset_name("x-x-sjis") eq "Shift_JIS", '');
ok(iana_charset_name("Unicode-2-0-utf-8") eq "UTF-8", '');

 #---- some aliasing examples -----------------------------------------
ok(!defined(I18N::Charset::add_iana_alias("alias1" => "junk")), 'add alias to junk');
ok(!defined iana_charset_name("alias1"), '');
ok(!defined iana_charset_name("junk"), '');

ok(I18N::Charset::add_iana_alias("alias2" => "Shift_JIS") eq "Shift_JIS", '');
ok(iana_charset_name("alias2") eq "Shift_JIS", '');

ok(I18N::Charset::add_iana_alias("alias3" => "sjis") eq "Shift_JIS", '');
ok(iana_charset_name("alias3") eq "Shift_JIS", '');
ok(iana_charset_name("sjis") eq "Shift_JIS", '');

exit 0;

__END__
