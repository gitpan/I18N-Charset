#!./perl
#
# map8.t - tests for map8 functionality of I18N::Charset
#

use I18N::Charset;

#-----------------------------------------------------------------------
# This is an array of tests. Each test is eval'd as an expression.
# If it evaluates to FALSE, then "not ok N" is printed for the test,
# otherwise "ok N".
#-----------------------------------------------------------------------
@TESTS =
(
	#================================================
	# TESTS FOR map8 routines
	#================================================

 #---- selection of examples which should all result in undef -----------
 '!defined map8_charset_name()',         # no argument
 '!defined map8_charset_name(undef)',    # undef argument
 '!defined map8_charset_name("")',       # empty argument
 '!defined map8_charset_name("junk")',   # illegal code
 '!defined map8_charset_name(\@aa)',     # illegal argument

 #---- some successful examples -----------------------------------------
 'map8_charset_name("ASMO_449")          eq "ASMO_449"',
 'map8_charset_name("ISO_9036")          eq "ASMO_449"',
 'map8_charset_name("arabic7")          eq "ASMO_449"',
 'map8_charset_name("iso-ir-89")          eq "ASMO_449"',
 'map8_charset_name("ISO-IR-89")          eq "ASMO_449"',
 'map8_charset_name("ISO - ir _ 89")          eq "ASMO_449"',

 #---- some aliasing examples -----------------------------------------
 '!defined(I18N::Charset::add_map8_alias("alias1" => "junk"))',
 '!defined map8_charset_name("alias1")',

 'I18N::Charset::add_map8_alias("alias2" => "ES2")      eq "ES2"',
 'map8_charset_name("alias2") eq "ES2"',

 'I18N::Charset::add_map8_alias("alias3" => "iso-ir-85") eq "ES2"',
 'map8_charset_name("alias3") eq "ES2"',

 'I18N::Charset::add_map8_alias("IBM297" => "IBM037") eq "IBM037"',
 'map8_charset_name("IBM297")       eq "IBM037"',
 'map8_charset_name("cp297")        eq "IBM037"',
 'map8_charset_name("ebcdic_cp_fr") eq "IBM037"',

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
