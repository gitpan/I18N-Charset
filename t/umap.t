#!./perl
#
# umap.t - tests for umap functionality of I18N::Charset
#

use I18N::Charset;

unless (eval "require Unicode::Map")
  {
  print STDOUT "1..0\nEND\n";
  exit 0;
  } # unless

#-----------------------------------------------------------------------
# This is an array of tests. Each test is eval'd as an expression.
# If it evaluates to FALSE, then "not ok N" is printed for the test,
# otherwise "ok N".
#-----------------------------------------------------------------------
@TESTS =
(
	#================================================
	# TESTS FOR umap routines
	#================================================

 #---- selection of examples which should all result in undef -----------
 '!defined umap_charset_name()',         # no argument
 '!defined umap_charset_name(undef)',    # undef argument
 '!defined umap_charset_name("")',       # empty argument
 '!defined umap_charset_name("junk")',   # illegal code
 '!defined umap_charset_name(\@aa)',     # illegal argument

 #---- some successful examples -----------------------------------------
 'umap_charset_name("apple symbol")          eq "APPLE-SYMBOL"',
 'umap_charset_name("Adobe Ding Bats")          eq "ADOBE-DINGBATS"',
 'umap_charset_name("cs IBM-037")          eq "CP037"',

 #---- some aliasing examples -------------------------------------------
 '!defined(I18N::Charset::add_umap_alias("alias1" => "junk"))',
 '!defined umap_charset_name("alias1")',

 'I18N::Charset::add_umap_alias("alias2" => "IBM775")      eq "CP775"',
 'umap_charset_name("alias2") eq "CP775"',

 'I18N::Charset::add_umap_alias("alias3" => "alias2") eq "CP775"',
 'umap_charset_name("alias3") eq "CP775"',

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
