#
# umap.t - tests for Unicode::Map functionality of I18N::Charset
#

use I18N::Charset;
use Test::More;

if (eval "require Unicode::Map")
  {
  plan tests => 16;
  }
else
  {
  plan skip_all => 'Unicode::Map is not installed';
  } # unless

#================================================
# TESTS FOR umap routines
#================================================

my @aa;
#---- selection of examples which should all result in undef -----------
ok(!defined umap_charset_name(), 'no argument');
ok(!defined umap_charset_name(undef), 'undef argument');
ok(!defined umap_charset_name(""), 'empty argument');
ok(!defined umap_charset_name("junk"), 'junk argument');
ok(!defined umap_charset_name(999999), '999999 argument');
ok(!defined umap_charset_name(\@aa), 'arrayref argument');

#---- some successful examples -----------------------------------------
ok(umap_charset_name("apple symbol") eq "APPLE-SYMBOL", 'dummy mib');
ok(umap_charset_name("Adobe Ding Bats") eq "ADOBE-DINGBATS", 'dummy mib');
ok(umap_charset_name("cs IBM-037") eq "CP037", 'same as iana');
ok(umap_charset_name("CP037") eq "CP037", 'identical');

#---- some aliasing examples -------------------------------------------
ok(!defined(I18N::Charset::add_umap_alias("alias1" => "junk")), 'add alias1');
ok(!defined umap_charset_name("alias1"), 'alias1');

ok(I18N::Charset::add_umap_alias("alias2" => "IBM775") eq "CP775", 'add alias2');
ok(umap_charset_name("alias2") eq "CP775", 'alias2');

ok(I18N::Charset::add_umap_alias("alias3" => "alias2") eq "CP775", 'add alias3');
ok(umap_charset_name("alias3") eq "CP775", 'alias3');

exit 0;

__END__
