#!perl
#
# maputf8.t - tests for Unicode::MapUTF8 functionality of I18N::Charset
#

use I18N::Charset;
use Test::More skip_all => 'not implemented (patches welcome!)';

unless (eval "require Unicode::Map")
  {
  plan skip_all => 'Unicode::MapUTF8 is not installed';
  } # unless

my @as = &Unicode::MapUTF8::utf8_supported_charset();
@TESTS = map { 'defined iana_charset_name("'. $_ .'")' } @as;

plan tests => scalar(@TESTS);

foreach (@TESTS)
  {
  ok($_);
  } # foreach

exit 0;

__END__
