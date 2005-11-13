# $Revision: 1.4 $
# mib.t - Tests for converting mib numbers back to charset names

use Test::More tests => 25;
BEGIN { use_ok('I18N::Charset') };

#================================================
# TESTS FOR mib routine
#================================================

#---- selection of examples which should all result in undef -----------
ok(!defined mib_charset_name());         # no argument
ok(!defined mib_charset_name(undef));    # undef argument
ok(!defined mib_charset_name(""));       # empty argument
ok(!defined mib_charset_name("junk"));   # illegal code
ok(!defined mib_charset_name(9999999));  # illegal code
ok(!defined mib_charset_name("None"));   # "None" appears as an Alias
                                         # in the data but should be
                                         # ignored
my @aa;
ok(!defined mib_charset_name(\@aa));     # illegal argument

# The same things, in the opposite direction:
ok(!defined charset_name_to_mib());         # no argument
ok(!defined charset_name_to_mib(undef));    # undef argument
ok(!defined charset_name_to_mib(""));       # empty argument
ok(!defined charset_name_to_mib("junk"));   # illegal code
ok(!defined charset_name_to_mib(9999999));  # illegal code
ok(!defined charset_name_to_mib("None")); # "None" appears as an
                                            # Alias in the data but
                                            # should be ignored
ok(!defined charset_name_to_mib(\@aa));     # illegal argument

 #---- some successful examples -----------------------------------------
ok(mib_charset_name("3") eq "ANSI_X3.4-1968");
ok(mib_charset_name("106") eq "UTF-8");
ok(mib_to_charset_name("1015") eq "UTF-16");
ok(mib_to_charset_name("17") eq "Shift_JIS");

# The same things, in the opposite direction:
ok(charset_name_to_mib("ecma cyrillic") eq '77');
ok(charset_name_to_mib("UTF-8") == 106);
ok(charset_name_to_mib("UTF-16") == 1015);
ok(charset_name_to_mib('s h i f t j i s') eq '17');

# This is the FIRST entry in the IANA list:
ok(charset_name_to_mib("ANSI_X3.4-1968") eq '3');
# This is the LAST entry in the IANA list:
ok(charset_name_to_mib('hz gb 2312') == 2085);

exit 0;

__END__
