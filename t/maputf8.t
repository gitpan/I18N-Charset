#!./perl
#
# maputf8.t - tests for Unicode::MapUTF8 functionality of I18N::Charset
#

use I18N::Charset;

eval "use Unicode::MapUTF8";
if (1 || $@ ne '')
  {
  # print STDERR $@;
  print STDOUT "1..0\nEND\n";
  exit 0;
  } # unless

#-----------------------------------------------------------------------
# This is an array of tests. Each test is eval'd as an expression.
# If it evaluates to FALSE, then "not ok N" is printed for the test,
# otherwise "ok N".
#-----------------------------------------------------------------------
my @as = &Unicode::MapUTF8::utf8_supported_charset();
@TESTS = map { 'defined iana_charset_name("'. $_ .'")' } @as;

print "1..", int(@TESTS), "\n";

$testid = 1;
foreach $test (@TESTS)
  {
  # print STDERR "\n  $test";
  unless (eval "$test")
    {
    print STDERR "  FAILED $test\n";
    print "not ";
    }
  print "ok $testid\n";
  ++$testid;
  } # foreach

exit 0;
