use ExtUtils::testlib;
use Test::More no_plan;

BEGIN { use_ok('I18N::Charset') };

ok(I18N::Charset::add_enco_alias('gb2312' => 'euc-cn'));
is(enco_charset_name("gb2312"),
   'euc-cn',
   'test literal -- big5');

__END__
