#
# umap.t - tests for Unicode::Map functionality of I18N::Charset
#

use I18N::Charset;
use Test::More;

if (eval "require Unicode::Map")
  {
  plan tests => 15;
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
ok(umap_charset_name("apple symbol") eq "APPLE-SYMBOL", '');
ok(umap_charset_name("Adobe Ding Bats") eq "ADOBE-DINGBATS", '');
ok(umap_charset_name("cs IBM-037") eq "CP037", '');

#---- some aliasing examples -------------------------------------------
ok(!defined(I18N::Charset::add_umap_alias("alias1" => "junk")), '');
ok(!defined umap_charset_name("alias1"), '');

ok(I18N::Charset::add_umap_alias("alias2" => "IBM775")      eq "CP775", '');
ok(umap_charset_name("alias2") eq "CP775", '');

ok(I18N::Charset::add_umap_alias("alias3" => "alias2") eq "CP775", '');
ok(umap_charset_name("alias3") eq "CP775", '');

exit 0;

__END__
