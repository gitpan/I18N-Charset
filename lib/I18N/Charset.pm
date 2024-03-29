
# $rcs = ' $Id: Charset.pm,v 1.412 2013/10/05 15:12:38 Martin Exp $ ' ;

package I18N::Charset;

use strict;
use warnings;

require 5.005;

use base 'Exporter';
use blib;
use Carp;

=head1 NAME

I18N::Charset - IANA Character Set Registry names and Unicode::MapUTF8
(et al.) conversion scheme names

=head1 SYNOPSIS

  use I18N::Charset;

  $sCharset = iana_charset_name('WinCyrillic');
  # $sCharset is now 'windows-1251'
  $sCharset = umap_charset_name('Adobe DingBats');
  # $sCharset is now 'ADOBE-DINGBATS' which can be passed to Unicode::Map->new()
  $sCharset = map8_charset_name('windows-1251');
  # $sCharset is now 'cp1251' which can be passed to Unicode::Map8->new()
  $sCharset = umu8_charset_name('x-sjis');
  # $sCharset is now 'sjis' which can be passed to Unicode::MapUTF8->new()
  $sCharset = libi_charset_name('x-sjis');
  # $sCharset is now 'MS_KANJI' which can be passed to `iconv -f $sCharset ...`
  $sCharset = enco_charset_name('Shift-JIS');
  # $sCharset is now 'shiftjis' which can be passed to Encode::from_to()

  I18N::Charset::add_iana_alias('my-japanese' => 'iso-2022-jp');
  I18N::Charset::add_map8_alias('my-arabic' => 'arabic7');
  I18N::Charset::add_umap_alias('my-hebrew' => 'ISO-8859-8');
  I18N::Charset::add_libi_alias('my-sjis' => 'x-sjis');
  I18N::Charset::add_enco_alias('my-japanese' => 'shiftjis');

=head1 DESCRIPTION

The C<I18N::Charset> module provides access to the IANA Character Set
Registry names for identifying character encoding schemes.  It also
provides a mapping to the character set names used by the
Unicode::Map and Unicode::Map8 modules.

So, for example, if you get an HTML document with a META CHARSET="..."
tag, you can fairly quickly determine what Unicode::MapXXX module can
be used to convert it to Unicode.

If you don't have the module Unicode::Map installed, the umap_
functions will always return undef.
If you don't have the module Unicode::Map8 installed, the map8_
functions will always return undef.
If you don't have the module Unicode::MapUTF8 installed, the umu8_
functions will always return undef.
If you don't have the iconv library installed, the libi_
functions will always return undef.
If you don't have the Encode module installed, the enco_
functions will always return undef.

=cut

#-----------------------------------------------------------------------
#	Public Global Variables
#-----------------------------------------------------------------------
our
$VERSION = do { my @r = (q$Revision: 1.412 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };
our @EXPORT = qw( iana_charset_name
map8_charset_name
umap_charset_name
umu8_charset_name
mib_charset_name
mime_charset_name
libi_charset_name
enco_charset_name
mib_to_charset_name charset_name_to_mib
 );
our @EXPORT_OK = qw( add_iana_alias add_map8_alias add_umap_alias add_libi_alias add_enco_alias );

#-----------------------------------------------------------------------
#	Private Global Variables
#-----------------------------------------------------------------------

# %hsMIBofShortname is a hash of stripped names to mib.
my %hsMIBofShortname;
# %hsLongnameOfMIB is a hash of mib to long name.
my %hsLongnameOfMIB;
# %hsMIBofLongname is a hash of long name to mib.
my %hsMIBofLongname;
# %hsMIMEofMIB is a hash of mib to preferred MIME names.
my %hsMIMEofMIB;
# %MIBtoMAP8 is a hash of mib to Unicode::Map8 names.  (Only valid for
# those U::Map8 names that we can find in the IANA registry)
my %MIBtoMAP8;
# %MIBtoUMAP is a hash of mib to Unicode::Map names.  If a U::Map
# encoding does not have an official IANA entry, we create a dummy mib
# for it.
my %MIBtoUMAP;
# %MIBtoUMU8 is a hash of mib to Unicode::MapUTF8 names.  If a
# U::MapUTF8 encoding does not have an official IANA entry, we create
# a dummy mib for it.
my %MIBtoUMU8;
# %MIBtoLIBI is a hash of mib to libiconv names.  (Only valid for
# those libiconv names that we can find in the IANA registry)
my %MIBtoLIBI;
# %MIBtoENCO is a hash of mib to Encode names.  (Only valid for
# those Encode names that we can find in the IANA registry)
my %MIBtoENCO;

use constant DEBUG => 0;
use constant DEBUG_ENCO => 0;
use constant DEBUG_LIBI => 0;

=head1 CONVERSION ROUTINES

There are four main conversion routines: C<iana_charset_name()>,
C<map8_charset_name()>, C<umap_charset_name()>, and
C<umu8_charset_name()>.

=over 4

=item iana_charset_name()

This function takes a string containing the name of a character set
and returns a string which contains the official IANA name of the
character set identified. If no valid character set name can be
identified, then C<undef> will be returned.  The case and punctuation
within the string are not important.

    $sCharset = iana_charset_name('WinCyrillic');

=cut

my $sDummy = 'dummymib';
my $sFakeMIB = $sDummy .'001';

sub _is_dummy
  {
  my $s = shift;
  return ($s =~ m!\A$sDummy!);
  } # _is_dummy

sub iana_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # $iDebug = ($code =~ m!sjis!);
  # print STDERR " + iana_charset_name($code)..." if $iDebug;
  my $mib = _short_to_mib($code);
  return undef unless defined $mib;
  # print STDERR " + mib is ($mib)..." if $iDebug;
  # Make sure this is really a IANA mib:
  return undef if _is_dummy($mib);
  # print STDERR " + is really iana..." if $iDebug;
  return $hsLongnameOfMIB{$mib};
  } # iana_charset_name


sub _try_list
  {
  my $code = shift;
  my @asTry = ($code, _strip($code));
  push @asTry, _strip($code) if $code =~ s!\A(x-)+!!;  # try without leading x-
  return @asTry;
  } # _try_list

sub _short_to_mib
  {
  my $code = shift;
  local $^W = 0;
  # print STDERR " + _short_to_mib($code)..." if DEBUG;
  my $answer = undef;
 TRY_SHORT:
  foreach my $sTry (_try_list($code))
    {
    my $iMIB = $hsMIBofShortname{$sTry} || 'undef';
    # print STDERR "try($sTry)...$iMIB..." if DEBUG;
    if ($iMIB ne 'undef')
      {
      $answer = $iMIB;
      last TRY_SHORT;
      } # if
    } # foreach
  # print STDERR "answer is $answer\n" if DEBUG;
  return $answer;
  } # _short_to_mib


sub _short_to_long
  {
  local $^W = 0;
  my $s = shift;
  # print STDERR " + _short_to_long($s)..." if DEBUG;
  return $hsLongnameOfMIB{_short_to_mib($s)};
  } # _short_to_long


=item mime_charset_name()

This function takes a string containing the name of a character set
and returns a string which contains the preferred MIME name of the
character set identified. If no valid character set name can be
identified, then C<undef> will be returned.  The case and punctuation
within the string are not important.

    $sCharset = mime_charset_name('Extended_UNIX_Code_Packed_Format_for_Japanese');

=cut

sub mime_charset_name
  {
  # This function contributed by Masafumi "Max" Nakane.  Thank you!
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # print STDERR " + mime_charset_name($code)..." if DEBUG;
  my $mib = _short_to_mib($code);
  return undef unless defined $mib;
  # print STDERR " + mib is ($mib)..." if DEBUG;
  # Make sure this is really an IANA mib:
  return undef if _is_dummy($mib);
  # print STDERR " + is really iana..." if DEBUG;
  return $hsMIMEofMIB{$mib};
  } # mime_charset_name


=item enco_charset_name()

This function takes a string containing the name of a character set
and returns a string which contains a name of the character set
suitable to be passed to the Encode module.  If no valid character set
name can be identified, or if Encode is not installed, then C<undef>
will be returned.  The case and punctuation within the string are not
important.

    $sCharset = enco_charset_name('Extended_UNIX_Code_Packed_Format_for_Japanese');

=cut

my $iEncoLoaded = 0;

sub _maybe_load_enco # PRIVATE
  {
  return if $iEncoLoaded;
  # Get a list of aliases from Encode:
  if (eval q{require Encode})
    {
    my @as;
    @as = Encode->encodings(':all');
    # push @as, Encode->encodings('EBCDIC');
    my $iFake = 0;
    my $iReal = 0;
 ENCODING:
    foreach my $s (@as)
      {
      # First, see if this already has an IANA mapping:
      my $mib;
      my $sIana = iana_charset_name($s);
      if (!defined $sIana)
        {
        # Create a dummy mib:
        $mib = $sFakeMIB++;
        $iFake++;
        } # if
      else
        {
        $mib = charset_name_to_mib($sIana);
        $iReal++;
        }
      # At this point we have a mib for this Encode entry.
      $MIBtoENCO{$mib} = $s;
      DEBUG_ENCO && print STDERR " +   mib for enco ==$s== is $mib\n";
      $hsMIBofShortname{_strip($s)} = $mib;
      DEBUG_ENCO && print STDERR " +   assign enco =$s==>$mib\n" if _is_dummy($mib);
      } # foreach ENCODING
    if (DEBUG_ENCO)
      {
      print STDERR " + Summary of Encode encodings:\n";
      printf STDERR (" +   %d encodings found.\n", scalar(@as));
      print STDERR " +   $iFake fake mibs created.\n";
      print STDERR " +   $iReal real mibs re-used.\n";
      } # if
    $iEncoLoaded = 1;
    add_enco_alias('Windows-31J', 'cp932');
    } # if
  else
    {
    print STDERR " --- Encode is not installed\n";
    }
  } # _maybe_load_enco

sub _mib_to_enco # PRIVATE
  {
  _maybe_load_enco();
  return $MIBtoENCO{shift()};
  } # _mib_to_enco

sub enco_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  _maybe_load_enco();
  my $iDebug = 0; # ($code =~ m!johab!i);
  print STDERR " + enco_charset_name($code)..." if ($iDebug || DEBUG_ENCO);
  my $mib = _short_to_mib($code);
  return undef unless defined $mib;
  print STDERR " + mib is ($mib)..." if ($iDebug || DEBUG_ENCO);
  my $ret = _mib_to_enco($mib);
  print STDERR " + enco is ($ret)..." if ($iDebug || DEBUG_ENCO);
  return $ret;
  } # enco_charset_name


=item libi_charset_name()

This function takes a string containing the name of a character set
and returns a string which contains a name of the character set
suitable to be passed to iconv.  If no valid character set name can be
identified, then C<undef> will be returned.  The case and punctuation
within the string are not important.

    $sCharset = libi_charset_name('Extended_UNIX_Code_Packed_Format_for_Korean');

=cut

my $iLibiLoaded = 0;

sub _maybe_load_libi # PRIVATE
  {
  return if $iLibiLoaded;
  # Get a list of aliases from iconv:
  return unless eval 'require App::Info::Lib::Iconv';
  my $oAILI = new App::Info::Lib::Iconv;
  if (ref $oAILI)
    {
    my $iLibiVersion = $oAILI->version;
    DEBUG_LIBI && warn " DDD libiconv version is $iLibiVersion\n";
    if ($oAILI->installed && (1.08 <= $iLibiVersion))
      {
      my $sCmd = $oAILI->bin_dir . '/iconv -l';
      DEBUG_LIBI && warn " DDD iconv cmdline is $sCmd\n";
      my @asIconv = split(/\n/, `$sCmd`);
 ICONV_LINE:
      foreach my $sLine (@asIconv)
        {
        my @asWord = split(/\s+/, $sLine);
        # First, go through and find one of these that has an IANA mapping:
        my $mib;
        my $sIana = undef;
 FIND_IANA:
        foreach my $sWord (@asWord)
          {
          last FIND_IANA if ($sIana = iana_charset_name($sWord));
          } # foreach FIND_IANA
        if (!defined $sIana)
          {
          # Create a dummy mib:
          $mib = $sFakeMIB++;
          } # if
        else
          {
          $mib = charset_name_to_mib($sIana);
          }
        # At this point we have a mib for this iconv entry.  Assign them all:
 ADD_LIBI:
        foreach my $sWord (reverse @asWord)
          {
          $MIBtoLIBI{$mib} = $sWord;
          DEBUG_LIBI && warn " +   mib for libi ==$sWord== is $mib\n";
          $hsMIBofShortname{_strip($sWord)} = $mib;
          } # foreach ADD_LIBI
        } # foreach ICONV_LINE
      } # if
    } # if
  $iLibiLoaded = 1;
  } # _maybe_load_libi

sub _mib_to_libi # PRIVATE
  {
  _maybe_load_libi();
  return $MIBtoLIBI{shift()};
  } # _mib_to_libi

sub libi_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # my $iDebug = 1; # ($code =~ m!johab!i);
  # print STDERR " + libi_charset_name($code)..." if $iDebug;
  my $mib = _short_to_mib($code);
  return undef unless defined $mib;
  # print STDERR " + mib is ($mib)..." if $iDebug;
  my $ret = _mib_to_libi($mib);
  # print STDERR " + libi is ($ret)..." if $iDebug;
  return $ret;
  } # libi_charset_name


=item mib_to_charset_name

This function takes a string containing the MIBenum of a character set
and returns a string which contains a name for the character set.
If the given MIBenum does not correspond to any character set,
then C<undef> will be returned.

    $sCharset = mib_to_charset_name('3');

=cut

sub mib_to_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  local $^W = 0;
  return $hsLongnameOfMIB{$code};
  } # mib_to_charset_name


=item mib_charset_name

This is a synonum for mib_to_charset_name

=cut

sub mib_charset_name
  {
  mib_to_charset_name(@_);
  } # mib_charset_name


=item charset_name_to_mib

This function takes a string containing the name of a character set in
almost any format and returns a MIBenum for the character set.  For
IANA-registered character sets, this is the IANA-registered MIB.  For
non-IANA character sets, this is an unambiguous unique string whose
only use is to pass to other functions in this module.  If no valid
character set name can be identified, then C<undef> will be returned.

    $iMIB = charset_name_to_mib('US-ASCII');

