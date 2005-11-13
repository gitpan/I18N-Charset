# libi.t - tests for "preferred LIBI name" functionality of I18N::Charset

# $Id: libi.t,v 1.10 2005/11/12 14:45:08 Daddy Exp $

use Test::More no_plan;

use IO::Capture::Stderr;
my $oICE =  IO::Capture::Stderr->new;

use strict;

BEGIN { use_ok('I18N::Charset') };

#================================================
# TESTS FOR libi routines
#================================================

my @aa;
#---- selection of examples which should all result in undef -----------
ok(!defined libi_charset_name(), 'no argument');
ok(!defined libi_charset_name(undef), 'undef argument');
ok(!defined libi_charset_name(""), 'empty argument');
ok(!defined libi_charset_name("junk"), 'junk argument');
ok(!defined libi_charset_name(999999), '999999 argument');
ok(!defined libi_charset_name(\@aa), 'arrayref argument');
$oICE->start;
ok(!defined I18N::Charset::add_libi_alias("my-junk" => 'junk argument'));
$oICE->stop;

SKIP:
  {
  skip 'App::Info::Lib::Iconv is not installed', 16 unless eval "require App::Info::Lib::Iconv";
  my $oAILI = new App::Info::Lib::Iconv;
 SKIP:
    {
    skip 'can not determine iconv version (not installed?)', 16 unless ref $oAILI;
 SKIP:
      {
      skip 'iconv is not installed', 16 unless $oAILI->installed;
      my $iLibiVersion = $oAILI->version || 0.0;
      # print STDERR " + libiconv version is $iLibiVersion\n";
 SKIP:
        {
        skip 'iconv version is too old(?)', 16 if ($iLibiVersion < 1.8);

        #---- some successful examples -----------------------------------------
        is(libi_charset_name("x-x-sjis"), libi_charset_name("MS_KANJI"), 'x-x-sjis');
        is(libi_charset_name("x-x-sjis"), "MS_KANJI", 'normal literal -- x-x-sjis');
        is(libi_charset_name("G.B.K."), "CP936", 'normal -- G.B.K.');
        is(libi_charset_name("CP936"), "CP936", 'identity -- CP936');
        is(libi_charset_name("Johab"), "CP1361", 'normal -- Johab');
        is(libi_charset_name("johab"), libi_charset_name("cp 1361"), 'equivalent -- johab');

        #---- some aliasing examples -----------------------------------------
        ok(I18N::Charset::add_libi_alias('my-chinese1' => 'CN-GB'));
        is(libi_charset_name("my-chinese1"), 'CN-GB', 'alias literal -- my-chinese1');
        is(libi_charset_name("my-chinese1"), libi_charset_name('EUC-CN'), 'alias equal -- my-chinese1');
        ok(I18N::Charset::add_libi_alias('my-chinese2' => 'EUC-CN'));
        is(libi_charset_name("my-chinese2"), 'CN-GB', 'alias literal -- my-chinese2');
        is(libi_charset_name("my-chinese2"), libi_charset_name('G.B.2312'), 'alias equal -- my-chinese2');
        ok(I18N::Charset::add_libi_alias('my-japanese' => 'x-x-sjis'));
        is(libi_charset_name("my-japanese"), 'MS_KANJI', 'alias literal -- my-japanese');
        is(libi_charset_name("my-japanese"), libi_charset_name('Shift_JIS'), 'alias equal -- my-japanese');
        }
      }
    }
  }

exit 0;

__END__

