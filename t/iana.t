#!./perl
#
# iana.t - tests for Locale::Country
#

use I18N::Charset;

$I18N::Charset::verbose = $I18N::Charset::verbose = 1;

#-----------------------------------------------------------------------
# This is an array of tests. Each test is eval'd as an expression.
# If it evaluates to FALSE, then "not ok N" is printed for the test,
# otherwise "ok N".
#-----------------------------------------------------------------------
@TESTS =
(
	#================================================
	# TESTS FOR iana routines
	#================================================

 #---- selection of examples which should all result in undef -----------
 '!defined iana_charset_name()',         # no argument
 '!defined iana_charset_name(undef)',    # undef argument
 '!defined iana_charset_name("")',       # empty argument
 '!defined iana_charset_name("junk")',   # illegal code
 '!defined iana_charset_name("None")',   # "None" appears as an Alias
                                         # in the data but should be
                                         # ignored
 '!defined iana_charset_name(\@aa)',     # illegal argument

 #---- some successful examples -----------------------------------------
 'iana_charset_name("Windows-1-2-5-1")   eq "windows-1251"',
 'iana_charset_name("windows-1252")   eq "windows-1252"',
 'iana_charset_name("windows-1252")   ne "windows-1253"',
 'iana_charset_name("windows-1253")   eq "windows-1253"',
 'iana_charset_name("Shift_JIS")         eq "Shift_JIS"',
 'iana_charset_name("sjis")         eq "Shift_JIS"',
 'iana_charset_name("x-sjis")         eq "Shift_JIS"',
 'iana_charset_name("x-x-sjis")         eq "Shift_JIS"',
 'iana_charset_name("Unicode-2-0-utf-8") eq "UTF-8"',

 #---- some aliasing examples -----------------------------------------
 '!defined(I18N::Charset::add_iana_alias("alias1" => "junk"))',
 '!defined iana_charset_name("alias1")',

 'I18N::Charset::add_iana_alias("alias2" => "Shift_JIS") eq "Shift_JIS"',
 'iana_charset_name("alias2") eq "Shift_JIS"',

 'I18N::Charset::add_iana_alias("alias3" => "sjis")      eq "Shift_JIS"',
 'iana_charset_name("alias3") eq "Shift_JIS"',
 'iana_charset_name("sjis") eq "Shift_JIS"',

);

print "1..", int(@TESTS), "\n";

$testid = 1;
foreach $test (@TESTS)
{
    eval "print (($test) ? \"ok $testid\\n\" : \"not ok $testid\\n\" )";
    print "not ok $testid\n" if $@;
    ++$testid;
}

exit 0;