=cut

sub charset_name_to_mib
  {
  my $s = shift;
  return undef unless defined($s);
  return $hsMIBofLongname{$s} || $hsMIBofLongname{
                                                  iana_charset_name($s) ||
                                                  umap_charset_name($s) ||
                                                  map8_charset_name($s) ||
                                                  umu8_charset_name($s) ||
                                                  ''
                                                 };
  } # charset_name_to_mib


=item map8_charset_name()

This function takes a string containing the name of a character set
(in almost any format) and returns a string which contains a name for
the character set that can be passed to Unicode::Map8::new().
Note: the returned string will be capitalized just like
the name of the .bin file in the Unicode::Map8::MAPS_DIR directory.
If no valid character set name can be identified,
then C<undef> will be returned.
The case and punctuation within the argument string are not important.

    $sCharset = map8_charset_name('windows-1251');

=cut

sub map8_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # $iDebug = 0 && ($code =~ m!037!);
  # print STDERR " + map8_charset_name($code)..." if $iDebug;
  $code = _strip($code);
  # print STDERR "$code..." if $iDebug;
  my $iMIB = _short_to_mib($code) || 'undef';
  # print STDERR "$iMIB..." if $iDebug;
  if ($iMIB ne 'undef')
    {
    # print STDERR "$MIBtoMAP8{$iMIB}\n" if $iDebug;
    return $MIBtoMAP8{$iMIB};
    } # if
  # print STDERR "undef\n" if $iDebug;
  return undef;
  } # map8_charset_name


=item umap_charset_name()

This function takes a string containing the name of a character set
(in almost any format) and returns a string which contains a name for
the character set that can be passed to Unicode::Map::new(). If no
valid character set name can be identified, then C<undef> will be
returned.  The case and punctuation within the argument string are not
important.

    $sCharset = umap_charset_name('hebrew');

=cut

sub umap_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # $iDebug = ($code =~ m!apple!i);
  # print STDERR "\n + MIBtoUMAP{dummymib029} == $MIBtoUMAP{$sDummy .'029'}\n\n" if $iDebug;
  # print STDERR " + umap_charset_name($code)..." if $iDebug;
  my $iMIB = _short_to_mib(_strip($code)) || 'undef';
  # print STDERR "$iMIB..." if $iDebug;
  if ($iMIB ne 'undef')
    {
    # print STDERR "$MIBtoUMAP{$iMIB}\n" if $iDebug;
    return $MIBtoUMAP{$iMIB};
    } # if
  # print STDERR "undef\n" if $iDebug;
  return undef;
  } # umap_charset_name


our @asMap8Debug;

=item umu8_charset_name()

This function takes a string containing the name of a character set
(in almost any format) and returns a string which contains a name for
the character set that can be passed to Unicode::MapUTF8::new(). If no
valid character set name can be identified, then C<undef> will be
returned.  The case and punctuation within the argument string are not
important.

    $sCharset = umu8_charset_name('windows-1251');

=cut

sub umu8_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # $iDebug = ($code =~ m!u!);
  # print STDERR " + umu8_charset_name($code)..." if $iDebug;
  my $iMIB = _short_to_mib($code) || 'undef';
  # print STDERR "$iMIB..." if $iDebug;
  if ($iMIB ne 'undef')
    {
    # print STDERR "$MIBtoUMU8{$iMIB}\n" if $iDebug;
    return $MIBtoUMU8{$iMIB};
    } # if
  # print STDERR "undef\n" if $iDebug;
  return undef;
  } # umu8_charset_name

=back

=head1 QUERY ROUTINES

There is one function which can be used to obtain a list of all
IANA-registered character set names.

=over 4

=item C<all_iana_charset_names()>

Returns a list of all registered IANA character set names.
The names are not in any particular order.

=back

=cut

sub all_iana_charset_names
  {
  return values %hsLongnameOfMIB;
  } # all_iana_charset_names

#-----------------------------------------------------------------------

=head1 CHARACTER SET NAME ALIASING

This module supports several semi-private routines for specifying
character set name aliases.

=over 4

=item  add_iana_alias()

This function takes two strings: a new alias, and a target IANA
Character Set Name (or another alias).  It defines the new alias to
refer to that character set name (or to the character set name to
which the second alias refers).

Returns the target character set name of the successfully installed alias.
Returns 'undef' if the target character set name is not registered.
Returns 'undef' if the target character set name of the second alias
is not registered.

  I18N::Charset::add_iana_alias('my-alias1' => 'Shift_JIS');

With this code, "my-alias1" becomes an alias for the existing IANA
character set name 'Shift_JIS'.

  I18N::Charset::add_iana_alias('my-alias2' => 'sjis');

With this code, "my-alias2" becomes an alias for the IANA character set
name referred to by the existing alias 'sjis' (which happens to be 'Shift_JIS').

=cut

sub add_iana_alias
  {
  my ($sAlias, $sReal) = @_;
  # print STDERR " + add_iana_alias($sAlias, $sReal)\n";
  my $sName = iana_charset_name($sReal);
  if (not defined($sName))
    {
    carp qq{attempt to alias "$sAlias" to unknown IANA charset "$sReal"};
    return undef;
    } # if
  my $mib = _short_to_mib(_strip($sName));
  # print STDERR " --> $sName --> $mib\n";
  $hsMIBofShortname{_strip($sAlias)} = $mib;
  return $sName;
  } # add_iana_alias

#-----------------------------------------------------------------------

=item  add_map8_alias()

This function takes two strings: a new alias, and a target
Unicode::Map8 Character Set Name (or an exising alias to a Map8 name).
It defines the new alias to refer to that mapping name (or to the
mapping name to which the second alias refers).

If the first argument is a registered IANA character set name, then
all aliases of that IANA character set name will end up pointing to
the target Map8 mapping name.

Returns the target mapping name of the successfully installed alias.
Returns 'undef' if the target mapping name is not registered.
Returns 'undef' if the target mapping name of the second alias
is not registered.

  I18N::Charset::add_map8_alias('normal' => 'ANSI_X3.4-1968');

With the above statement, "normal" becomes an alias for the existing
Unicode::Map8 mapping name 'ANSI_X3.4-1968'.

  I18N::Charset::add_map8_alias('normal' => 'US-ASCII');

With the above statement, "normal" becomes an alias for the existing
Unicode::Map mapping name 'ANSI_X3.4-1968' (which is what "US-ASCII"
is an alias for).

  I18N::Charset::add_map8_alias('IBM297' => 'EBCDIC-CA-FR');

With the above statement, "IBM297" becomes an alias for the existing
Unicode::Map mapping name 'EBCDIC-CA-FR'.  As a side effect, all the
aliases for 'IBM297' (i.e. 'cp297' and 'ebcdic-cp-fr') also become
aliases for 'EBCDIC-CA-FR'.

=cut

sub add_map8_alias
  {
  my ($sAlias, $sReal) = @_;
  my $sName = map8_charset_name($sReal);
  my $sShort = _strip($sAlias);
  my $sShortName = _strip($sName);
  if (not defined($sName))
    {
    carp qq{attempt to alias "$sAlias" to unknown Map8 charset "$sReal"};
    return undef;
    } # if
  if (exists $hsMIBofShortname{$sShortName})
    {
    $hsMIBofShortname{$sShort} = $hsMIBofShortname{$sShortName};
    } # if
  return $sName;
  } # add_map8_alias

#-----------------------------------------------------------------------

=item  add_umap_alias()

This function works identically to add_map8_alias() above, but
operates on Unicode::Map encoding tables.

=cut

sub add_umap_alias
  {
  my ($sAlias, $sReal) = @_;
  my $sName = umap_charset_name($sReal);
  my $sShort = _strip($sAlias);
  my $sShortName = _strip($sName);
  if (not defined($sName))
    {
    carp qq{attempt to alias "$sAlias" to unknown U::Map charset "$sReal"};
    return undef;
    } # if
  if (exists $hsMIBofShortname{$sShortName})
    {
    $hsMIBofShortname{$sShort} = $hsMIBofShortname{$sShortName};
    } # if
  return $sName;
  } # add_umap_alias

#-----------------------------------------------------------------------

=item  add_libi_alias()

This function takes two strings: a new alias, and a target iconv
Character Set Name (or existing iconv alias).  It defines the new
alias to refer to that character set name (or to the character set
name to which the existing alias refers).

Returns the target conversion scheme name of the successfully installed alias.
Returns 'undef' if there is no such target conversion scheme or alias.

Examples:

  I18N::Charset::add_libi_alias('my-chinese1' => 'CN-GB');

With this code, "my-chinese1" becomes an alias for the existing iconv
conversion scheme 'CN-GB'.

  I18N::Charset::add_libi_alias('my-chinese2' => 'EUC-CN');

With this code, "my-chinese2" becomes an alias for the iconv
conversion scheme referred to by the existing alias 'EUC-CN' (which
happens to be 'CN-GB').

=cut

sub add_libi_alias
  {
  my ($sAlias, $sReal) = @_;
  # print STDERR " + add_libi_alias($sAlias,$sReal)...";
  my $sName = libi_charset_name($sReal);
  if (not defined($sName))
    {
    carp qq{attempt to alias "$sAlias" to unknown iconv charset "$sReal"};
    return undef;
    } # if
  my $mib = _short_to_mib(_strip($sName));
  # print STDERR "sName=$sName...mib=$mib\n";
  $hsMIBofShortname{_strip($sAlias)} = $mib;
  return $sName;
  } # add_libi_alias

#-----------------------------------------------------------------------

=item  add_enco_alias()

This function takes two strings: a new alias, and a target Encode
encoding Name (or existing Encode alias).  It defines the new alias
referring to that encoding name (or to the encoding to which the
existing alias refers).

Returns the target encoding name of the successfully installed alias.
Returns 'undef' if there is no such encoding or alias.

Examples:

  I18N::Charset::add_enco_alias('my-japanese1' => 'jis0201-raw');

With this code, "my-japanese1" becomes an alias for the existing
encoding 'jis0201-raw'.

  I18N::Charset::add_enco_alias('my-japanese2' => 'my-japanese1');

With this code, "my-japanese2" becomes an alias for the encoding
referred to by the existing alias 'my-japanese1' (which happens to be
'jis0201-raw' after the previous call).

=cut

sub add_enco_alias
  {
  my ($sAlias, $sReal) = @_;
  my $iDebug = 0;
  print STDERR " + add_enco_alias($sAlias,$sReal)..." if ($iDebug || DEBUG_ENCO);
  my $sName = enco_charset_name($sReal);
  if (not defined($sName))
    {
    carp qq{attempt to alias "$sAlias" to unknown Encode charset "$sReal"};
    return undef;
    } # if
  my $mib = _short_to_mib(_strip($sName));
  print STDERR "sName=$sName...mib=$mib\n" if ($iDebug || DEBUG_ENCO);
  $hsMIBofShortname{_strip($sAlias)} = $mib;
  return $sName;
  } # add_enco_alias

#-----------------------------------------------------------------------

=back

=head1 KNOWN BUGS AND LIMITATIONS

=over 4

=item *

There could probably be many more aliases added (for convenience) to
all the IANA names.
If you have some specific recommendations, please email the author!

=item *

The only character set names which have a corresponding mapping in the
Unicode::Map8 module are the character sets that Unicode::Map8 can
convert.

Similarly, the only character set names which have a corresponding
mapping in the Unicode::Map module are the character sets that
Unicode::Map can convert.

=item *

In the current implementation, all tables are read in and initialized
when the module is loaded, and then held in memory until the program
exits.  A "lazy" implementation (or a less-portable tied hash) might
lead to a shorter startup time.  Suggestions, patches, comments are
always welcome!

=back

=head1 SEE ALSO

=over 4

=item Unicode::Map

Convert strings from various multi-byte character encodings to and from Unicode.

=item Unicode::Map8

Convert strings from various 8-bit character encodings to and from Unicode.

=item Jcode

Convert strings among various Japanese character encodings and Unicode.

=item Unicode::MapUTF8

A wrapper around all three of these character set conversion distributions.

=back

=head1 AUTHOR

Martin 'Kingpin' Thurn, C<mthurn at cpan.org>, L<http://tinyurl.com/nn67z>.

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

#-----------------------------------------------------------------------

sub _strip
  {
  my $s = lc(shift);
  $s =~ tr/[0-9a-zA-Z]//dc;
  return $s;
  } # _strip

# initialization code - stuff the DATA into some data structure

# The only reason this is a while loop is so that I can bail out
# (e.g. for debugging) without using goto ;-)
INITIALIZATION:
  {
  my ($sName, $iMIB, $sAlias, $mimename);
  my $iDebug = 0;
  # I used to use the __DATA__ mechanism to initialize the data, but
  # that is not compatible with perlapp.  NOTE that storing the IANA
  # charset data as a file separate from this module code will not
  # work with perlapp either!
  my $s = _init_data();
  my $iRecord = 0;
 RECORD:
  while ($s =~ m/<record(.+?)<\/record>/gs)
    {
    my $sRecord = $1;
    $iRecord++;
    if ($sRecord !~ m/<name>(.+?)<\/name>/)
      {
      warn " WWW found record with no name.\n";
      next RECORD;
      } # if
    my $sName = $1;
    if ($sRecord !~ m/<value>(\d+)<\/value>/)
      {
      warn " WWW found record '$sName' with no value.\n";
      next RECORD;
      } # if
    my $iMIB = $1;
    if ($sRecord =~ m/<preferred_alias>(.+?)<\/preferred_alias>/)
      {
      $hsMIMEofMIB{$iMIB} = $1;
      $hsMIBofShortname{_strip($1)} = $iMIB;
      }
    else
      {
      # warn " WWW found record '$sName' with no preferred alias.\n";
      } # if
    my $sMime = $1;
    $hsLongnameOfMIB{$iMIB} = $sName;
    $hsMIBofLongname{$sName} = $iMIB;
    # warn " DDD '$sName' ==> $iMIB\n";
    $hsMIBofShortname{_strip($sName)} = $iMIB;
 ALIAS:
    while ($sRecord =~ m/<alias>(.+?)<\/alias>/g)
      {
      my $sAlias = $1;
      $hsMIBofShortname{_strip($sAlias)} = $iMIB;
      } # while ALIAS
    } # while RECORD
  # Now that we have all the standard definitions, process the special
  # === directives:
  my @asEqualLines = split(/\n/, _init_data_extra());
  chomp @asEqualLines;
 EQUAL_LINE:
  foreach my $sLine (@asEqualLines)
    {
    next if ($sLine =~ m!\A#!);
    # print STDERR " +   equal-sign line $sLine...\n";
    my @as = split(/\ ===\ /, $sLine);
    my $sName = shift @as || q{};
    next unless $sName ne '';
    my $iMIB = $hsMIBofShortname{_strip($sName)} || 0;
    if (! $iMIB)
      {
      print STDERR " EEE can not find IANA entry for equal-sign directive $sName\n";
      next EQUAL_LINE;
      } # unless
 EQUAL_ITEM:
    foreach my $s (@as)
      {
      my $sStrip = _strip($s);
      # print STDERR " +     $sStrip --> $iMIB\n";
      $hsMIBofShortname{$sStrip} = $iMIB;
      } # foreach EQUAL_ITEM
    } # foreach EQUAL_LINE

  # last;  # for debugging

  if (eval "require Unicode::Map8")
    {
    # $iDebug = 1;
    my $sDir = $Unicode::Map8::MAPS_DIR;
    my $sAliasesFname = "$sDir/aliases";
    # Ah, how to get all the Unicode::Map8 supported charsets...  It
    # sure ain't easy!  The aliases file in the MAPS_DIR has a nice
    # set of aliases, but since some charsets have no aliases, they're
    # not listed in the aliases file!  Ergo, we have to read the
    # aliases file *and* all the file names in the MAPS_DIR!
    push @asMap8Debug, " DDD found Unicode::Map8 installed, will build map8 tables based on $sAliasesFname and files in that directory...\n";
    # First, read all the files in the MAPS_DIR folder and register in our local data structures:
    if (opendir(DIR, $sDir))
      {
      my @asFname = grep(!/^\.\.?$/, readdir(DIR));
      foreach my $sLong (@asFname)
        {
        next unless -f "$Unicode::Map8::MAPS_DIR/$sLong";
        $sLong =~ s/\.(?:bin|txt)$//;
        # Try to find the official IANA name for this encoding:
        push @asMap8Debug, " DDD   looking for $sLong in iana table...\n";
        my $sFound = '';
        if (defined (my $sTemp = iana_charset_name($sLong)))
          {
          $sFound = $sTemp;
          } # if
        if ($sFound eq '')
          {
          # $iDebug = 1;
          $iMIB = $sFakeMIB++;
          push @asMap8Debug, " DDD   had to use a dummy mib ($iMIB) for U::Map8==$sLong==\n";
          $hsMIBofLongname{$sLong} = $iMIB;
          } # unless
        else
          {
          $iMIB = $hsMIBofLongname{$sFound};
          push @asMap8Debug, " DDD   found IANA name $sFound ($iMIB) for Map8 entry $sLong\n";
          }
        # Make this IANA mib map to this Map8 name:
        push @asMap8Debug, " DDD      map $iMIB to $sLong in MIBtoMAP8...\n";
        $MIBtoMAP8{$iMIB} = $sLong;
        my $s = _strip($sLong);
        push @asMap8Debug, " DDD      map $s to $iMIB in hsMIBofShortname...\n";
        $hsMIBofShortname{$s} = $iMIB;
        } # foreach
      } # if
    # Now, go through the Unicode::Map8 aliases hash and process the aliases:
    my $avoid_warning = keys %Unicode::Map8::ALIASES;
    while (my ($alias, $charset) = each %Unicode::Map8::ALIASES)
      {
      my $iMIB = charset_name_to_mib($charset); # qqq
      my $s = _strip($alias);
      push @asMap8Debug, " DDD      map $s to $iMIB in hsMIBofShortname...\n";
      $hsMIBofShortname{$s} = $iMIB;
      } # while
    # If there are special cases for Unicode::Map8, add them here:
    add_map8_alias('ISO_8859-13:1998', 'ISO_8859-13');
    add_map8_alias('L 7', 'ISO_8859-13');
    add_map8_alias('Latin 7', 'ISO_8859-13');
    add_map8_alias('ISO_8859-15:1998', 'ISO_8859-15');
    add_map8_alias('L 0', 'ISO_8859-15');
    add_map8_alias('Latin 0', 'ISO_8859-15');
    add_map8_alias('L 9', 'ISO_8859-15');
    add_map8_alias('Latin 9', 'ISO_8859-15');
    add_map8_alias('ISO-8859-1-Windows-3.1-Latin-1', 'cp1252');
    add_map8_alias('csWindows31Latin1', 'cp1252');
    # Above aliases were described in RT#18802
    push @asMap8Debug, "done.\n";
    print STDERR @asMap8Debug if $iDebug;
    } # if Unicode::Map8 installed

  # last;  # for debugging

  # $iDebug = 1;
  if (eval "require Unicode::Map")
    {
    print STDERR " + found Unicode::Map installed, will build tables..." if $iDebug;
    my $MAP_Path = $INC{'Unicode/Map.pm'};
    $MAP_Path =~ s/\.pm//;
    my $sMapFile = "$MAP_Path/REGISTRY";
    if (open MAPS, $sMapFile)
      {
      local $/ = undef;
      my @asMAPS = split(/\n\s*\n/, <MAPS>);
 UMAP_ENTRY:
      foreach my $sEntry (@asMAPS)
        {
        $iDebug = 0;
        # print STDERR " + working on Umap entry >>>>>$sEntry<<<<<...\n";
        my ($sName, $iMIB) = ('', '');
        # Get the value of the name field, and skip entries with no name:
        next UMAP_ENTRY unless $sEntry =~ m!^name:\s+(\S+)!mi;
        $sName = $1;
        # $iDebug = ($sName =~ m!apple!);
        print STDERR " +   UMAP sName is $sName\n" if $iDebug;
        my @asAlias = split /\n/, $sEntry;
        @asAlias = map { /alias:\s+(.*)/; $1 } (grep /alias/, @asAlias);
        # See if this entry already has the MIB identified:
        if ($sEntry =~ m!^#mib:\s+(\d+)!mi)
          {
          $iMIB = $1;
          } # if
        else
          {
          # This entry does not have the MIB listed.  See if the name
          # of any of the aliases are known to our iana tables:
 UMAP_ALIAS:
          foreach my $sAlias ($sName, @asAlias)
            {
            print STDERR " +     try alias $sAlias\n" if $iDebug;
            my $iMIBtry = _short_to_mib(_strip($sAlias));
            if ($iMIBtry)
              {
              print STDERR " +       matched\n" if $iDebug;
              $iMIB = $iMIBtry;
              last UMAP_ALIAS;
              } # if
            } # foreach
          # If nothing matched, create a dummy mib:
          if ($iMIB eq '')
            {
            $iMIB = $sFakeMIB++;
            print STDERR " +   had to use a dummy mib ($iMIB) for U::Map==$sName==\n" if $iDebug;
            } # if
          } # else
        # $iDebug = ($iMIB =~ m!225[23]!);
        # $iDebug = ($iMIB eq '17');
        print STDERR " +   UMAP mib is $iMIB\n" if $iDebug;
        $MIBtoUMAP{$iMIB} = $sName;
        $hsMIBofLongname{$sName} ||= $iMIB;
        $hsMIBofShortname{_strip($sName)} ||= $iMIB;
        foreach my $sAlias (@asAlias)
          {
          print STDERR " +   UMAP alias $sAlias\n" if $iDebug;
          $hsMIBofShortname{_strip($sAlias)} = $iMIB;
          } # foreach $sAlias
        } # foreach UMAP_ENTRY
      close MAPS;
      # print STDERR "\n + MIBtoUMAP{dummymib029} == $MIBtoUMAP{$sDummy .'029'}\n\n";
      } # if open
    else
      {
      carp " --- couldn't open $sMapFile for read" if $iDebug;
      }
    # If there are special cases for Unicode::Map, add them here:
    # add_umap_alias("new-name", "existing-name");
    print STDERR "done.\n" if $iDebug;
    } # if Unicode::Map installed

  # Make sure to do U::MapUTF8 last, because it (in turn) depends on
  # the others.
  # $iDebug = 1;
  if (1.0 <= (eval q{ require Unicode::MapUTF8; $Unicode::MapUTF8::VERSION } || 0))
    {
    print STDERR " + found Unicode::MapUTF8 $Unicode::MapUTF8::VERSION installed, will build tables...\n" if $iDebug;
    my @as;
    # Wrap this in an eval to avoid compiler warning(?):
    eval { @as = Unicode::MapUTF8::utf8_supported_charset() };
UMU8_NAME:
    foreach my $sName (@as)
      {
      # $iDebug = ($sName =~ m!jis!i);
      print STDERR " + working on UmapUTF8 entry >>>>>$sName<<<<<...\n" if $iDebug;
      my $s = iana_charset_name($sName) || '';
      if ($s ne '')
        {
        # print STDERR " +   iana name is >>>>>$s<<<<<...\n" if $iDebug;
        $MIBtoUMU8{charset_name_to_mib($s)} = $sName;
        next UMU8_NAME;
        } # if already maps to IANA
      # print STDERR " +   UmapUTF8 entry ===$sName=== has no iana entry\n" if $iDebug;
      $s = umap_charset_name($sName) || '';
      if ($s ne '')
        {
        print STDERR " +   U::Map name is >>>>>$s<<<<<...\n" if $iDebug;
        $MIBtoUMU8{charset_name_to_mib($s)} = $sName;
        next UMU8_NAME;
        } # if maps to U::Map
      # print STDERR " +   UmapUTF8 entry ==$sName== has no U::Map entry\n" if $iDebug;
      $s = map8_charset_name($sName) || '';
      if ($s ne '')
        {
        print STDERR " +   U::Map8 name is >>>>>$s<<<<<...\n" if $iDebug;
        $MIBtoUMU8{charset_name_to_mib($s)} = $sName;
        next UMU8_NAME;
        } # if maps to U::Map8
      print STDERR " +   UmapUTF8 entry ==$sName== has no entries at all\n" if $iDebug;
      } # foreach
    # If there are special cases for Unicode::MapUTF8, add them here:
    # add_umap_alias("new-name", "existing-name");
    print STDERR "done.\n" if $iDebug;
    } # if Unicode::MapUTF8 installed

  # Initialization is all finished:
  last;
  # Below here is debugging code:

  print STDERR " + the following IANA names do *not* have entries in the Map8 table:\n";
  my %hiTried = ();
  foreach my $sIANA (sort values %hsLongnameOfMIB)
    {
    next if $hiTried{$sIANA};
    print "$sIANA\n" unless defined map8_charset_name($sIANA);
    $hiTried{$sIANA}++;
    } # foreach

  # last;  # for debugging

  # debugging: selective dump:
  print STDERR " + after init, iana_charset_name returns:\n";
  foreach my $key (qw(cp1251 windows-1251 WinCyrillic sjis x-sjis Shift_JIS ASCII US-ASCII us-ascii iso-2022-jp iso-8859-1 Unicode-2-0-utf-8 EUC-KR big5 x-x-big5))
    {
    print STDERR " +   $key => ", iana_charset_name($key) || 'undef', "\n";
    } # foreach

  # exit 88;

  print STDERR " + after init, map8_charset_name() returns:\n";
  foreach my $key (qw(cp1251 windows-1251 WinCyrillic sjis x-sjis Shift_JIS ASCII US-ASCII us-ascii iso-2022-jp iso-8859-1 Unicode-2-0-utf-8 EUC-KR big5 x-x-big5))
    {
    print STDERR " +   $key => ", map8_charset_name($key) || 'undef', "\n";
    } # foreach

  last;

  # debugging: huge dump:
  # _dump_hash('hsLongnameOfMIB', \%hsLongnameOfMIB);
  # _dump_hash('hsMIBofLongname', \%hsMIBofLongname);
  # _dump_hash('hsMIBofShortname', \%hsMIBofShortname);
  foreach (keys %hsMIBofShortname)
    {
    print STDERR " + _short_to_long($_) == ", _short_to_long($_) || 'undef', "\n";
    } # foreach

  } # end of INITIALIZATION block

sub _dump_hash
  {
  my ($sName, $rh) = @_;
  print STDERR " + after initialization, $sName is:\n";
  foreach my $key (keys %$rh)
    {
    print STDERR " +   $key => $$rh{$key}\n";
    } # foreach
  } # _dump_hash

sub _init_data_extra
  {
  # This little piece of data is a hand-made list of IANA names and
  # aliases, in the form AAA === BBB === CCC, where AAA is the
  # canonical IANA name and BBB and CCC are aliases.  Note that
  # capitalization and punctuation of aliases are meaningless (but
  # whitespace is not allowed).
  return <<'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';

Shift_JIS === sjis
windows-1250 === winlatin2 === cp1250
windows-1251 === wincyrillic === cp1251
windows-1252 === winlatin1 === cp1252
windows-1253 === wingreek === cp1253
windows-1254 === winturkish === cp1254
windows-1255 === winhebrew === cp1255
windows-1256 === winarabic === cp1256
windows-1257 === winbaltic === cp1257
windows-1258 === winvietnamese === cp1258
Adobe-Standard-Encoding === adobe-standard
Adobe-Symbol-Encoding === adobe-symbol
EBCDIC-ES === ebcdic-cp-es
EBCDIC-FR === ebcdic-cp-fr
EBCDIC-IT === ebcdic-cp-it
EBCDIC-UK === ebcdic-cp-gb
EBCDIC-FI-SE === ebcdic-cp-fi
UTF-7 === Unicode-2-0-utf-7
UTF-8 === Unicode-2-0-utf-8
Extended_UNIX_Code_Packed_Format_for_Japanese === euc === euc-jp
# These are for Unicode::MapUTF8:
ISO-10646-UCS-2 === ucs2
ISO-10646-UCS-4 === ucs4
# These are for iconv:
ISO-2022-JP === ISO-2022-JP-1
# These are for Encode:
IBM1047 === cp1047
GB2312 === gb2312-raw
HZ-GB-2312 === hz
JIS_X0201 === jis0201-raw
JIS_C6226-1983 === jis0208-raw
JIS_X0212-1990 === jis0212-raw
KS_C_5601-1987 === ksc5601-raw
CP037 === CP37
cp863 === DOSCanadaF
cp860 === DOSPortuguese
cp869 === DOSGreek2
koi8-r === cp878
# These encodings are handled by Encode, but I don't know what they are:
# ??? === AdobeZdingbats
# ??? === MacArabic
# ??? === MacCentralEurRoman
# ??? === MacChineseSimp
# ??? === MacChineseTrad
# ??? === MacCroatian
# ??? === MacCyrillic
# ??? === MacDingbats
# ??? === MacFarsi
# ??? === MacGreek
# ??? === MacHebrew
# ??? === MacIcelandic
# ??? === MacJapanese
# ??? === MacKorean
# ??? === MacRomanian
# ??? === MacRumanian
# ??? === MacSami
# ??? === MacThai
# ??? === MacTurkish
# ??? === MacUkrainian
# ??? === MacVietnamese
# ??? === cp1006
# ??? === dingbats
# ??? === nextstep
# ??? === posix-bc
# The following aliases are listed in RT#18802:
ISO-8859-10 === 8859-10 === ISO_8859-10:1993
# TCVN-5712 x-viet-tcvn viet-tcvn VN-1 TCVN-5712:1993
TIS-620 === TIS_620-2553 === TIS_620-2553:1990
# VPS x-viet-vps viet-vps
# The above aliases are listed in RT#18802
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
  } # _init_data_extra


sub _init_data
  {
  # This big piece of data is the original document from
  # http://www.iana.org/assignments/character-sets
  return <<'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE';
<?xml version='1.0' encoding='UTF-8'?>
<?xml-stylesheet type="text/xsl" href="character-sets.xsl"?>
<?oxygen RNGSchema="character-sets.rng" type="xml"?>
<registry xmlns="http://www.iana.org/assignments" id="character-sets">
  <updated>2013-10-01</updated>
  <title>Character Sets</title>
  <category>Character Sets</category>
  <xref type="rfc" data="rfc2978"/>
  <registration_rule>Expert Review</registration_rule>
  <expert>Primary Expert Ned Freed and Secondary Expert Martin D�rst</expert>
  <note>These are the official names for character sets that may be used in
the Internet and may be referred to in Internet documentation.  These
names are expressed in ANSI_X3.4-1968 which is commonly called
US-ASCII or simply ASCII.  The character set most commonly use in the
Internet and used especially in protocol standards is US-ASCII, this
is strongly encouraged.  The use of the name US-ASCII is also
encouraged.

The character set names may be up to 40 characters taken from the
printable characters of US-ASCII.  However, no distinction is made
between use of upper and lower case letters.

The MIBenum value is a unique value for use in MIBs to identify coded
character sets.

The value space for MIBenum values has been divided into three
regions. The first region (3-999) consists of coded character sets
that have been standardized by some standard setting organization.
This region is intended for standards that do not have subset
implementations. The second region (1000-1999) is for the Unicode and
ISO/IEC 10646 coded character sets together with a specification of a
(set of) sub-repertoires that may occur.  The third region (&gt;1999) is
intended for vendor specific coded character sets.

        Assigned MIB enum Numbers
        -------------------------
        0-2             Reserved
        3-999           Set By Standards Organizations
        1000-1999       Unicode / 10646
        2000-2999       Vendor

The aliases that start with "cs" have been added for use with the
IANA-CHARSET-MIB as originally defined in <xref type="rfc" data="rfc3808"/>, and as currently
maintained by IANA at <xref type="registry" data="ianacharset-mib"/>.
Note that the ianacharset-mib needs to be kept in sync with this
registry.  These aliases that start with "cs" contain the standard
numbers along with suggestive names in order to facilitate applications
that want to display the names in user interfaces.  The "cs" stands
for character set and is provided for applications that need a lower
case first letter but want to use mixed case thereafter that cannot
contain any special characters, such as underbar ("_") and dash ("-").

If the character set is from an ISO standard, its cs alias is the ISO
standard number or name.  If the character set is not from an ISO
standard, but is registered with ISO (IPSJ/ITSCJ is the current ISO
Registration Authority), the ISO Registry number is specified as
ISOnnn followed by letters suggestive of the name or standards number
of the code set.  When a national or international standard is
revised, the year of revision is added to the cs alias of the new
character set entry in the IANA Registry in order to distinguish the
revised character set from the original character set.</note>
  <registry id="character-sets-1">
    <record>
      <name>US-ASCII</name>
      <xref type="rfc" data="rfc2046"/>
      <value>3</value>
      <description>ANSI X3.4-1986</description>
      <alias>iso-ir-6</alias>
      <alias>ANSI_X3.4-1968</alias>
      <alias>ANSI_X3.4-1986</alias>
      <alias>ISO_646.irv:1991</alias>
      <alias>ISO646-US</alias>
      <alias>US-ASCII</alias>
      <alias>us</alias>
      <alias>IBM367</alias>
      <alias>cp367</alias>
      <alias>csASCII</alias>
      <preferred_alias>US-ASCII</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-1:1987</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>4</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-100</alias>
      <alias>ISO_8859-1</alias>
      <alias>ISO-8859-1</alias>
      <alias>latin1</alias>
      <alias>l1</alias>
      <alias>IBM819</alias>
      <alias>CP819</alias>
      <alias>csISOLatin1</alias>
      <preferred_alias>ISO-8859-1</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-2:1987</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>5</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-101</alias>
      <alias>ISO_8859-2</alias>
      <alias>ISO-8859-2</alias>
      <alias>latin2</alias>
      <alias>l2</alias>
      <alias>csISOLatin2</alias>
      <preferred_alias>ISO-8859-2</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-3:1988</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>6</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-109</alias>
      <alias>ISO_8859-3</alias>
      <alias>ISO-8859-3</alias>
      <alias>latin3</alias>
      <alias>l3</alias>
      <alias>csISOLatin3</alias>
      <preferred_alias>ISO-8859-3</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-4:1988</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>7</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-110</alias>
      <alias>ISO_8859-4</alias>
      <alias>ISO-8859-4</alias>
      <alias>latin4</alias>
      <alias>l4</alias>
      <alias>csISOLatin4</alias>
      <preferred_alias>ISO-8859-4</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-5:1988</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>8</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-144</alias>
      <alias>ISO_8859-5</alias>
      <alias>ISO-8859-5</alias>
      <alias>cyrillic</alias>
      <alias>csISOLatinCyrillic</alias>
      <preferred_alias>ISO-8859-5</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-6:1987</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>9</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-127</alias>
      <alias>ISO_8859-6</alias>
      <alias>ISO-8859-6</alias>
      <alias>ECMA-114</alias>
      <alias>ASMO-708</alias>
      <alias>arabic</alias>
      <alias>csISOLatinArabic</alias>
      <preferred_alias>ISO-8859-6</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-7:1987</name>
      <xref type="rfc" data="rfc1947"/>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>10</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-126</alias>
      <alias>ISO_8859-7</alias>
      <alias>ISO-8859-7</alias>
      <alias>ELOT_928</alias>
      <alias>ECMA-118</alias>
      <alias>greek</alias>
      <alias>greek8</alias>
      <alias>csISOLatinGreek</alias>
      <preferred_alias>ISO-8859-7</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-8:1988</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>11</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-138</alias>
      <alias>ISO_8859-8</alias>
      <alias>ISO-8859-8</alias>
      <alias>hebrew</alias>
      <alias>csISOLatinHebrew</alias>
      <preferred_alias>ISO-8859-8</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-9:1989</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>12</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-148</alias>
      <alias>ISO_8859-9</alias>
      <alias>ISO-8859-9</alias>
      <alias>latin5</alias>
      <alias>l5</alias>
      <alias>csISOLatin5</alias>
      <preferred_alias>ISO-8859-9</preferred_alias>
    </record>
    <record>
      <name>ISO-8859-10</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>13</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-157</alias>
      <alias>l6</alias>
      <alias>ISO_8859-10:1992</alias>
      <alias>csISOLatin6</alias>
      <alias>latin6</alias>
      <preferred_alias>ISO-8859-10</preferred_alias>
    </record>
    <record>
      <name>ISO_6937-2-add</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>14</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref> and ISO 6937-2:1983<br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-142</alias>
      <alias>csISOTextComm</alias>
    </record>
    <record>
      <name>JIS_X0201</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>15</value>
      <description>JIS X 0201-1976.   One byte only, this is equivalent to
JIS/Roman (similar to ASCII) plus eight-bit half-width
Katakana</description>
      <alias>X0201</alias>
      <alias>csHalfWidthKatakana</alias>
    </record>
    <record>
      <name>JIS_Encoding</name>
      <value>16</value>
      <description>JIS X 0202-1991.  Uses ISO 2022 escape sequences to
shift code sets as documented in JIS X 0202-1991.</description>
      <alias>csJISEncoding</alias>
    </record>
    <record>
      <name>Shift_JIS</name>
      <value>17</value>
      <description>This charset is an extension of csHalfWidthKatakana by
adding graphic characters in JIS X 0208.  The CCS's are
JIS X0201:1997 and JIS X0208:1997.  The
complete definition is shown in Appendix 1 of JIS
X0208:1997.
This charset can be used for the top-level media type "text".</description>
      <alias>MS_Kanji</alias>
      <alias>csShiftJIS</alias>
      <preferred_alias>Shift_JIS</preferred_alias>
    </record>
    <record>
      <name>Extended_UNIX_Code_Packed_Format_for_Japanese</name>
      <value>18</value>
      <description>Standardized by OSF, UNIX International, and UNIX Systems
Laboratories Pacific.  Uses ISO 2022 rules to select
code set 0: US-ASCII (a single 7-bit byte set)
code set 1: JIS X0208-1990 (a double 8-bit byte set)
restricted to A0-FF in both bytes
code set 2: Half Width Katakana (a single 7-bit byte set)
requiring SS2 as the character prefix
code set 3: JIS X0212-1990 (a double 7-bit byte set)
restricted to A0-FF in both bytes
requiring SS3 as the character prefix</description>
      <alias>csEUCPkdFmtJapanese</alias>
      <alias>EUC-JP</alias>
      <preferred_alias>EUC-JP</preferred_alias>
    </record>
    <record>
      <name>Extended_UNIX_Code_Fixed_Width_for_Japanese</name>
      <value>19</value>
      <description>Used in Japan.  Each character is 2 octets.
code set 0: US-ASCII (a single 7-bit byte set)
1st byte = 00
2nd byte = 20-7E
code set 1: JIS X0208-1990 (a double 7-bit byte set)
restricted  to A0-FF in both bytes
code set 2: Half Width Katakana (a single 7-bit byte set)
1st byte = 00
2nd byte = A0-FF
code set 3: JIS X0212-1990 (a double 7-bit byte set)
restricted to A0-FF in
the first byte
and 21-7E in the second byte</description>
      <alias>csEUCFixWidJapanese</alias>
    </record>
    <record>
      <name>BS_4730</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>20</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-4</alias>
      <alias>ISO646-GB</alias>
      <alias>gb</alias>
      <alias>uk</alias>
      <alias>csISO4UnitedKingdom</alias>
    </record>
    <record>
      <name>SEN_850200_C</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>21</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-11</alias>
      <alias>ISO646-SE2</alias>
      <alias>se2</alias>
      <alias>csISO11SwedishForNames</alias>
    </record>
    <record>
      <name>IT</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>22</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-15</alias>
      <alias>ISO646-IT</alias>
      <alias>csISO15Italian</alias>
    </record>
    <record>
      <name>ES</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>23</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-17</alias>
      <alias>ISO646-ES</alias>
      <alias>csISO17Spanish</alias>
    </record>
    <record>
      <name>DIN_66003</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>24</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-21</alias>
      <alias>de</alias>
      <alias>ISO646-DE</alias>
      <alias>csISO21German</alias>
    </record>
    <record>
      <name>NS_4551-1</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>25</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-60</alias>
      <alias>ISO646-NO</alias>
      <alias>no</alias>
      <alias>csISO60DanishNorwegian</alias>
      <alias>csISO60Norwegian1</alias>
    </record>
    <record>
      <name>NF_Z_62-010</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>26</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-69</alias>
      <alias>ISO646-FR</alias>
      <alias>fr</alias>
      <alias>csISO69French</alias>
    </record>
    <record>
      <name>ISO-10646-UTF-1</name>
      <value>27</value>
      <description>Universal Transfer Format (1), this is the multibyte
encoding, that subsets ASCII-7. It does not have byte
ordering issues.</description>
      <alias>csISO10646UTF1</alias>
    </record>
    <record>
      <name>ISO_646.basic:1983</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>28</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>ref</alias>
      <alias>csISO646basic1983</alias>
    </record>
    <record>
      <name>INVARIANT</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>29</value>
      <alias>csINVARIANT</alias>
    </record>
    <record>
      <name>ISO_646.irv:1983</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>30</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-2</alias>
      <alias>irv</alias>
      <alias>csISO2IntlRefVersion</alias>
    </record>
    <record>
      <name>NATS-SEFI</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>31</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-8-1</alias>
      <alias>csNATSSEFI</alias>
    </record>
    <record>
      <name>NATS-SEFI-ADD</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>32</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-8-2</alias>
      <alias>csNATSSEFIADD</alias>
    </record>
    <record>
      <name>NATS-DANO</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>33</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-9-1</alias>
      <alias>csNATSDANO</alias>
    </record>
    <record>
      <name>NATS-DANO-ADD</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>34</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-9-2</alias>
      <alias>csNATSDANOADD</alias>
    </record>
    <record>
      <name>SEN_850200_B</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>35</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-10</alias>
      <alias>FI</alias>
      <alias>ISO646-FI</alias>
      <alias>ISO646-SE</alias>
      <alias>se</alias>
      <alias>csISO10Swedish</alias>
    </record>
    <record>
      <name>KS_C_5601-1987</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>36</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-149</alias>
      <alias>KS_C_5601-1989</alias>
      <alias>KSC_5601</alias>
      <alias>korean</alias>
      <alias>csKSC56011987</alias>
    </record>
    <record>
      <name>ISO-2022-KR</name>
      <xref type="rfc" data="rfc1557"/>
      <xref type="person" data="Woohyong_Choi"/>
      <value>37</value>
      <description><xref type="rfc" data="rfc1557"/> (see also KS_C_5601-1987)</description>
      <alias>csISO2022KR</alias>
      <preferred_alias>ISO-2022-KR</preferred_alias>
    </record>
    <record>
      <name>EUC-KR</name>
      <xref type="rfc" data="rfc1557"/>
      <xref type="person" data="Woohyong_Choi"/>
      <value>38</value>
      <description><xref type="rfc" data="rfc1557"/> (see also KS_C_5861-1992)</description>
      <alias>csEUCKR</alias>
      <preferred_alias>EUC-KR</preferred_alias>
    </record>
    <record>
      <name>ISO-2022-JP</name>
      <xref type="rfc" data="rfc1468"/>
      <xref type="person" data="Jun_Murai"/>
      <value>39</value>
      <description><xref type="rfc" data="rfc1468"/> (see also <xref type="rfc" data="rfc2237"/>)</description>
      <alias>csISO2022JP</alias>
      <preferred_alias>ISO-2022-JP</preferred_alias>
    </record>
    <record date="1995-07">
      <name>ISO-2022-JP-2</name>
      <xref type="rfc" data="rfc1554"/>
      <xref type="person" data="Masataka_Ohta"/>
      <value>40</value>
      <description>
        <xref type="rfc" data="rfc1554"/>
      </description>
      <alias>csISO2022JP2</alias>
      <preferred_alias>ISO-2022-JP-2</preferred_alias>
    </record>
    <record>
      <name>JIS_C6220-1969-jp</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>41</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>JIS_C6220-1969</alias>
      <alias>iso-ir-13</alias>
      <alias>katakana</alias>
      <alias>x0201-7</alias>
      <alias>csISO13JISC6220jp</alias>
    </record>
    <record>
      <name>JIS_C6220-1969-ro</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>42</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-14</alias>
      <alias>jp</alias>
      <alias>ISO646-JP</alias>
      <alias>csISO14JISC6220ro</alias>
    </record>
    <record>
      <name>PT</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>43</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-16</alias>
      <alias>ISO646-PT</alias>
      <alias>csISO16Portuguese</alias>
    </record>
    <record>
      <name>greek7-old</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>44</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-18</alias>
      <alias>csISO18Greek7Old</alias>
    </record>
    <record>
      <name>latin-greek</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>45</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-19</alias>
      <alias>csISO19LatinGreek</alias>
    </record>
    <record>
      <name>NF_Z_62-010_(1973)</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>46</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-25</alias>
      <alias>ISO646-FR1</alias>
      <alias>csISO25French</alias>
    </record>
    <record>
      <name>Latin-greek-1</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>47</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-27</alias>
      <alias>csISO27LatinGreek1</alias>
    </record>
    <record>
      <name>ISO_5427</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>48</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-37</alias>
      <alias>csISO5427Cyrillic</alias>
    </record>
    <record>
      <name>JIS_C6226-1978</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>49</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-42</alias>
      <alias>csISO42JISC62261978</alias>
    </record>
    <record>
      <name>BS_viewdata</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>50</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-47</alias>
      <alias>csISO47BSViewdata</alias>
    </record>
    <record>
      <name>INIS</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>51</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-49</alias>
      <alias>csISO49INIS</alias>
    </record>
    <record>
      <name>INIS-8</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>52</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-50</alias>
      <alias>csISO50INIS8</alias>
    </record>
    <record>
      <name>INIS-cyrillic</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>53</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-51</alias>
      <alias>csISO51INISCyrillic</alias>
    </record>
    <record>
      <name>ISO_5427:1981</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>54</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-54</alias>
      <alias>ISO5427Cyrillic1981</alias>
      <alias>csISO54271981</alias>
    </record>
    <record>
      <name>ISO_5428:1980</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>55</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-55</alias>
      <alias>csISO5428Greek</alias>
    </record>
    <record>
      <name>GB_1988-80</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>56</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-57</alias>
      <alias>cn</alias>
      <alias>ISO646-CN</alias>
      <alias>csISO57GB1988</alias>
    </record>
    <record>
      <name>GB_2312-80</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>57</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-58</alias>
      <alias>chinese</alias>
      <alias>csISO58GB231280</alias>
    </record>
    <record>
      <name>NS_4551-2</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>58</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>ISO646-NO2</alias>
      <alias>iso-ir-61</alias>
      <alias>no2</alias>
      <alias>csISO61Norwegian2</alias>
    </record>
    <record>
      <name>videotex-suppl</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>59</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-70</alias>
      <alias>csISO70VideotexSupp1</alias>
    </record>
    <record>
      <name>PT2</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>60</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-84</alias>
      <alias>ISO646-PT2</alias>
      <alias>csISO84Portuguese2</alias>
    </record>
    <record>
      <name>ES2</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>61</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-85</alias>
      <alias>ISO646-ES2</alias>
      <alias>csISO85Spanish2</alias>
    </record>
    <record>
      <name>MSZ_7795.3</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>62</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-86</alias>
      <alias>ISO646-HU</alias>
      <alias>hu</alias>
      <alias>csISO86Hungarian</alias>
    </record>
    <record>
      <name>JIS_C6226-1983</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>63</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-87</alias>
      <alias>x0208</alias>
      <alias>JIS_X0208-1983</alias>
      <alias>csISO87JISX0208</alias>
    </record>
    <record>
      <name>greek7</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>64</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-88</alias>
      <alias>csISO88Greek7</alias>
    </record>
    <record>
      <name>ASMO_449</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>65</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>ISO_9036</alias>
      <alias>arabic7</alias>
      <alias>iso-ir-89</alias>
      <alias>csISO89ASMO449</alias>
    </record>
    <record>
      <name>iso-ir-90</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>66</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>csISO90</alias>
    </record>
    <record>
      <name>JIS_C6229-1984-a</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>67</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-91</alias>
      <alias>jp-ocr-a</alias>
      <alias>csISO91JISC62291984a</alias>
    </record>
    <record>
      <name>JIS_C6229-1984-b</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>68</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-92</alias>
      <alias>ISO646-JP-OCR-B</alias>
      <alias>jp-ocr-b</alias>
      <alias>csISO92JISC62991984b</alias>
    </record>
    <record>
      <name>JIS_C6229-1984-b-add</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>69</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-93</alias>
      <alias>jp-ocr-b-add</alias>
      <alias>csISO93JIS62291984badd</alias>
    </record>
    <record>
      <name>JIS_C6229-1984-hand</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>70</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-94</alias>
      <alias>jp-ocr-hand</alias>
      <alias>csISO94JIS62291984hand</alias>
    </record>
    <record>
      <name>JIS_C6229-1984-hand-add</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>71</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-95</alias>
      <alias>jp-ocr-hand-add</alias>
      <alias>csISO95JIS62291984handadd</alias>
    </record>
    <record>
      <name>JIS_C6229-1984-kana</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>72</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-96</alias>
      <alias>csISO96JISC62291984kana</alias>
    </record>
    <record>
      <name>ISO_2033-1983</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>73</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-98</alias>
      <alias>e13b</alias>
      <alias>csISO2033</alias>
    </record>
    <record>
      <name>ANSI_X3.110-1983</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>74</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-99</alias>
      <alias>CSA_T500-1983</alias>
      <alias>NAPLPS</alias>
      <alias>csISO99NAPLPS</alias>
    </record>
    <record>
      <name>T.61-7bit</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>75</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-102</alias>
      <alias>csISO102T617bit</alias>
    </record>
    <record>
      <name>T.61-8bit</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>76</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>T.61</alias>
      <alias>iso-ir-103</alias>
      <alias>csISO103T618bit</alias>
    </record>
    <record>
      <name>ECMA-cyrillic</name>
      <value>77</value>
      <description><xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/111.pdf">ISO registry</xref>
        (formerly <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ECMA
          registry</xref>)</description>
      <alias>iso-ir-111</alias>
      <alias>KOI8-E</alias>
      <alias>csISO111ECMACyrillic</alias>
    </record>
    <record>
      <name>CSA_Z243.4-1985-1</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>78</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-121</alias>
      <alias>ISO646-CA</alias>
      <alias>csa7-1</alias>
      <alias>csa71</alias>
      <alias>ca</alias>
      <alias>csISO121Canadian1</alias>
    </record>
    <record>
      <name>CSA_Z243.4-1985-2</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>79</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-122</alias>
      <alias>ISO646-CA2</alias>
      <alias>csa7-2</alias>
      <alias>csa72</alias>
      <alias>csISO122Canadian2</alias>
    </record>
    <record>
      <name>CSA_Z243.4-1985-gr</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>80</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-123</alias>
      <alias>csISO123CSAZ24341985gr</alias>
    </record>
    <record>
      <name>ISO_8859-6-E</name>
      <xref type="rfc" data="rfc1556"/>
      <xref type="person" data="IANA"/>
      <value>81</value>
      <description>
        <xref type="rfc" data="rfc1556"/>
      </description>
      <alias>csISO88596E</alias>
      <alias>ISO-8859-6-E</alias>
      <preferred_alias>ISO-8859-6-E</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-6-I</name>
      <xref type="rfc" data="rfc1556"/>
      <xref type="person" data="IANA"/>
      <value>82</value>
      <description>
        <xref type="rfc" data="rfc1556"/>
      </description>
      <alias>csISO88596I</alias>
      <alias>ISO-8859-6-I</alias>
      <preferred_alias>ISO-8859-6-I</preferred_alias>
    </record>
    <record>
      <name>T.101-G2</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>83</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-128</alias>
      <alias>csISO128T101G2</alias>
    </record>
    <record>
      <name>ISO_8859-8-E</name>
      <xref type="rfc" data="rfc1556"/>
      <xref type="person" data="Hank_Nussbacher"/>
      <value>84</value>
      <description>
        <xref type="rfc" data="rfc1556"/>
      </description>
      <alias>csISO88598E</alias>
      <alias>ISO-8859-8-E</alias>
      <preferred_alias>ISO-8859-8-E</preferred_alias>
    </record>
    <record>
      <name>ISO_8859-8-I</name>
      <xref type="rfc" data="rfc1556"/>
      <xref type="person" data="Hank_Nussbacher"/>
      <value>85</value>
      <description>
        <xref type="rfc" data="rfc1556"/>
      </description>
      <alias>csISO88598I</alias>
      <alias>ISO-8859-8-I</alias>
      <preferred_alias>ISO-8859-8-I</preferred_alias>
    </record>
    <record>
      <name>CSN_369103</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>86</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-139</alias>
      <alias>csISO139CSN369103</alias>
    </record>
    <record>
      <name>JUS_I.B1.002</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>87</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-141</alias>
      <alias>ISO646-YU</alias>
      <alias>js</alias>
      <alias>yu</alias>
      <alias>csISO141JUSIB1002</alias>
    </record>
    <record>
      <name>IEC_P27-1</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>88</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-143</alias>
      <alias>csISO143IECP271</alias>
    </record>
    <record>
      <name>JUS_I.B1.003-serb</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>89</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-146</alias>
      <alias>serbian</alias>
      <alias>csISO146Serbian</alias>
    </record>
    <record>
      <name>JUS_I.B1.003-mac</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>90</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>macedonian</alias>
      <alias>iso-ir-147</alias>
      <alias>csISO147Macedonian</alias>
    </record>
    <record>
      <name>greek-ccitt</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>91</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-150</alias>
      <alias>csISO150</alias>
      <alias>csISO150GreekCCITT</alias>
    </record>
    <record>
      <name>NC_NC00-10:81</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>92</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>cuba</alias>
      <alias>iso-ir-151</alias>
      <alias>ISO646-CU</alias>
      <alias>csISO151Cuba</alias>
    </record>
    <record>
      <name>ISO_6937-2-25</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>93</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-152</alias>
      <alias>csISO6937Add</alias>
    </record>
    <record>
      <name>GOST_19768-74</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>94</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>ST_SEV_358-88</alias>
      <alias>iso-ir-153</alias>
      <alias>csISO153GOST1976874</alias>
    </record>
    <record>
      <name>ISO_8859-supp</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>95</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-154</alias>
      <alias>latin1-2-5</alias>
      <alias>csISO8859Supp</alias>
    </record>
    <record>
      <name>ISO_10367-box</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>96</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>iso-ir-155</alias>
      <alias>csISO10367Box</alias>
    </record>
    <record>
      <name>latin-lap</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>97</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>lap</alias>
      <alias>iso-ir-158</alias>
      <alias>csISO158Lap</alias>
    </record>
    <record>
      <name>JIS_X0212-1990</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>98</value>
      <description>
        <xref type="uri" data="http://www.itscj.ipsj.or.jp/ISO-IR/">ISO-IR: International Register of Escape Sequences</xref><br/>
        Note: The current registration authority is IPSJ/ITSCJ, Japan.
      </description>
      <alias>x0212</alias>
      <alias>iso-ir-159</alias>
      <alias>csISO159JISX02121990</alias>
    </record>
    <record>
      <name>DS_2089</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>99</value>
      <description>Danish Standard, DS 2089, February 1974</description>
      <alias>DS2089</alias>
      <alias>ISO646-DK</alias>
      <alias>dk</alias>
      <alias>csISO646Danish</alias>
    </record>
    <record>
      <name>us-dk</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>100</value>
      <alias>csUSDK</alias>
    </record>
    <record>
      <name>dk-us</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>101</value>
      <alias>csDKUS</alias>
    </record>
    <record>
      <name>KSC5636</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>102</value>
      <alias>ISO646-KR</alias>
      <alias>csKSC5636</alias>
    </record>
    <record>
      <name>UNICODE-1-1-UTF-7</name>
      <xref type="rfc" data="rfc1642"/>
      <value>103</value>
      <description>
        <xref type="rfc" data="rfc1642"/>
      </description>
      <alias>csUnicode11UTF7</alias>
    </record>
    <record>
      <name>ISO-2022-CN</name>
      <xref type="rfc" data="rfc1922"/>
      <value>104</value>
      <description>
        <xref type="rfc" data="rfc1922"/>
      </description>
      <alias>csISO2022CN</alias>
    </record>
    <record>
      <name>ISO-2022-CN-EXT</name>
      <xref type="rfc" data="rfc1922"/>
      <value>105</value>
      <description>
        <xref type="rfc" data="rfc1922"/>
      </description>
      <alias>csISO2022CNEXT</alias>
    </record>
    <record>
      <name>UTF-8</name>
      <xref type="rfc" data="rfc3629"/>
      <value>106</value>
      <description>
        <xref type="rfc" data="rfc3629"/>
      </description>
      <alias>csUTF8</alias>
    </record>
    <record date="2000-08">
      <name>ISO-8859-13</name>
      <value>109</value>
      <description>ISO See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/ISO-8859-13"/><xref type="person" data="Vladas_Tumasonis"/></description>
      <alias>csISO885913</alias>
    </record>
    <record date="2000-08">
      <name>ISO-8859-14</name>
      <value>110</value>
      <description>ISO See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/ISO-8859-14"/> <xref type="person" data="Keld_Simonsen_2"/></description>
      <alias>iso-ir-199</alias>
      <alias>ISO_8859-14:1998</alias>
      <alias>ISO_8859-14</alias>
      <alias>latin8</alias>
      <alias>iso-celtic</alias>
      <alias>l8</alias>
      <alias>csISO885914</alias>
    </record>
    <record>
      <name>ISO-8859-15</name>
      <value>111</value>
      <description>ISO
Please see: <xref type="uri" data="http://www.iana.org/assignments/charset-reg/ISO-8859-15"/></description>
      <alias>ISO_8859-15</alias>
      <alias>Latin-9</alias>
      <alias>csISO885915</alias>
    </record>
    <record>
      <name>ISO-8859-16</name>
      <value>112</value>
      <description>ISO</description>
      <alias>iso-ir-226</alias>
      <alias>ISO_8859-16:2001</alias>
      <alias>ISO_8859-16</alias>
      <alias>latin10</alias>
      <alias>l10</alias>
      <alias>csISO885916</alias>
    </record>
    <record>
      <name>GBK</name>
      <value>113</value>
      <description>Chinese IT Standardization Technical Committee
Please see: <xref type="uri" data="http://www.iana.org/assignments/charset-reg/GBK"/></description>
      <alias>CP936</alias>
      <alias>MS936</alias>
      <alias>windows-936</alias>
      <alias>csGBK</alias>
    </record>
    <record>
      <name>GB18030</name>
      <value>114</value>
      <description>Chinese IT Standardization Technical Committee
Please see: <xref type="uri" data="http://www.iana.org/assignments/charset-reg/GB18030"/></description>
      <alias>csGB18030</alias>
    </record>
    <record>
      <name>OSD_EBCDIC_DF04_15</name>
      <value>115</value>
      <description>Fujitsu-Siemens standard mainframe EBCDIC encoding
Please see: <xref type="uri" data="http://www.iana.org/assignments/charset-reg/OSD-EBCDIC-DF04-15"/></description>
      <alias>csOSDEBCDICDF0415</alias>
    </record>
    <record>
      <name>OSD_EBCDIC_DF03_IRV</name>
      <value>116</value>
      <description>Fujitsu-Siemens standard mainframe EBCDIC encoding
Please see: <xref type="uri" data="http://www.iana.org/assignments/charset-reg/OSD-EBCDIC-DF03-IRV"/></description>
      <alias>csOSDEBCDICDF03IRV</alias>
    </record>
    <record>
      <name>OSD_EBCDIC_DF04_1</name>
      <value>117</value>
      <description>Fujitsu-Siemens standard mainframe EBCDIC encoding
Please see: <xref type="uri" data="http://www.iana.org/assignments/charset-reg/OSD-EBCDIC-DF04-1"/></description>
      <alias>csOSDEBCDICDF041</alias>
    </record>
    <record date="2006-12-07">
      <name>ISO-11548-1</name>
      <value>118</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/ISO-11548-1"/>            <xref type="person" data="Samuel_Thibault"/></description>
      <alias>ISO_11548-1</alias>
      <alias>ISO_TR_11548-1</alias>
      <alias>csISO115481</alias>
    </record>
    <record date="2006-12-07">
      <name>KZ-1048</name>
      <value>119</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/KZ-1048"/>      <xref type="person" data="Sairan_M_Kikkarin"/><xref type="person" data="Alexei_Veremeev"/></description>
      <alias>STRK1048-2002</alias>
      <alias>RK1048</alias>
      <alias>csKZ1048</alias>
    </record>
    <record>
      <name>ISO-10646-UCS-2</name>
      <value>1000</value>
      <description>the 2-octet Basic Multilingual Plane, aka Unicode
this needs to specify network byte order: the standard
does not specify (it is a 16-bit integer space)</description>
      <alias>csUnicode</alias>
    </record>
    <record>
      <name>ISO-10646-UCS-4</name>
      <value>1001</value>
      <description>the full code space. (same comment about byte order,
these are 31-bit numbers.</description>
      <alias>csUCS4</alias>
    </record>
    <record>
      <name>ISO-10646-UCS-Basic</name>
      <value>1002</value>
      <description>ASCII subset of Unicode.  Basic Latin = collection 1
See ISO 10646, Appendix A</description>
      <alias>csUnicodeASCII</alias>
    </record>
    <record>
      <name>ISO-10646-Unicode-Latin1</name>
      <value>1003</value>
      <description>ISO Latin-1 subset of Unicode. Basic Latin and Latin-1
Supplement  = collections 1 and 2.  See ISO 10646,
Appendix A.  See <xref type="rfc" data="rfc1815"/>.</description>
      <alias>csUnicodeLatin1</alias>
      <alias>ISO-10646</alias>
    </record>
    <record>
      <name>ISO-10646-J-1</name>
      <value>1004</value>
      <description>ISO 10646 Japanese, see <xref type="rfc" data="rfc1815"/>.</description>
      <alias>csUnicodeJapanese</alias>
    </record>
    <record>
      <name>ISO-Unicode-IBM-1261</name>
      <value>1005</value>
      <description>IBM Latin-2, -3, -5, Extended Presentation Set, GCSGID: 1261</description>
      <alias>csUnicodeIBM1261</alias>
    </record>
    <record>
      <name>ISO-Unicode-IBM-1268</name>
      <value>1006</value>
      <description>IBM Latin-4 Extended Presentation Set, GCSGID: 1268</description>
      <alias>csUnicodeIBM1268</alias>
    </record>
    <record>
      <name>ISO-Unicode-IBM-1276</name>
      <value>1007</value>
      <description>IBM Cyrillic Greek Extended Presentation Set, GCSGID: 1276</description>
      <alias>csUnicodeIBM1276</alias>
    </record>
    <record>
      <name>ISO-Unicode-IBM-1264</name>
      <value>1008</value>
      <description>IBM Arabic Presentation Set, GCSGID: 1264</description>
      <alias>csUnicodeIBM1264</alias>
    </record>
    <record>
      <name>ISO-Unicode-IBM-1265</name>
      <value>1009</value>
      <description>IBM Hebrew Presentation Set, GCSGID: 1265</description>
      <alias>csUnicodeIBM1265</alias>
    </record>
    <record>
      <name>UNICODE-1-1</name>
      <xref type="rfc" data="rfc1641"/>
      <value>1010</value>
      <description>
        <xref type="rfc" data="rfc1641"/>
      </description>
      <alias>csUnicode11</alias>
    </record>
    <record date="2002-09">
      <name>SCSU</name>
      <value>1011</value>
      <description>SCSU See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/SCSU"/>     <xref type="person" data="Markus_Scherer"/></description>
      <alias>csSCSU</alias>
    </record>
    <record>
      <name>UTF-7</name>
      <xref type="rfc" data="rfc2152"/>
      <value>1012</value>
      <description>
        <xref type="rfc" data="rfc2152"/>
      </description>
      <alias>csUTF7</alias>
    </record>
    <record>
      <name>UTF-16BE</name>
      <xref type="rfc" data="rfc2781"/>
      <value>1013</value>
      <description>
        <xref type="rfc" data="rfc2781"/>
      </description>
      <alias>csUTF16BE</alias>
    </record>
    <record>
      <name>UTF-16LE</name>
      <xref type="rfc" data="rfc2781"/>
      <value>1014</value>
      <description>
        <xref type="rfc" data="rfc2781"/>
      </description>
      <alias>csUTF16LE</alias>
    </record>
    <record>
      <name>UTF-16</name>
      <xref type="rfc" data="rfc2781"/>
      <value>1015</value>
      <description>
        <xref type="rfc" data="rfc2781"/>
      </description>
      <alias>csUTF16</alias>
    </record>
    <record date="2002-03">
      <name>CESU-8</name>
      <xref type="person" data="Toby_Phipps"/>
      <value>1016</value>
      <description>
        <xref type="uri" data="http://www.unicode.org/unicode/reports/tr26"/>
      </description>
      <alias>csCESU8</alias>
      <alias>csCESU-8</alias>
    </record>
    <record date="2002-04">
      <name>UTF-32</name>
      <xref type="person" data="Mark_Davis"/>
      <value>1017</value>
      <description>
        <xref type="uri" data="http://www.unicode.org/unicode/reports/tr19/"/>
      </description>
      <alias>csUTF32</alias>
    </record>
    <record date="2002-04">
      <name>UTF-32BE</name>
      <xref type="person" data="Mark_Davis"/>
      <value>1018</value>
      <description>
        <xref type="uri" data="http://www.unicode.org/unicode/reports/tr19/"/>
      </description>
      <alias>csUTF32BE</alias>
    </record>
    <record date="2002-04">
      <name>UTF-32LE</name>
      <xref type="person" data="Mark_Davis"/>
      <value>1019</value>
      <description>
        <xref type="uri" data="http://www.unicode.org/unicode/reports/tr19/"/>
      </description>
      <alias>csUTF32LE</alias>
    </record>
    <record date="2002-09">
      <name>BOCU-1</name>
      <xref type="person" data="Markus_Scherer"/>
      <value>1020</value>
      <description>
        <xref type="uri" data="http://www.unicode.org/notes/tn6/"/>
      </description>
      <alias>csBOCU1</alias>
      <alias>csBOCU-1</alias>
    </record>
    <record>
      <name>ISO-8859-1-Windows-3.0-Latin-1</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2000</value>
      <description>Extended ISO 8859-1 Latin-1 for Windows 3.0.
PCL Symbol Set id: 9U</description>
      <alias>csWindows30Latin1</alias>
    </record>
    <record>
      <name>ISO-8859-1-Windows-3.1-Latin-1</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2001</value>
      <description>Extended ISO 8859-1 Latin-1 for Windows 3.1.
PCL Symbol Set id: 19U</description>
      <alias>csWindows31Latin1</alias>
    </record>
    <record>
      <name>ISO-8859-2-Windows-Latin-2</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2002</value>
      <description>Extended ISO 8859-2.  Latin-2 for Windows 3.1.
PCL Symbol Set id: 9E</description>
      <alias>csWindows31Latin2</alias>
    </record>
    <record>
      <name>ISO-8859-9-Windows-Latin-5</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2003</value>
      <description>Extended ISO 8859-9.  Latin-5 for Windows 3.1
PCL Symbol Set id: 5T</description>
      <alias>csWindows31Latin5</alias>
    </record>
    <record>
      <name>hp-roman8</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2004</value>
      <description>LaserJet IIP Printer User's Manual,
HP part no 33471-90901, Hewlet-Packard, June 1989.</description>
      <alias>roman8</alias>
      <alias>r8</alias>
      <alias>csHPRoman8</alias>
    </record>
    <record>
      <name>Adobe-Standard-Encoding</name>
      <xref type="text">Adobe Systems Incorporated, PostScript Language Reference
Manual, second edition, Addison-Wesley Publishing Company,
Inc., 1990.</xref>
      <value>2005</value>
      <description>PostScript Language Reference Manual
PCL Symbol Set id: 10J</description>
      <alias>csAdobeStandardEncoding</alias>
    </record>
    <record>
      <name>Ventura-US</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2006</value>
      <description>Ventura US.  ASCII plus characters typically used in
publishing, like pilcrow, copyright, registered, trade mark,
section, dagger, and double dagger in the range A0 (hex)
to FF (hex).
PCL Symbol Set id: 14J</description>
      <alias>csVenturaUS</alias>
    </record>
    <record>
      <name>Ventura-International</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2007</value>
      <description>Ventura International.  ASCII plus coded characters similar
to Roman8.
PCL Symbol Set id: 13J</description>
      <alias>csVenturaInternational</alias>
    </record>
    <record>
      <name>DEC-MCS</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2008</value>
      <description>VAX/VMS User's Manual,
Order Number: AI-Y517A-TE, April 1986.</description>
      <alias>dec</alias>
      <alias>csDECMCS</alias>
    </record>
    <record>
      <name>IBM850</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2009</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp850</alias>
      <alias>850</alias>
      <alias>csPC850Multilingual</alias>
    </record>
    <record>
      <name>PC8-Danish-Norwegian</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2012</value>
      <description>PC Danish Norwegian
8-bit PC set for Danish Norwegian
PCL Symbol Set id: 11U</description>
      <alias>csPC8DanishNorwegian</alias>
    </record>
    <record>
      <name>IBM862</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2013</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp862</alias>
      <alias>862</alias>
      <alias>csPC862LatinHebrew</alias>
    </record>
    <record>
      <name>PC8-Turkish</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2014</value>
      <description>PC Latin Turkish.  PCL Symbol Set id: 9T</description>
      <alias>csPC8Turkish</alias>
    </record>
    <record>
      <name>IBM-Symbols</name>
      <xref type="text">IBM Corporation, "ABOUT TYPE: IBM's Technical Reference
for Core Interchange Digitized Type", Publication number
S544-3708-01</xref>
      <value>2015</value>
      <description>Presentation Set, CPGID: 259</description>
      <alias>csIBMSymbols</alias>
    </record>
    <record>
      <name>IBM-Thai</name>
      <xref type="text">IBM Corporation, "ABOUT TYPE: IBM's Technical Reference
for Core Interchange Digitized Type", Publication number
S544-3708-01</xref>
      <value>2016</value>
      <description>Presentation Set, CPGID: 838</description>
      <alias>csIBMThai</alias>
    </record>
    <record>
      <name>HP-Legal</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2017</value>
      <description>PCL 5 Comparison Guide, Hewlett-Packard,
HP part number 5961-0510, October 1992
PCL Symbol Set id: 1U</description>
      <alias>csHPLegal</alias>
    </record>
    <record>
      <name>HP-Pi-font</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2018</value>
      <description>PCL 5 Comparison Guide, Hewlett-Packard,
HP part number 5961-0510, October 1992
PCL Symbol Set id: 15U</description>
      <alias>csHPPiFont</alias>
    </record>
    <record>
      <name>HP-Math8</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2019</value>
      <description>PCL 5 Comparison Guide, Hewlett-Packard,
HP part number 5961-0510, October 1992
PCL Symbol Set id: 8M</description>
      <alias>csHPMath8</alias>
    </record>
    <record>
      <name>Adobe-Symbol-Encoding</name>
      <xref type="text">Adobe Systems Incorporated, PostScript Language Reference
Manual, second edition, Addison-Wesley Publishing Company,
Inc., 1990.</xref>
      <value>2020</value>
      <description>PostScript Language Reference Manual
PCL Symbol Set id: 5M</description>
      <alias>csHPPSMath</alias>
    </record>
    <record>
      <name>HP-DeskTop</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2021</value>
      <description>PCL 5 Comparison Guide, Hewlett-Packard,
HP part number 5961-0510, October 1992
PCL Symbol Set id: 7J</description>
      <alias>csHPDesktop</alias>
    </record>
    <record>
      <name>Ventura-Math</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2022</value>
      <description>PCL 5 Comparison Guide, Hewlett-Packard,
HP part number 5961-0510, October 1992
PCL Symbol Set id: 6M</description>
      <alias>csVenturaMath</alias>
    </record>
    <record>
      <name>Microsoft-Publishing</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2023</value>
      <description>PCL 5 Comparison Guide, Hewlett-Packard,
HP part number 5961-0510, October 1992
PCL Symbol Set id: 6J</description>
      <alias>csMicrosoftPublishing</alias>
    </record>
    <record>
      <name>Windows-31J</name>
      <value>2024</value>
      <description>Windows Japanese.  A further extension of Shift_JIS
to include NEC special characters (Row 13), NEC
selection of IBM extensions (Rows 89 to 92), and IBM
extensions (Rows 115 to 119).  The CCS's are
JIS X0201:1997, JIS X0208:1997, and these extensions.
This charset can be used for the top-level media type "text",
but it is of limited or specialized use (see <xref type="rfc" data="rfc2278"/>).
PCL Symbol Set id: 19K</description>
      <alias>csWindows31J</alias>
    </record>
    <record>
      <name>GB2312</name>
      <value>2025</value>
      <description>Chinese for People's Republic of China (PRC) mixed one byte,
two byte set:
20-7E = one byte ASCII
A1-FE = two byte PRC Kanji
See GB 2312-80
PCL Symbol Set Id: 18C</description>
      <alias>csGB2312</alias>
      <preferred_alias>GB2312</preferred_alias>
    </record>
    <record>
      <name>Big5</name>
      <value>2026</value>
      <description>Chinese for Taiwan Multi-byte set.
PCL Symbol Set Id: 18T</description>
      <alias>csBig5</alias>
      <preferred_alias>Big5</preferred_alias>
    </record>
    <record>
      <name>macintosh</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2027</value>
      <description>The Unicode Standard ver1.0, ISBN 0-201-56788-1, Oct 1991</description>
      <alias>mac</alias>
      <alias>csMacintosh</alias>
    </record>
    <record>
      <name>IBM037</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2028</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp037</alias>
      <alias>ebcdic-cp-us</alias>
      <alias>ebcdic-cp-ca</alias>
      <alias>ebcdic-cp-wt</alias>
      <alias>ebcdic-cp-nl</alias>
      <alias>csIBM037</alias>
    </record>
    <record>
      <name>IBM038</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2029</value>
      <description>IBM 3174 Character Set Ref, GA27-3831-02, March 1990</description>
      <alias>EBCDIC-INT</alias>
      <alias>cp038</alias>
      <alias>csIBM038</alias>
    </record>
    <record>
      <name>IBM273</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2030</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP273</alias>
      <alias>csIBM273</alias>
    </record>
    <record>
      <name>IBM274</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2031</value>
      <description>IBM 3174 Character Set Ref, GA27-3831-02, March 1990</description>
      <alias>EBCDIC-BE</alias>
      <alias>CP274</alias>
      <alias>csIBM274</alias>
    </record>
    <record>
      <name>IBM275</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2032</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>EBCDIC-BR</alias>
      <alias>cp275</alias>
      <alias>csIBM275</alias>
    </record>
    <record>
      <name>IBM277</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2033</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>EBCDIC-CP-DK</alias>
      <alias>EBCDIC-CP-NO</alias>
      <alias>csIBM277</alias>
    </record>
    <record>
      <name>IBM278</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2034</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP278</alias>
      <alias>ebcdic-cp-fi</alias>
      <alias>ebcdic-cp-se</alias>
      <alias>csIBM278</alias>
    </record>
    <record>
      <name>IBM280</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2035</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP280</alias>
      <alias>ebcdic-cp-it</alias>
      <alias>csIBM280</alias>
    </record>
    <record>
      <name>IBM281</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2036</value>
      <description>IBM 3174 Character Set Ref, GA27-3831-02, March 1990</description>
      <alias>EBCDIC-JP-E</alias>
      <alias>cp281</alias>
      <alias>csIBM281</alias>
    </record>
    <record>
      <name>IBM284</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2037</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP284</alias>
      <alias>ebcdic-cp-es</alias>
      <alias>csIBM284</alias>
    </record>
    <record>
      <name>IBM285</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2038</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP285</alias>
      <alias>ebcdic-cp-gb</alias>
      <alias>csIBM285</alias>
    </record>
    <record>
      <name>IBM290</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2039</value>
      <description>IBM 3174 Character Set Ref, GA27-3831-02, March 1990</description>
      <alias>cp290</alias>
      <alias>EBCDIC-JP-kana</alias>
      <alias>csIBM290</alias>
    </record>
    <record>
      <name>IBM297</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2040</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp297</alias>
      <alias>ebcdic-cp-fr</alias>
      <alias>csIBM297</alias>
    </record>
    <record>
      <name>IBM420</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2041</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990,
IBM NLS RM p 11-11</description>
      <alias>cp420</alias>
      <alias>ebcdic-cp-ar1</alias>
      <alias>csIBM420</alias>
    </record>
    <record>
      <name>IBM423</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2042</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp423</alias>
      <alias>ebcdic-cp-gr</alias>
      <alias>csIBM423</alias>
    </record>
    <record>
      <name>IBM424</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2043</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp424</alias>
      <alias>ebcdic-cp-he</alias>
      <alias>csIBM424</alias>
    </record>
    <record>
      <name>IBM437</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2011</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp437</alias>
      <alias>437</alias>
      <alias>csPC8CodePage437</alias>
    </record>
    <record>
      <name>IBM500</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2044</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP500</alias>
      <alias>ebcdic-cp-be</alias>
      <alias>ebcdic-cp-ch</alias>
      <alias>csIBM500</alias>
    </record>
    <record>
      <name>IBM851</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2045</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp851</alias>
      <alias>851</alias>
      <alias>csIBM851</alias>
    </record>
    <record>
      <name>IBM852</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2010</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp852</alias>
      <alias>852</alias>
      <alias>csPCp852</alias>
    </record>
    <record>
      <name>IBM855</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2046</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp855</alias>
      <alias>855</alias>
      <alias>csIBM855</alias>
    </record>
    <record>
      <name>IBM857</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2047</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp857</alias>
      <alias>857</alias>
      <alias>csIBM857</alias>
    </record>
    <record>
      <name>IBM860</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2048</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp860</alias>
      <alias>860</alias>
      <alias>csIBM860</alias>
    </record>
    <record>
      <name>IBM861</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2049</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp861</alias>
      <alias>861</alias>
      <alias>cp-is</alias>
      <alias>csIBM861</alias>
    </record>
    <record>
      <name>IBM863</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2050</value>
      <description>IBM Keyboard layouts and code pages, PN 07G4586 June 1991</description>
      <alias>cp863</alias>
      <alias>863</alias>
      <alias>csIBM863</alias>
    </record>
    <record>
      <name>IBM864</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2051</value>
      <description>IBM Keyboard layouts and code pages, PN 07G4586 June 1991</description>
      <alias>cp864</alias>
      <alias>csIBM864</alias>
    </record>
    <record>
      <name>IBM865</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2052</value>
      <description>IBM DOS 3.3 Ref (Abridged), 94X9575 (Feb 1987)</description>
      <alias>cp865</alias>
      <alias>865</alias>
      <alias>csIBM865</alias>
    </record>
    <record>
      <name>IBM868</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2053</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP868</alias>
      <alias>cp-ar</alias>
      <alias>csIBM868</alias>
    </record>
    <record>
      <name>IBM869</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2054</value>
      <description>IBM Keyboard layouts and code pages, PN 07G4586 June 1991</description>
      <alias>cp869</alias>
      <alias>869</alias>
      <alias>cp-gr</alias>
      <alias>csIBM869</alias>
    </record>
    <record>
      <name>IBM870</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2055</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP870</alias>
      <alias>ebcdic-cp-roece</alias>
      <alias>ebcdic-cp-yu</alias>
      <alias>csIBM870</alias>
    </record>
    <record>
      <name>IBM871</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2056</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP871</alias>
      <alias>ebcdic-cp-is</alias>
      <alias>csIBM871</alias>
    </record>
    <record>
      <name>IBM880</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2057</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp880</alias>
      <alias>EBCDIC-Cyrillic</alias>
      <alias>csIBM880</alias>
    </record>
    <record>
      <name>IBM891</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2058</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp891</alias>
      <alias>csIBM891</alias>
    </record>
    <record>
      <name>IBM903</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2059</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp903</alias>
      <alias>csIBM903</alias>
    </record>
    <record>
      <name>IBM904</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2060</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>cp904</alias>
      <alias>904</alias>
      <alias>csIBBM904</alias>
    </record>
    <record>
      <name>IBM905</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2061</value>
      <description>IBM 3174 Character Set Ref, GA27-3831-02, March 1990</description>
      <alias>CP905</alias>
      <alias>ebcdic-cp-tr</alias>
      <alias>csIBM905</alias>
    </record>
    <record>
      <name>IBM918</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2062</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP918</alias>
      <alias>ebcdic-cp-ar2</alias>
      <alias>csIBM918</alias>
    </record>
    <record>
      <name>IBM1026</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2063</value>
      <description>IBM NLS RM Vol2 SE09-8002-01, March 1990</description>
      <alias>CP1026</alias>
      <alias>csIBM1026</alias>
    </record>
    <record>
      <name>EBCDIC-AT-DE</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2064</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csIBMEBCDICATDE</alias>
    </record>
    <record>
      <name>EBCDIC-AT-DE-A</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2065</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICATDEA</alias>
    </record>
    <record>
      <name>EBCDIC-CA-FR</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2066</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICCAFR</alias>
    </record>
    <record>
      <name>EBCDIC-DK-NO</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2067</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICDKNO</alias>
    </record>
    <record>
      <name>EBCDIC-DK-NO-A</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2068</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICDKNOA</alias>
    </record>
    <record>
      <name>EBCDIC-FI-SE</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2069</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICFISE</alias>
    </record>
    <record>
      <name>EBCDIC-FI-SE-A</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2070</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICFISEA</alias>
    </record>
    <record>
      <name>EBCDIC-FR</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2071</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICFR</alias>
    </record>
    <record>
      <name>EBCDIC-IT</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2072</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICIT</alias>
    </record>
    <record>
      <name>EBCDIC-PT</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2073</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICPT</alias>
    </record>
    <record>
      <name>EBCDIC-ES</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2074</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICES</alias>
    </record>
    <record>
      <name>EBCDIC-ES-A</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2075</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICESA</alias>
    </record>
    <record>
      <name>EBCDIC-ES-S</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2076</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICESS</alias>
    </record>
    <record>
      <name>EBCDIC-UK</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2077</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICUK</alias>
    </record>
    <record>
      <name>EBCDIC-US</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2078</value>
      <description>IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987</description>
      <alias>csEBCDICUS</alias>
    </record>
    <record>
      <name>UNKNOWN-8BIT</name>
      <xref type="rfc" data="rfc1428"/>
      <value>2079</value>
      <alias>csUnknown8BiT</alias>
    </record>
    <record>
      <name>MNEMONIC</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2080</value>
      <description><xref type="rfc" data="rfc1345"/>, also known as "mnemonic+ascii+38"</description>
      <alias>csMnemonic</alias>
    </record>
    <record>
      <name>MNEM</name>
      <xref type="rfc" data="rfc1345"/>
      <xref type="person" data="Keld_Simonsen"/>
      <value>2081</value>
      <description><xref type="rfc" data="rfc1345"/>, also known as "mnemonic+ascii+8200"</description>
      <alias>csMnem</alias>
    </record>
    <record>
      <name>VISCII</name>
      <xref type="rfc" data="rfc1456"/>
      <value>2082</value>
      <description>
        <xref type="rfc" data="rfc1456"/>
      </description>
      <alias>csVISCII</alias>
    </record>
    <record>
      <name>VIQR</name>
      <xref type="rfc" data="rfc1456"/>
      <value>2083</value>
      <description>
        <xref type="rfc" data="rfc1456"/>
      </description>
      <alias>csVIQR</alias>
    </record>
    <record>
      <name>KOI8-R</name>
      <xref type="rfc" data="rfc1489"/>
      <value>2084</value>
      <description><xref type="rfc" data="rfc1489"/>, based on GOST-19768-74, ISO-6937/8,
INIS-Cyrillic, ISO-5427.</description>
      <alias>csKOI8R</alias>
      <preferred_alias>KOI8-R</preferred_alias>
    </record>
    <record>
      <name>HZ-GB-2312</name>
      <value>2085</value>
      <description><xref type="rfc" data="rfc1842"/>, <xref type="rfc" data="rfc1843"/><xref type="rfc" data="rfc1843"/><xref type="rfc" data="rfc1842"/></description>
    </record>
    <record date="1997-03">
      <name>IBM866</name>
      <xref type="person" data="Rick_Pond"/>
      <value>2086</value>
      <description>IBM NLDG Volume 2 (SE09-8002-03) August 1994</description>
      <alias>cp866</alias>
      <alias>866</alias>
      <alias>csIBM866</alias>
    </record>
    <record>
      <name>IBM775</name>
      <xref type="text">Hewlett-Packard Company, "HP PCL 5 Comparison Guide",
(P/N 5021-0329) pp B-13, 1996.</xref>
      <value>2087</value>
      <description>HP PCL 5 Comparison Guide (P/N 5021-0329) pp B-13, 1996</description>
      <alias>cp775</alias>
      <alias>csPC775Baltic</alias>
    </record>
    <record>
      <name>KOI8-U</name>
      <xref type="rfc" data="rfc2319"/>
      <value>2088</value>
      <description>
        <xref type="rfc" data="rfc2319"/>
      </description>
      <alias>csKOI8U</alias>
    </record>
    <record date="2000-08">
      <name>IBM00858</name>
      <value>2089</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM00858"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID00858</alias>
      <alias>CP00858</alias>
      <alias>PC-Multilingual-850+euro</alias>
      <alias>csIBM00858</alias>
    </record>
    <record date="2000-08">
      <name>IBM00924</name>
      <value>2090</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM00924"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID00924</alias>
      <alias>CP00924</alias>
      <alias>ebcdic-Latin9--euro</alias>
      <alias>csIBM00924</alias>
    </record>
    <record date="2000-08">
      <name>IBM01140</name>
      <value>2091</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01140"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01140</alias>
      <alias>CP01140</alias>
      <alias>ebcdic-us-37+euro</alias>
      <alias>csIBM01140</alias>
    </record>
    <record date="2000-08">
      <name>IBM01141</name>
      <value>2092</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01141"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01141</alias>
      <alias>CP01141</alias>
      <alias>ebcdic-de-273+euro</alias>
      <alias>csIBM01141</alias>
    </record>
    <record date="2000-08">
      <name>IBM01142</name>
      <value>2093</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01142"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01142</alias>
      <alias>CP01142</alias>
      <alias>ebcdic-dk-277+euro</alias>
      <alias>ebcdic-no-277+euro</alias>
      <alias>csIBM01142</alias>
    </record>
    <record date="2000-08">
      <name>IBM01143</name>
      <value>2094</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01143"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01143</alias>
      <alias>CP01143</alias>
      <alias>ebcdic-fi-278+euro</alias>
      <alias>ebcdic-se-278+euro</alias>
      <alias>csIBM01143</alias>
    </record>
    <record date="2000-08">
      <name>IBM01144</name>
      <value>2095</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01144"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01144</alias>
      <alias>CP01144</alias>
      <alias>ebcdic-it-280+euro</alias>
      <alias>csIBM01144</alias>
    </record>
    <record date="2000-08">
      <name>IBM01145</name>
      <value>2096</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01145"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01145</alias>
      <alias>CP01145</alias>
      <alias>ebcdic-es-284+euro</alias>
      <alias>csIBM01145</alias>
    </record>
    <record date="2000-08">
      <name>IBM01146</name>
      <value>2097</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01146"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01146</alias>
      <alias>CP01146</alias>
      <alias>ebcdic-gb-285+euro</alias>
      <alias>csIBM01146</alias>
    </record>
    <record date="2000-08">
      <name>IBM01147</name>
      <value>2098</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01147"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01147</alias>
      <alias>CP01147</alias>
      <alias>ebcdic-fr-297+euro</alias>
      <alias>csIBM01147</alias>
    </record>
    <record date="2000-08">
      <name>IBM01148</name>
      <value>2099</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01148"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01148</alias>
      <alias>CP01148</alias>
      <alias>ebcdic-international-500+euro</alias>
      <alias>csIBM01148</alias>
    </record>
    <record date="2000-08">
      <name>IBM01149</name>
      <value>2100</value>
      <description>IBM See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/IBM01149"/>    <xref type="person" data="Tamer_Mahdi"/></description>
      <alias>CCSID01149</alias>
      <alias>CP01149</alias>
      <alias>ebcdic-is-871+euro</alias>
      <alias>csIBM01149</alias>
    </record>
    <record date="2000-10">
      <name>Big5-HKSCS</name>
      <xref type="person" data="Nicky_Yick"/>
      <value>2101</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/Big5-HKSCS"/></description>
      <alias>csBig5HKSCS</alias>
    </record>
    <record date="2002-09">
      <name>IBM1047</name>
      <xref type="person" data="Reuel_Robrigado"/>
      <value>2102</value>
      <description>IBM1047 (EBCDIC Latin 1/Open Systems)
<xref type="uri" data="http://www-1.ibm.com/servers/eserver/iseries/software/globalization/pdf/cp01047z.pdf"/></description>
      <alias>IBM-1047</alias>
      <alias>csIBM1047</alias>
    </record>
    <record date="2002-09">
      <name>PTCP154</name>
      <xref type="person" data="Alexander_Uskov"/>
      <value>2103</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/PTCP154"/></description>
      <alias>csPTCP154</alias>
      <alias>PT154</alias>
      <alias>CP154</alias>
      <alias>Cyrillic-Asian</alias>
      <alias>csPTCP154</alias>
    </record>
    <record>
      <name>Amiga-1251</name>
      <value>2104</value>
      <description>See <xref type="uri" data="http://www.amiga.ultranet.ru/Amiga-1251.html"/></description>
      <alias>Ami1251</alias>
      <alias>Amiga1251</alias>
      <alias>Ami-1251</alias>
      <alias>csAmiga1251
(Aliases are provided for historical reasons and should not be used) [Malyshev]</alias>
    </record>
    <record>
      <name>KOI7-switched</name>
      <value>2105</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/KOI7-switched"/></description>
      <alias>csKOI7switched</alias>
    </record>
    <record date="2006-12-07">
      <name>BRF</name>
      <value>2106</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/BRF"/>                    <xref type="person" data="Samuel_Thibault"/></description>
      <alias>csBRF</alias>
    </record>
    <record date="2007-05-14">
      <name>TSCII</name>
      <value>2107</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/TSCII"/>           <xref type="person" data="Kuppuswamy_Kalyanasu"/></description>
      <alias>csTSCII</alias>
    </record>
    <record date="2011-09-23">
      <name>CP51932</name>
      <value>2108</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/CP51932"/>                  <xref type="person" data="Yui_Naruse"/></description>
      <alias>csCP51932</alias>
    </record>
    <record date="2010-11-04">
      <name>windows-874</name>
      <value>2109</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-874"/>              <xref type="person" data="Shawn_Steele"/></description>
      <alias>cswindows874</alias>
    </record>
    <record date="1996-05">
      <name>windows-1250</name>
      <value>2250</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1250"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1250</alias>
    </record>
    <record date="1996-05">
      <name>windows-1251</name>
      <value>2251</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1251"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1251</alias>
    </record>
    <record date="1999-12">
      <name>windows-1252</name>
      <value>2252</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1252"/>       <xref type="person" data="Chris_Wendt"/></description>
      <alias>cswindows1252</alias>
    </record>
    <record date="1996-05">
      <name>windows-1253</name>
      <value>2253</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1253"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1253</alias>
    </record>
    <record date="1996-05">
      <name>windows-1254</name>
      <value>2254</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1254"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1254</alias>
    </record>
    <record date="1996-05">
      <name>windows-1255</name>
      <value>2255</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1255"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1255</alias>
    </record>
    <record date="1996-05">
      <name>windows-1256</name>
      <value>2256</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1256"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1256</alias>
    </record>
    <record date="1996-05">
      <name>windows-1257</name>
      <value>2257</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1257"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1257</alias>
    </record>
    <record date="1996-05">
      <name>windows-1258</name>
      <value>2258</value>
      <description>Microsoft  <xref type="uri" data="http://www.iana.org/assignments/charset-reg/windows-1258"/> <xref type="person" data="Katya_Lazhintseva"/></description>
      <alias>cswindows1258</alias>
    </record>
    <record date="1998-09">
      <name>TIS-620</name>
      <value>2259</value>
      <description>Thai Industrial Standards Institute (TISI)                             <xref type="person" data="Trin_Tantsetthi"/></description>
      <alias>csTIS620</alias>
      <alias>ISO-8859-11</alias>
    </record>
    <record date="2011-09-23">
      <name>CP50220</name>
      <value>2260</value>
      <description>See <xref type="uri" data="http://www.iana.org/assignments/charset-reg/CP50220"/>                  <xref type="person" data="Yui_Naruse"/></description>
      <alias>csCP50220</alias>
    </record>
  </registry>
  <people>
    <person id="Alexander_Uskov">
      <name>Alexander Uskov</name>
      <uri>mailto:auskov&amp;idc.kz</uri>
      <updated>2002-09</updated>
    </person>
    <person id="Alexei_Veremeev">
      <name>Alexei Veremeev</name>
      <uri>mailto:Alexey.Veremeev&amp;oracle.com</uri>
      <updated>2006-12-07</updated>
    </person>
    <person id="Chris_Wendt">
      <name>Chris Wendt</name>
      <uri>mailto:christw&amp;microsoft.com</uri>
      <updated>1999-12</updated>
    </person>
    <person id="Hank_Nussbacher">
      <name>Hank Nussbacher</name>
      <uri>mailto:hank&amp;vm.tau.ac.il</uri>
    </person>
    <person id="IANA">
      <name>Internet Assigned Numbers Authority</name>
      <uri>mailto:iana&amp;iana.org</uri>
    </person>
    <person id="Jun_Murai">
      <name>Jun Murai</name>
      <uri>mailto:jun&amp;wide.ad.jp</uri>
    </person>
    <person id="Katya_Lazhintseva">
      <name>Katya Lazhintseva</name>
      <uri>mailto:katyal&amp;microsoft.com</uri>
      <updated>1996-05</updated>
    </person>
    <person id="Keld_Simonsen">
      <name>Keld Simonsen</name>
      <uri>mailto:Keld.Simonsen&amp;dkuug.dk</uri>
    </person>
    <person id="Keld_Simonsen_2">
      <name>Keld Simonsen</name>
      <uri>mailto:Keld.Simonsen&amp;rap.dk</uri>
      <updated>2000-08</updated>
    </person>
    <person id="Kuppuswamy_Kalyanasu">
      <name>Kuppuswamy Kalyanasundaram</name>
      <uri>mailto:kalyan.geo&amp;yahoo.com</uri>
      <updated>2007-05-14</updated>
    </person>
    <person id="Mark_Davis">
      <name>Mark Davis</name>
      <uri>mailto:mark&amp;unicode.org</uri>
      <updated>2002-04</updated>
    </person>
    <person id="Markus_Scherer">
      <name>Markus Scherer</name>
      <uri>mailto:markus.scherer&amp;jtcsv.com</uri>
      <updated>2002-09</updated>
    </person>
    <person id="Masataka_Ohta">
      <name>Masataka Ohta</name>
      <uri>mailto:mohta&amp;cc.titech.ac.jp</uri>
      <updated>1995-07</updated>
    </person>
    <person id="Nicky_Yick">
      <name>Nicky Yick</name>
      <uri>mailto:cliac&amp;itsd.gcn.gov.hk</uri>
      <updated>2000-10</updated>
    </person>
    <person id="Reuel_Robrigado">
      <name>Reuel Robrigado</name>
      <uri>mailto:reuelr&amp;ca.ibm.com</uri>
      <updated>2002-09</updated>
    </person>
    <person id="Rick_Pond">
      <name>Rick Pond</name>
      <uri>mailto:rickpond&amp;vnet.ibm.com</uri>
      <updated>1997-03</updated>
    </person>
    <person id="Sairan_M_Kikkarin">
      <name>Sairan M. Kikkarin</name>
      <uri>mailto:sairan&amp;sci.kz</uri>
      <updated>2006-12-07</updated>
    </person>
    <person id="Samuel_Thibault">
      <name>Samuel Thibault</name>
      <uri>mailto:samuel.thibault&amp;ens-lyon.org</uri>
      <updated>2006-12-07</updated>
    </person>
    <person id="Shawn_Steele">
      <name>Shawn Steele</name>
      <uri>mailto:Shawn.Steele&amp;microsoft.com</uri>
      <updated>2010-11-04</updated>
    </person>
    <person id="Tamer_Mahdi">
      <name>Tamer Mahdi</name>
      <uri>mailto:tamer&amp;ca.ibm.com</uri>
      <updated>2000-08</updated>
    </person>
    <person id="Toby_Phipps">
      <name>Toby Phipps</name>
      <uri>mailto:tphipps&amp;peoplesoft.com</uri>
      <updated>2002-03</updated>
    </person>
    <person id="Trin_Tantsetthi">
      <name>Trin Tantsetthi</name>
      <uri>mailto:trin&amp;mozart.inet.co.th</uri>
      <updated>1998-09</updated>
    </person>
    <person id="Vladas_Tumasonis">
      <name>Vladas Tumasonis</name>
      <uri>mailto:vladas.tumasonis&amp;maf.vu.lt</uri>
      <updated>2000-08</updated>
    </person>
    <person id="Woohyong_Choi">
      <name>Woohyong Choi</name>
      <uri>mailto:whchoi&amp;cosmos.kaist.ac.kr</uri>
    </person>
    <person id="Yui_Naruse">
      <name>Yui Naruse</name>
      <uri>mailto:naruse&amp;airemix.jp</uri>
      <updated>2011-09-23</updated>
    </person>
  </people>
</registry>
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
  } # _init_data

1;

__END__

