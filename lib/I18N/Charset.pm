
=head1 NAME

I18N::Charset - IANA Character Set Registry names and Unicode::Map8
conversion scheme names

=head1 SYNOPSIS

  use I18N::Charset;

  $sCharset = iana_charset_name('WinCyrillic');
  # $sCharset is now 'windows-1251'
  $sCharset = map8_charset_name('windows-1251');
  # $sCharset is now 'cp1251' which can be passed to Unicode::Map8->new()
  $sCharset = umap_charset_name('Adobe DingBats');  # $sCharset gets ''
  # $sCharset is now 'ADOBE-DINGBATS' which can be passed to Unicode::Map->new()

  I18N::Charset::add_iana_alias('my-japanese' => 'iso-2022-jp');
  I18N::Charset::add_map8_alias('my-arabic' => 'arabic7');
  I18N::Charset::add_umap_alias('my-hebrew' => 'ISO-8859-8');

=cut

#-----------------------------------------------------------------------

package I18N::Charset;
use strict;
require 5.002;

#-----------------------------------------------------------------------

=head1 DESCRIPTION

The C<I18N::Charset> module provides access to the IANA Character Set
Registry names for identifying character encoding schemes.  It also
provides a mapping to the character set names used by the
Unicode::Map8 and Unicode::Map modules.

So, for example, if you get an HTML document with a META CHARSET="..."
tag, you can fairly quickly determine what Unicode:: module can be
used to convert it to Unicode.

If you don't have the module Unicode::Map8 installed, the map8_
functions will always return undef; similarly for Unicode::Map and the
umap_ functions.

=cut

#-----------------------------------------------------------------------

require Exporter;
use Carp;

#-----------------------------------------------------------------------
#	Public Global Variables
#-----------------------------------------------------------------------
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK );
$VERSION = '1.11';
@ISA       = qw( Exporter );
@EXPORT    = qw( iana_charset_name map8_charset_name umap_charset_name );
@EXPORT_OK = qw( add_iana_alias add_map8_alias add_umap_alias );

#-----------------------------------------------------------------------
#	Private Global Variables
#-----------------------------------------------------------------------

# %SHORTtoMIB is a hash of stripped names to mib.
my %SHORTtoMIB;
# %MIBtoLONG is a hash of mib to long name.
my %MIBtoLONG;
# %LONGtoMIB is a hash of long name to mib.
my %LONGtoMIB;
# %MIBtoMAP8 is a hash of mib to Unicode::Map8 names.  (Only valid for
# those U::Map8 names that we can find in the IANA registry)
my %MIBtoMAP8;
# %MIBtoUMAP is a hash of mib to Unicode::Map names.  If a U::Map
# encoding does not have an official IANA entry, we create a dummy mib
# for it.
my %MIBtoUMAP;

my ($debug, $verbose);
# $debug = 1;
$verbose ||= $debug;

=head1 CONVERSION ROUTINES

There are three conversion routines: C<iana_charset_name()>,
C<map8_charset_name()>, and C<umap_charset_name()>.

=over 4

=item iana_charset_name()

This function takes a string containing the name of a character set
and returns a string which contains the official IANA name of the
character set identified. If no valid character set name can be
identified, then C<undef> will be returned.  The case and punctuation
within the string are not important.

    $sCharset = iana_charset_name('WinCyrillic');

=cut

sub iana_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  # print STDERR " + iana_charset_name($code)...";
  return &short_to_long($code);
  } # iana_charset_name


sub try_list
  {
  my $code = shift;
  my @asTry = ($code, &strip($code));
  push @asTry, &strip($1) if $code =~ m/^x-(.+)$/;  # try without leading x-
  push @asTry, &strip($1) if $code =~ m/^x-x-(.+)$/;  # try without leading x-x-
  return @asTry;
  } # try_list

sub short_to_mib
  {
  my $code = shift;
  local $^W = 0;
  foreach my $sTry (&try_list($code))
    {
    my $iMIB = $SHORTtoMIB{$sTry} || 'undef';
    # print STDERR "try($sTry)...$iMIB...";
    return $iMIB if ($iMIB ne 'undef');
    } # foreach
  return undef;
  } # short_to_mib

sub short_to_long
  {
  local $^W = 0;
  return $MIBtoLONG{&short_to_mib(shift)};
  } # short_to_long


=item map8_charset_name()

This function takes a string containing the name of a character set
(in almost any format) and returns a string which contains a name for
the character set that can be used to designate a Unicode::Map8
character code map. If no valid character set name can be identified,
then C<undef> will be returned.  The case and punctuation within the
argument string are not important.

    $sCharset = map8_charset_name('windows-1251');

=cut

sub map8_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  my $debug = 0 && ($code =~ m!037!);
  print STDERR " + map8_charset_name($code)..." if $debug;
  $code = &strip($code);
  print STDERR "$code..." if $debug;
  my $iMIB = &short_to_mib($code) || 'undef';
  print STDERR "$iMIB..." if $debug;
  if ($iMIB ne 'undef')
    {
    print STDERR "$MIBtoMAP8{$iMIB}\n" if $debug;
    return $MIBtoMAP8{$iMIB};
    } # if
  print STDERR "undef\n" if $debug;
  return undef;
  } # map8_charset_name

=item umap_charset_name()

This function takes a string containing the name of a character set
(in almost any format) and returns a string which contains a name for
the character set that can be used to designate a Unicode::Map
character code mapping. If no valid character set name can be
identified, then C<undef> will be returned.  The case and punctuation
within the argument string are not important.

    $sCharset = umap_charset_name('hebrew');

=back

=cut

sub umap_charset_name
  {
  my $code = shift;
  return undef unless defined $code;
  return undef unless $code ne '';
  my $debug = 0 && ($code =~ m!apple!i);
  # print STDERR "\n + MIBtoUMAP{dummymib029} == $MIBtoUMAP{'dummymib029'}\n\n" if $debug;
  print STDERR " + umap_charset_name($code)..." if $debug;
  my $iMIB = &short_to_mib($code) || 'undef';
  print STDERR "$iMIB..." if $debug;
  # First, see if there is a special UMap alias (independent of the
  # IANA registry) for the desired code:
  if ($iMIB ne 'undef')
    {
    print STDERR "$MIBtoUMAP{$iMIB}\n" if $debug;
    return $MIBtoUMAP{$iMIB};
    } # if
  print STDERR "undef\n" if $debug;
  return undef;
  } # umap_charset_name


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
  return values %MIBtoLONG;
  } # all_iana_charset_names

#-----------------------------------------------------------------------

=head1 CHARACTER SET NAME ALIASING

This module supports three semi-private routines for specifying
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

#-----------------------------------------------------------------------

sub add_iana_alias
  {
  my ($sAlias, $sReal) = @_;
  # print STDERR " + add_iana_alias($sAlias,$sReal)...";
  my $sName = &iana_charset_name($sReal);
  if (not defined($sName))
    {
    carp "attempt to alias \"$sAlias\" to unknown IANA character set \"$sReal\"\n" if $verbose;
    return undef;
    } # if
  # print STDERR "$sName...", &short_to_mib(&strip($sName)), "\n";
  $SHORTtoMIB{&strip($sAlias)} = &short_to_mib(&strip($sName));
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

#-----------------------------------------------------------------------

sub add_map8_alias
  {
  my ($sAlias, $sReal) = @_;
  my $sName = &map8_charset_name($sReal);
  my $sShort = &strip($sAlias);
  my $sShortName = &strip($sName);
  if (not defined($sName))
    {
    carp "attempt to alias \"$sAlias\" to unknown Map8 character set \"$sReal\"\n" if $verbose;
    return undef;
    } # if
  if (exists $SHORTtoMIB{$sShortName})
    {
    $SHORTtoMIB{$sShort} = $SHORTtoMIB{$sShortName};
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
  my $sName = &umap_charset_name($sReal);
  my $sShort = &strip($sAlias);
  my $sShortName = &strip($sName);
  if (not defined($sName))
    {
    carp "attempt to alias \"$sAlias\" to unknown U::Map character set \"$sReal\"\n" if $verbose;
    return undef;
    } # if
  if (exists $SHORTtoMIB{$sShortName})
    {
    $SHORTtoMIB{$sShort} = $SHORTtoMIB{$sShortName};
    } # if
  return $sName;
  } # add_map8_alias

#-----------------------------------------------------------------------

=head1 EXAMPLES

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

Martin Thurn E<lt>MartinThurn@iname.comE<gt>

=head1 COPYRIGHT

Copyright (c) 1998-2001 TASC, Inc.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

#-----------------------------------------------------------------------

sub strip
  {
  my $s = lc(shift);
  $s =~ tr/[0-9a-zA-Z]//dc;
  return $s;
  } # strip

# initialization code - stuff the DATA into some data structure

INFINITE:
while (1)
  {
  my @asEqualLines;
  my ($sName, $iMIB, $sAlias);
 DATA:
  while (my $sLine = <DATA>)
    {
    unless ($sLine =~ m!\S!)
      {
      # Blank line separates entries.
      ($sName, $iMIB, $sAlias) = ('', '', '');
      $debug = 0;
      next DATA;
      } # unless
    # print STDERR " + read DATA $_";
    if ($sLine =~ m/\ ===\ /)
      {
      push @asEqualLines, $sLine;
      } # if
    elsif ($sLine =~ m/^Name:\s*(\S+)/)
      {
      $sName = $1;
      # $debug = $sName =~ m!jis!i;
      print STDERR " +   read Name: $sName\n" if $debug;
      } # if Name
    elsif ($sLine =~ m!^MIBenum:\s*(\d+)!)
      {
      $iMIB = $1;
      # $debug = ($iMIB == 2028);
      print STDERR " +   found mib: $iMIB, sName = $sName\n" if $debug;
      $MIBtoLONG{$iMIB} = $sName;
      $LONGtoMIB{$sName} = $iMIB;
      $SHORTtoMIB{&strip($sName)} = $iMIB;
      } # MIBenum line
    elsif ($sLine =~ m/^Alias:\s*(\S+)/)
      {
      $sAlias = $1;
      if ($sAlias !~ m!None!i)
        {
        print STDERR " +   map Alias ($sAlias) to mib $iMIB\n" if $debug;
        $SHORTtoMIB{&strip($sAlias)} = $iMIB;
        } # if not "None"
      } # if Alias
    } # while <DATA>

  # last INFINITE;

  # Not that we have all the standard definitions, process the special
  # === directives:
 EQUAL_LINE:
  foreach my $sLine (@asEqualLines)
    {
    # print STDERR " +   equal-sign line $sLine...";
    my @as = split(/\ ===\ /, $sLine);
    my $iMIB = $SHORTtoMIB{&strip($as[0])} || '';
    unless ($iMIB ne '')
      {
      print STDERR " --- can not find IANA entry for equal-sign directive $as[0]\n";
      next EQUAL_LINE;
      } # unless
    foreach my $s (@as)
      {
      $SHORTtoMIB{&strip($s)} = $iMIB;
      } # foreach
    } # foreach

  # last INFINITE;

  my $sFakeMIB = 'dummymib001';

  if (eval "require Unicode::Map8")
    {
    print STDERR " + found Unicode::Map8 installed, will build map8 tables..." if $debug;
    my $sMapFile = "$Unicode::Map8::MAPS_DIR/aliases";
    if (open MAPS, $sMapFile)
      {
      while (defined (my $sLine = <MAPS>))
        {
        # $debug = ($sLine =~ m!IBM037!);
        my @as = split(/\s/, $sLine);
        my $sFound = '';
        my $iMIB = '';
        # The "master" Map8 name is in $as[0].  Try to find the
        # official IANA name for this encoding:
        my $sMap8 = $as[$[];
 MAP8ITEM:
        foreach my $s (@as)
          {
          print STDERR " +      looking for $s in iana table...\n" if $debug;
          if (defined (my $sTemp = &iana_charset_name($s)))
            {
            $sFound = $sTemp;
            last MAP8ITEM;
            } # if
          } # foreach
        if ($sFound eq '')
          {
          print STDERR " --- did not find IANA name for Map8 entry $sMap8\n" if $debug;
          $iMIB = $sFakeMIB++;
          $LONGtoMIB{$sMap8} = $iMIB;
          } # unless
        else
          {
          print STDERR " +   found IANA name $sFound for Map8 entry $sMap8\n" if $debug;
          $iMIB = $LONGtoMIB{$sFound};
          }
        # $debug = ($iMIB eq 2028);
        # Make this IANA mib map to this Map8 name:
        print STDERR " +      map $iMIB to $sMap8 in MIBtoMAP8...\n" if $debug;
        $MIBtoMAP8{$iMIB} = $sMap8;
        # Map ALL the Map8 aliases to this Map8 master name:
        foreach my $s (@as)
          {
          $s = &strip($s);
          print STDERR " +      map $s to $iMIB in SHORTtoMIB...\n" if $debug;
          $SHORTtoMIB{$s} = $iMIB;
          } # foreach
        } # while
      close MAPS;
      } # if open
    else
      {
      carp " --- couldn't open $sMapFile for read" if $verbose;
      }
    # If there are special cases for Unicode::Map8, add them here:
    # &add_map8_alias("new-name", "existing-name");
    print STDERR "done.\n" if $debug;
    } # if Unicode::Map8 installed

  # $debug = 1;
  if (eval "require Unicode::Map")
    {
    print STDERR " + found Unicode::Map installed, will build tables..." if $debug;
    my $MAP_Path = $INC{'Unicode/Map.pm'};
    $MAP_Path =~ s/\.pm//;
    my $sMapFile = "$MAP_Path/REGISTRY";
    if (open MAPS, $sMapFile)
      {
      $/ = "\n\n";
      while (defined (my $sEntry = <MAPS>))
        {
        $debug = 0;
        # print STDERR " + working on Umap entry >>>>>$sEntry<<<<<...\n";
        my ($sName, $iMIB) = ('', '');
        next unless $sEntry =~ m!^name:\s+(\S+)!mi;
        $sName = $1;
        # $debug = ($sName =~ m!apple!i);
        print STDERR " +   UMAP sName is $sName\n" if $debug;
        $iMIB = $1 if $sEntry =~ m!^#mib:\s+(\d+)!mi;
        $iMIB ||= $SHORTtoMIB{&strip($sName)};
        $iMIB ||= $sFakeMIB++;
        # $debug = ($iMIB eq '17');
        print STDERR " +   UMAP mib is $iMIB\n" if $debug;
        $MIBtoUMAP{$iMIB} = $sName;
        # Set the long IANA name, IF it is empty so far:
        $MIBtoLONG{$iMIB} ||= $sName;
        $SHORTtoMIB{&strip($sName)} ||= $iMIB;
        while ($sEntry =~ m!^alias:\s+(.+)$!mgi)
          {
          print STDERR " +   UMAP alias $1\n" if $debug;
          $SHORTtoMIB{&strip($1)} = $iMIB;
          } # while
        } # while
      close MAPS;
      # print STDERR "\n + MIBtoUMAP{dummymib029} == $MIBtoUMAP{'dummymib029'}\n\n";
      } # if open
    else
      {
      carp " --- couldn't open $sMapFile for read" if $verbose;
      }
    # If there are special cases for Unicode::Map, add them here:
    # &add_umap_alias("new-name", "existing-name");
    print STDERR "done.\n" if $debug;
    } # if Unicode::Map installed

  last INFINITE;

  print STDERR " + the following IANA names do *not* have entries in the Map8 table:\n";
  my %hiTried = ();
  foreach my $sIANA (sort values %MIBtoLONG)
    {
    next if $hiTried{$sIANA};
    print "$sIANA\n" unless defined &map8_charset_name($sIANA);
    $hiTried{$sIANA}++;
    } # foreach

  # last INFINITE;

  # debugging: selective dump:
  print STDERR " + after init, iana_charset_name returns:\n";
  foreach my $key (qw(cp1251 windows-1251 WinCyrillic sjis x-sjis Shift_JIS ASCII US-ASCII us-ascii iso-2022-jp iso-8859-1 Unicode-2-0-utf-8 EUC-KR big5 x-x-big5))
    {
    print STDERR " +   $key => ", &iana_charset_name($key) || 'undef', "\n";
    } # foreach

  # exit 88;

  print STDERR " + after init, map8_charset_name() returns:\n";
  foreach my $key (qw(cp1251 windows-1251 WinCyrillic sjis x-sjis Shift_JIS ASCII US-ASCII us-ascii iso-2022-jp iso-8859-1 Unicode-2-0-utf-8 EUC-KR big5 x-x-big5))
    {
    print STDERR " +   $key => ", &map8_charset_name($key) || 'undef', "\n";
    } # foreach

  last INFINITE;

  # debugging: huge dump:
  # &dumpHash('MIBtoLONG', \%MIBtoLONG);
  # &dumpHash('LONGtoMIB', \%LONGtoMIB);
  # &dumpHash('SHORTtoMIB', \%SHORTtoMIB);
  foreach (keys %SHORTtoMIB)
    {
    print STDERR " + short_to_long($_) == ", &short_to_long($_) || 'undef', "\n";
    } # foreach

  last INFINITE;
  } # while

sub dumpHash
  {
  my ($sName, $rh) = @_;
  print STDERR " + after initialization, $sName is:\n";
  foreach my $key (keys %$rh)
    {
    print STDERR " +   $key => $$rh{$key}\n";
    } # foreach
  } # dumpHash

1;

__DATA__

The first part of the data is a hand-made list of IANA names and
aliases, in the form AAA \=\=\= BBB \=\=\= CCC, where AAA is the
canonical IANA name and BBB and CCC are aliases.  Note that
capitalization and punctuation of aliases are meaningless (but
whitespace is not allowed).

Shift_JIS === sjis
windows-1250 === winlatin2
windows-1251 === wincyrillic
windows-1252 === winlatin1
windows-1253 === wingreek
windows-1254 === winturkish
windows-1255 === winhebrew
windows-1256 === winarabic
windows-1257 === winbaltic
windows-1258 === winvietnamese
Adobe-Standard-Encoding === adobe-standard
Adobe-Symbol-Encoding === adobe-symbol
EBCDIC-ES === ebcdic-cp-es
EBCDIC-FR === ebcdic-cp-fr
EBCDIC-IT === ebcdic-cp-it
EBCDIC-UK === ebcdic-cp-gb
EBCDIC-US === ebcdic-cp-us
EBCDIC-FI-SE === ebcdic-cp-fi
UTF-7 === Unicode-2-0-utf-7
UTF-8 === Unicode-2-0-utf-8
Extended_UNIX_Code_Packed_Format_for_Japanese === euc === euc-jp

The rest of the DATA is the original document from
http://www.iana.org/assignments/character-sets

---------------------------------------------------------------

===================================================================
CHARACTER SETS

(last updated 2001 August 23)

These are the official names for character sets that may be used in
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
(set of) sub-repetoires that may occur.  The third region (>1999) is
intended for vendor specific coded character sets.

	Assigned MIB enum Numbers
	-------------------------
	0-2		Reserved
	3-999		Set By Standards Organizations
	1000-1999	Unicode / 10646
	2000-2999	Vendor

The aliases that start with "cs" have been added for use with the
Printer MIB (see RFC 1759) and contain the standard numbers along with
suggestive names in order to facilitate applications that want to
display the names in user interfaces.  The "cs" stands for character
set and is provided for applications that need a lower case first
letter but want to use mixed case thereafter that cannot contain any
special characters, such as underbar ("_") and dash ("-").  If the
character set is from an ISO standard, its cs alias is the ISO
standard number or name.  If the character set is not from an ISO
standard, but is registered with ISO (ECMA is the current ISO
Registration Authority), the ISO Registry number is specified as
ISOnnn followed by letters suggestive of the name or standards number
of the code set.  When a national or international standard is
revised, the year of revision is added to the cs alias of the new
character set entry in the IANA Registry in order to distinguish the
revised character set from the original character set.


Character Set                                               Reference
-------------                                               ---------

Name: ANSI_X3.4-1968                                   [RFC1345,KXS2]
MIBenum: 3
Source: ECMA registry
Alias: iso-ir-6
Alias: ANSI_X3.4-1986
Alias: ISO_646.irv:1991
Alias: ASCII
Alias: ISO646-US
Alias: US-ASCII (preferred MIME name)
Alias: us
Alias: IBM367
Alias: cp367
Alias: csASCII

Name: ISO-10646-UTF-1
MIBenum: 27
Source: Universal Transfer Format (1), this is the multibyte
        encoding, that subsets ASCII-7. It does not have byte
        ordering issues.
Alias: csISO10646UTF1

Name: ISO_646.basic:1983                                [RFC1345,KXS2]
MIBenum: 28
Source: ECMA registry
Alias: ref
Alias: csISO646basic1983

Name: INVARIANT                                         [RFC1345,KXS2]
MIBenum: 29
Alias: csINVARIANT

Name: ISO_646.irv:1983                                  [RFC1345,KXS2]
MIBenum: 30
Source: ECMA registry
Alias: iso-ir-2
Alias: irv
Alias: csISO2IntlRefVersion

Name: BS_4730                                           [RFC1345,KXS2]
MIBenum: 20
Source: ECMA registry
Alias: iso-ir-4
Alias: ISO646-GB
Alias: gb
Alias: uk
Alias: csISO4UnitedKingdom

Name: NATS-SEFI                                         [RFC1345,KXS2]
MIBenum: 31
Source: ECMA registry
Alias: iso-ir-8-1
Alias: csNATSSEFI

Name: NATS-SEFI-ADD                                     [RFC1345,KXS2]
MIBenum: 32
Source: ECMA registry
Alias: iso-ir-8-2
Alias: csNATSSEFIADD

Name: NATS-DANO                                         [RFC1345,KXS2]
MIBenum: 33
Source: ECMA registry
Alias: iso-ir-9-1
Alias: csNATSDANO

Name: NATS-DANO-ADD                                     [RFC1345,KXS2]
MIBenum: 34
Source: ECMA registry
Alias: iso-ir-9-2
Alias: csNATSDANOADD

Name: SEN_850200_B                                      [RFC1345,KXS2]
MIBenum: 35
Source: ECMA registry
Alias: iso-ir-10
Alias: FI
Alias: ISO646-FI
Alias: ISO646-SE
Alias: se
Alias: csISO10Swedish

Name: SEN_850200_C                                      [RFC1345,KXS2]
MIBenum: 21
Source: ECMA registry
Alias: iso-ir-11
Alias: ISO646-SE2
Alias: se2
Alias: csISO11SwedishForNames

Name: KS_C_5601-1987                                    [RFC1345,KXS2]
MIBenum: 36
Source: ECMA registry
Alias: iso-ir-149
Alias: KS_C_5601-1989
Alias: KSC_5601
Alias: korean
Alias: csKSC56011987

Name: ISO-2022-KR  (preferred MIME name)                [RFC1557,Choi]
MIBenum: 37
Source: RFC-1557 (see also KS_C_5601-1987)
Alias: csISO2022KR

Name: EUC-KR  (preferred MIME name)                     [RFC1557,Choi]
MIBenum: 38
Source: RFC-1557 (see also KS_C_5861-1992)
Alias: csEUCKR

Name: ISO-2022-JP  (preferred MIME name)               [RFC1468,Murai]
MIBenum: 39
Source: RFC-1468 (see also RFC-2237)
Alias: csISO2022JP

Name: ISO-2022-JP-2  (preferred MIME name)              [RFC1554,Ohta]
MIBenum: 40
Source: RFC-1554
Alias: csISO2022JP2

Name: ISO-2022-CN                                            [RFC1922]
MIBenum: 104
Source: RFC-1922

Name: ISO-2022-CN-EXT                                        [RFC1922]
MIBenum: 105
Source: RFC-1922

Name: JIS_C6220-1969-jp                                 [RFC1345,KXS2]
MIBenum: 41
Source: ECMA registry
Alias: JIS_C6220-1969
Alias: iso-ir-13
Alias: katakana
Alias: x0201-7
Alias: csISO13JISC6220jp

Name: JIS_C6220-1969-ro                                 [RFC1345,KXS2]
MIBenum: 42
Source: ECMA registry
Alias: iso-ir-14
Alias: jp
Alias: ISO646-JP
Alias: csISO14JISC6220ro

Name: IT                                                [RFC1345,KXS2]
MIBenum: 22
Source: ECMA registry
Alias: iso-ir-15
Alias: ISO646-IT
Alias: csISO15Italian

Name: PT                                                [RFC1345,KXS2]
MIBenum: 43
Source: ECMA registry
Alias: iso-ir-16
Alias: ISO646-PT
Alias: csISO16Portuguese

Name: ES                                                [RFC1345,KXS2]
MIBenum: 23
Source: ECMA registry
Alias: iso-ir-17
Alias: ISO646-ES
Alias: csISO17Spanish

Name: greek7-old                                        [RFC1345,KXS2]
MIBenum: 44
Source: ECMA registry
Alias: iso-ir-18
Alias: csISO18Greek7Old

Name: latin-greek                                       [RFC1345,KXS2]
MIBenum: 45
Source: ECMA registry
Alias: iso-ir-19
Alias: csISO19LatinGreek

Name: DIN_66003                                         [RFC1345,KXS2]
MIBenum: 24
Source: ECMA registry
Alias: iso-ir-21
Alias: de
Alias: ISO646-DE
Alias: csISO21German

Name: NF_Z_62-010_(1973)                                [RFC1345,KXS2]
MIBenum: 46
Source: ECMA registry
Alias: iso-ir-25
Alias: ISO646-FR1
Alias: csISO25French

Name: Latin-greek-1                                     [RFC1345,KXS2]
MIBenum: 47
Source: ECMA registry
Alias: iso-ir-27
Alias: csISO27LatinGreek1

Name: ISO_5427                                          [RFC1345,KXS2]
MIBenum: 48
Source: ECMA registry
Alias: iso-ir-37
Alias: csISO5427Cyrillic

Name: JIS_C6226-1978                                    [RFC1345,KXS2]
MIBenum: 49
Source: ECMA registry
Alias: iso-ir-42
Alias: csISO42JISC62261978

Name: BS_viewdata                                       [RFC1345,KXS2]
MIBenum: 50
Source: ECMA registry
Alias: iso-ir-47
Alias: csISO47BSViewdata

Name: INIS                                              [RFC1345,KXS2]
MIBenum: 51
Source: ECMA registry
Alias: iso-ir-49
Alias: csISO49INIS

Name: INIS-8                                            [RFC1345,KXS2]
MIBenum: 52
Source: ECMA registry
Alias: iso-ir-50
Alias: csISO50INIS8

Name: INIS-cyrillic                                     [RFC1345,KXS2]
MIBenum: 53
Source: ECMA registry
Alias: iso-ir-51
Alias: csISO51INISCyrillic

Name: ISO_5427:1981                                     [RFC1345,KXS2]
MIBenum: 54
Source: ECMA registry
Alias: iso-ir-54
Alias: ISO5427Cyrillic1981

Name: ISO_5428:1980                                     [RFC1345,KXS2]
MIBenum: 55
Source: ECMA registry
Alias: iso-ir-55
Alias: csISO5428Greek

Name: GB_1988-80                                        [RFC1345,KXS2]
MIBenum: 56
Source: ECMA registry
Alias: iso-ir-57
Alias: cn
Alias: ISO646-CN
Alias: csISO57GB1988

Name: GB_2312-80                                        [RFC1345,KXS2]
MIBenum: 57
Source: ECMA registry
Alias: iso-ir-58
Alias: chinese
Alias: csISO58GB231280

Name: NS_4551-1                                         [RFC1345,KXS2]
MIBenum: 25
Source: ECMA registry
Alias: iso-ir-60
Alias: ISO646-NO
Alias: no
Alias: csISO60DanishNorwegian
Alias: csISO60Norwegian1

Name: NS_4551-2                                          [RFC1345,KXS2]
MIBenum: 58
Source: ECMA registry
Alias: ISO646-NO2
Alias: iso-ir-61
Alias: no2
Alias: csISO61Norwegian2

Name: NF_Z_62-010                                        [RFC1345,KXS2]
MIBenum: 26
Source: ECMA registry
Alias: iso-ir-69
Alias: ISO646-FR
Alias: fr
Alias: csISO69French

Name: videotex-suppl                                     [RFC1345,KXS2]
MIBenum: 59
Source: ECMA registry
Alias: iso-ir-70
Alias: csISO70VideotexSupp1

Name: PT2                                                [RFC1345,KXS2]
MIBenum: 60
Source: ECMA registry
Alias: iso-ir-84
Alias: ISO646-PT2
Alias: csISO84Portuguese2

Name: ES2                                                [RFC1345,KXS2]
MIBenum: 61
Source: ECMA registry
Alias: iso-ir-85
Alias: ISO646-ES2
Alias: csISO85Spanish2

Name: MSZ_7795.3                                         [RFC1345,KXS2]
MIBenum: 62
Source: ECMA registry
Alias: iso-ir-86
Alias: ISO646-HU
Alias: hu
Alias: csISO86Hungarian

Name: JIS_C6226-1983                                     [RFC1345,KXS2]
MIBenum: 63
Source: ECMA registry
Alias: iso-ir-87
Alias: x0208
Alias: JIS_X0208-1983
Alias: csISO87JISX0208

Name: greek7                                             [RFC1345,KXS2]
MIBenum: 64
Source: ECMA registry
Alias: iso-ir-88
Alias: csISO88Greek7

Name: ASMO_449                                           [RFC1345,KXS2]
MIBenum: 65
Source: ECMA registry
Alias: ISO_9036
Alias: arabic7
Alias: iso-ir-89
Alias: csISO89ASMO449

Name: iso-ir-90                                          [RFC1345,KXS2]
MIBenum: 66
Source: ECMA registry
Alias: csISO90

Name: JIS_C6229-1984-a                                   [RFC1345,KXS2]
MIBenum: 67
Source: ECMA registry
Alias: iso-ir-91
Alias: jp-ocr-a
Alias: csISO91JISC62291984a

Name: JIS_C6229-1984-b                                   [RFC1345,KXS2]
MIBenum: 68
Source: ECMA registry
Alias: iso-ir-92
Alias: ISO646-JP-OCR-B
Alias: jp-ocr-b
Alias: csISO92JISC62991984b

Name: JIS_C6229-1984-b-add                               [RFC1345,KXS2]
MIBenum: 69
Source: ECMA registry
Alias: iso-ir-93
Alias: jp-ocr-b-add
Alias: csISO93JIS62291984badd

Name: JIS_C6229-1984-hand                                [RFC1345,KXS2]
MIBenum: 70
Source: ECMA registry
Alias: iso-ir-94
Alias: jp-ocr-hand
Alias: csISO94JIS62291984hand

Name: JIS_C6229-1984-hand-add                            [RFC1345,KXS2]
MIBenum: 71
Source: ECMA registry
Alias: iso-ir-95
Alias: jp-ocr-hand-add
Alias: csISO95JIS62291984handadd

Name: JIS_C6229-1984-kana                                [RFC1345,KXS2]
MIBenum: 72
Source: ECMA registry
Alias: iso-ir-96
Alias: csISO96JISC62291984kana

Name: ISO_2033-1983                                      [RFC1345,KXS2]
MIBenum: 73
Source: ECMA registry
Alias: iso-ir-98
Alias: e13b
Alias: csISO2033

Name: ANSI_X3.110-1983                                   [RFC1345,KXS2]
MIBenum: 74
Source: ECMA registry
Alias: iso-ir-99
Alias: CSA_T500-1983
Alias: NAPLPS
Alias: csISO99NAPLPS

Name: ISO_8859-1:1987                                    [RFC1345,KXS2]
MIBenum: 4
Source: ECMA registry
Alias: iso-ir-100
Alias: ISO_8859-1
Alias: ISO-8859-1 (preferred MIME name)
Alias: latin1
Alias: l1
Alias: IBM819
Alias: CP819
Alias: csISOLatin1

Name: ISO_8859-2:1987                                    [RFC1345,KXS2]
MIBenum: 5
Source: ECMA registry
Alias: iso-ir-101
Alias: ISO_8859-2
Alias: ISO-8859-2 (preferred MIME name)
Alias: latin2
Alias: l2
Alias: csISOLatin2

Name: T.61-7bit                                          [RFC1345,KXS2]
MIBenum: 75
Source: ECMA registry
Alias: iso-ir-102
Alias: csISO102T617bit

Name: T.61-8bit                                          [RFC1345,KXS2]
MIBenum: 76
Alias: T.61
Source: ECMA registry
Alias: iso-ir-103
Alias: csISO103T618bit

Name: ISO_8859-3:1988                                    [RFC1345,KXS2]
MIBenum: 6
Source: ECMA registry
Alias: iso-ir-109
Alias: ISO_8859-3
Alias: ISO-8859-3 (preferred MIME name)
Alias: latin3
Alias: l3
Alias: csISOLatin3

Name: ISO_8859-4:1988                                    [RFC1345,KXS2]
MIBenum: 7
Source: ECMA registry
Alias: iso-ir-110
Alias: ISO_8859-4
Alias: ISO-8859-4 (preferred MIME name)
Alias: latin4
Alias: l4
Alias: csISOLatin4

Name: ECMA-cyrillic                                      [RFC1345,KXS2]
MIBenum: 77
Source: ECMA registry
Alias: iso-ir-111
Alias: csISO111ECMACyrillic

Name: CSA_Z243.4-1985-1                                  [RFC1345,KXS2]
MIBenum: 78
Source: ECMA registry
Alias: iso-ir-121
Alias: ISO646-CA
Alias: csa7-1
Alias: ca
Alias: csISO121Canadian1

Name: CSA_Z243.4-1985-2                                  [RFC1345,KXS2]
MIBenum: 79
Source: ECMA registry
Alias: iso-ir-122
Alias: ISO646-CA2
Alias: csa7-2
Alias: csISO122Canadian2

Name: CSA_Z243.4-1985-gr                                 [RFC1345,KXS2]
MIBenum: 80
Source: ECMA registry
Alias: iso-ir-123
Alias: csISO123CSAZ24341985gr

Name: ISO_8859-6:1987                                    [RFC1345,KXS2]
MIBenum: 9
Source: ECMA registry
Alias: iso-ir-127
Alias: ISO_8859-6
Alias: ISO-8859-6 (preferred MIME name)
Alias: ECMA-114
Alias: ASMO-708
Alias: arabic
Alias: csISOLatinArabic

Name: ISO_8859-6-E                                       [RFC1556,IANA]
MIBenum: 81
Source: RFC1556
Alias: csISO88596E
Alias: ISO-8859-6-E (preferred MIME name)

Name: ISO_8859-6-I                                       [RFC1556,IANA]
MIBenum: 82
Source: RFC1556
Alias: csISO88596I
Alias: ISO-8859-6-I (preferred MIME name)

Name: ISO_8859-7:1987                            [RFC1947,RFC1345,KXS2]
MIBenum: 10
Source: ECMA registry
Alias: iso-ir-126
Alias: ISO_8859-7
Alias: ISO-8859-7 (preferred MIME name)
Alias: ELOT_928
Alias: ECMA-118
Alias: greek
Alias: greek8
Alias: csISOLatinGreek

Name: T.101-G2                                            [RFC1345,KXS2]
MIBenum: 83
Source: ECMA registry
Alias: iso-ir-128
Alias: csISO128T101G2

Name: ISO_8859-8:1988                                     [RFC1345,KXS2]
MIBenum: 11
Source: ECMA registry
Alias: iso-ir-138
Alias: ISO_8859-8
Alias: ISO-8859-8 (preferred MIME name)
Alias: hebrew
Alias: csISOLatinHebrew

Name: ISO_8859-8-E                                  [RFC1556,Nussbacher]
MIBenum: 84
Source: RFC1556
Alias: csISO88598E
Alias: ISO-8859-8-E (preferred MIME name)

Name: ISO_8859-8-I                                  [RFC1556,Nussbacher]
MIBenum: 85
Source: RFC1556
Alias: csISO88598I
Alias: ISO-8859-8-I (preferred MIME name)

Name: CSN_369103                                          [RFC1345,KXS2]
MIBenum: 86
Source: ECMA registry
Alias: iso-ir-139
Alias: csISO139CSN369103

Name: JUS_I.B1.002                                        [RFC1345,KXS2]
MIBenum: 87
Source: ECMA registry
Alias: iso-ir-141
Alias: ISO646-YU
Alias: js
Alias: yu
Alias: csISO141JUSIB1002

Name: ISO_6937-2-add                                      [RFC1345,KXS2]
MIBenum: 14
Source: ECMA registry and ISO 6937-2:1983
Alias: iso-ir-142
Alias: csISOTextComm

Name: IEC_P27-1                                           [RFC1345,KXS2]
MIBenum: 88
Source: ECMA registry
Alias: iso-ir-143
Alias: csISO143IECP271

Name: ISO_8859-5:1988                                     [RFC1345,KXS2]
MIBenum: 8
Source: ECMA registry
Alias: iso-ir-144
Alias: ISO_8859-5
Alias: ISO-8859-5 (preferred MIME name)
Alias: cyrillic
Alias: csISOLatinCyrillic

Name: JUS_I.B1.003-serb                                   [RFC1345,KXS2]
MIBenum: 89
Source: ECMA registry
Alias: iso-ir-146
Alias: serbian
Alias: csISO146Serbian

Name: JUS_I.B1.003-mac                                    [RFC1345,KXS2]
MIBenum: 90
Source: ECMA registry
Alias: macedonian
Alias: iso-ir-147
Alias: csISO147Macedonian

Name: ISO_8859-9:1989                                     [RFC1345,KXS2]
MIBenum: 12
Source: ECMA registry
Alias: iso-ir-148
Alias: ISO_8859-9
Alias: ISO-8859-9 (preferred MIME name)
Alias: latin5
Alias: l5
Alias: csISOLatin5

Name: greek-ccitt                                         [RFC1345,KXS2]
MIBenum: 91
Source: ECMA registry
Alias: iso-ir-150
Alias: csISO150
Alias: csISO150GreekCCITT

Name: NC_NC00-10:81                                       [RFC1345,KXS2]
MIBenum: 92
Source: ECMA registry
Alias: cuba
Alias: iso-ir-151
Alias: ISO646-CU
Alias: csISO151Cuba

Name: ISO_6937-2-25                                       [RFC1345,KXS2]
MIBenum: 93
Source: ECMA registry
Alias: iso-ir-152
Alias: csISO6937Add

Name: GOST_19768-74                                       [RFC1345,KXS2]
MIBenum: 94
Source: ECMA registry
Alias: ST_SEV_358-88
Alias: iso-ir-153
Alias: csISO153GOST1976874

Name: ISO_8859-supp                                       [RFC1345,KXS2]
MIBenum: 95
Source: ECMA registry
Alias: iso-ir-154
Alias: latin1-2-5
Alias: csISO8859Supp

Name: ISO_10367-box                                       [RFC1345,KXS2]
MIBenum: 96
Source: ECMA registry
Alias: iso-ir-155
Alias: csISO10367Box

Name: ISO-8859-10 (preferred MIME name)			  [RFC1345,KXS2]
MIBenum: 13
Source: ECMA registry
Alias: iso-ir-157
Alias: l6
Alias: ISO_8859-10:1992
Alias: csISOLatin6
Alias: latin6

Name: latin-lap                                           [RFC1345,KXS2]
MIBenum: 97
Source: ECMA registry
Alias: lap
Alias: iso-ir-158
Alias: csISO158Lap

Name: JIS_X0212-1990                                      [RFC1345,KXS2]
MIBenum: 98
Source: ECMA registry
Alias: x0212
Alias: iso-ir-159
Alias: csISO159JISX02121990

Name: DS_2089                                             [RFC1345,KXS2]
MIBenum: 99
Source: Danish Standard, DS 2089, February 1974
Alias: DS2089
Alias: ISO646-DK
Alias: dk
Alias: csISO646Danish

Name: us-dk                                               [RFC1345,KXS2]
MIBenum: 100
Alias: csUSDK

Name: dk-us                                               [RFC1345,KXS2]
MIBenum: 101
Alias: csDKUS

Name: JIS_X0201                                           [RFC1345,KXS2]
MIBenum: 15
Source: JIS X 0201-1976.   One byte only, this is equivalent to 
        JIS/Roman (similar to ASCII) plus eight-bit half-width 
        Katakana
Alias: X0201
Alias: csHalfWidthKatakana

Name: KSC5636                                             [RFC1345,KXS2]
MIBenum: 102
Alias: ISO646-KR
Alias: csKSC5636

Name: ISO-10646-UCS-2
MIBenum: 1000
Source: the 2-octet Basic Multilingual Plane, aka Unicode
        this needs to specify network byte order: the standard
        does not specify (it is a 16-bit integer space)
Alias: csUnicode

Name: ISO-10646-UCS-4
MIBenum: 1001
Source: the full code space. (same comment about byte order,
        these are 31-bit numbers.
Alias: csUCS4

Name: DEC-MCS                                             [RFC1345,KXS2]
MIBenum: 2008
Source: VAX/VMS User's Manual, 
        Order Number: AI-Y517A-TE, April 1986.
Alias: dec
Alias: csDECMCS

Name: hp-roman8                                  [HP-PCL5,RFC1345,KXS2]
MIBenum: 2004
Source: LaserJet IIP Printer User's Manual, 
        HP part no 33471-90901, Hewlet-Packard, June 1989.
Alias: roman8
Alias: r8
Alias: csHPRoman8

Name: macintosh                                           [RFC1345,KXS2]
MIBenum: 2027
Source: The Unicode Standard ver1.0, ISBN 0-201-56788-1, Oct 1991
Alias: mac
Alias: csMacintosh

Name: IBM037                                              [RFC1345,KXS2]
MIBenum: 2028
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp037
Alias: ebcdic-cp-us
Alias: ebcdic-cp-ca
Alias: ebcdic-cp-wt
Alias: ebcdic-cp-nl
Alias: csIBM037

Name: IBM038                                              [RFC1345,KXS2]
MIBenum: 2029
Source: IBM 3174 Character Set Ref, GA27-3831-02, March 1990
Alias: EBCDIC-INT
Alias: cp038
Alias: csIBM038

Name: IBM273                                              [RFC1345,KXS2]
MIBenum: 2030
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP273
Alias: csIBM273

Name: IBM274                                              [RFC1345,KXS2]
MIBenum: 2031
Source: IBM 3174 Character Set Ref, GA27-3831-02, March 1990
Alias: EBCDIC-BE
Alias: CP274
Alias: csIBM274

Name: IBM275                                              [RFC1345,KXS2]
MIBenum: 2032
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: EBCDIC-BR
Alias: cp275
Alias: csIBM275

Name: IBM277                                              [RFC1345,KXS2]
MIBenum: 2033
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: EBCDIC-CP-DK
Alias: EBCDIC-CP-NO
Alias: csIBM277

Name: IBM278                                              [RFC1345,KXS2]
MIBenum: 2034
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP278
Alias: ebcdic-cp-fi
Alias: ebcdic-cp-se
Alias: csIBM278

Name: IBM280                                              [RFC1345,KXS2]
MIBenum: 2035
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP280
Alias: ebcdic-cp-it
Alias: csIBM280

Name: IBM281                                              [RFC1345,KXS2]
MIBenum: 2036
Source: IBM 3174 Character Set Ref, GA27-3831-02, March 1990
Alias: EBCDIC-JP-E
Alias: cp281
Alias: csIBM281

Name: IBM284                                              [RFC1345,KXS2]
MIBenum: 2037
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP284
Alias: ebcdic-cp-es
Alias: csIBM284

Name: IBM285                                              [RFC1345,KXS2]
MIBenum: 2038
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP285
Alias: ebcdic-cp-gb
Alias: csIBM285

Name: IBM290                                              [RFC1345,KXS2]
MIBenum: 2039
Source: IBM 3174 Character Set Ref, GA27-3831-02, March 1990
Alias: cp290
Alias: EBCDIC-JP-kana
Alias: csIBM290

Name: IBM297                                              [RFC1345,KXS2]
MIBenum: 2040
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp297
Alias: ebcdic-cp-fr
Alias: csIBM297

Name: IBM420                                              [RFC1345,KXS2]
MIBenum: 2041
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990, 
        IBM NLS RM p 11-11
Alias: cp420
Alias: ebcdic-cp-ar1
Alias: csIBM420

Name: IBM423                                              [RFC1345,KXS2]
MIBenum: 2042
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp423
Alias: ebcdic-cp-gr
Alias: csIBM423

Name: IBM424                                              [RFC1345,KXS2]
MIBenum: 2043
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp424
Alias: ebcdic-cp-he
Alias: csIBM424

Name: IBM437                                              [RFC1345,KXS2]
MIBenum: 2011
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp437
Alias: 437
Alias: csPC8CodePage437

Name: IBM500                                              [RFC1345,KXS2]
MIBenum: 2044
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP500
Alias: ebcdic-cp-be
Alias: ebcdic-cp-ch
Alias: csIBM500

Name: IBM775                                                   [HP-PCL5]
MIBenum: 2087
Source: HP PCL 5 Comparison Guide (P/N 5021-0329) pp B-13, 1996
Alias: cp775
Alias: csPC775Baltic

Name: IBM850                                              [RFC1345,KXS2]
MIBenum: 2009
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp850
Alias: 850
Alias: csPC850Multilingual

Name: IBM851                                              [RFC1345,KXS2]
MIBenum: 2045
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp851
Alias: 851
Alias: csIBM851

Name: IBM852                                              [RFC1345,KXS2]
MIBenum: 2010
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp852
Alias: 852
Alias: csPCp852

Name: IBM855                                              [RFC1345,KXS2]
MIBenum: 2046
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp855
Alias: 855
Alias: csIBM855

Name: IBM857                                              [RFC1345,KXS2]
MIBenum: 2047
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp857
Alias: 857
Alias: csIBM857

Name: IBM860                                              [RFC1345,KXS2]
MIBenum: 2048
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp860
Alias: 860
Alias: csIBM860

Name: IBM861                                              [RFC1345,KXS2]
MIBenum: 2049
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp861
Alias: 861
Alias: cp-is
Alias: csIBM861

Name: IBM862                                              [RFC1345,KXS2]
MIBenum: 2013
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp862
Alias: 862
Alias: csPC862LatinHebrew

Name: IBM863                                              [RFC1345,KXS2]
MIBenum: 2050
Source: IBM Keyboard layouts and code pages, PN 07G4586 June 1991
Alias: cp863
Alias: 863
Alias: csIBM863

Name: IBM864                                              [RFC1345,KXS2]
MIBenum: 2051
Source: IBM Keyboard layouts and code pages, PN 07G4586 June 1991
Alias: cp864
Alias: csIBM864

Name: IBM865                                              [RFC1345,KXS2]
MIBenum: 2052
Source: IBM DOS 3.3 Ref (Abridged), 94X9575 (Feb 1987)
Alias: cp865
Alias: 865
Alias: csIBM865

Name: IBM866                                                     [Pond]
MIBenum: 2086
Source: IBM NLDG Volume 2 (SE09-8002-03) August 1994
Alias: cp866
Alias: 866
Alias: csIBM866

Name: IBM868                                              [RFC1345,KXS2]
MIBenum: 2053
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP868
Alias: cp-ar
Alias: csIBM868

Name: IBM869                                              [RFC1345,KXS2]
MIBenum: 2054
Source: IBM Keyboard layouts and code pages, PN 07G4586 June 1991
Alias: cp869
Alias: 869
Alias: cp-gr
Alias: csIBM869

Name: IBM870                                              [RFC1345,KXS2]
MIBenum: 2055
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP870
Alias: ebcdic-cp-roece
Alias: ebcdic-cp-yu
Alias: csIBM870

Name: IBM871                                              [RFC1345,KXS2]
MIBenum: 2056
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP871
Alias: ebcdic-cp-is
Alias: csIBM871

Name: IBM880                                              [RFC1345,KXS2]
MIBenum: 2057
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp880
Alias: EBCDIC-Cyrillic
Alias: csIBM880

Name: IBM891                                              [RFC1345,KXS2]
MIBenum: 2058
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp891
Alias: csIBM891

Name: IBM903                                              [RFC1345,KXS2]
MIBenum: 2059
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp903
Alias: csIBM903

Name: IBM904                                              [RFC1345,KXS2]
MIBenum: 2060
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: cp904
Alias: 904
Alias: csIBBM904

Name: IBM905                                              [RFC1345,KXS2]
MIBenum: 2061
Source: IBM 3174 Character Set Ref, GA27-3831-02, March 1990
Alias: CP905
Alias: ebcdic-cp-tr
Alias: csIBM905

Name: IBM918                                              [RFC1345,KXS2]
MIBenum: 2062
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP918
Alias: ebcdic-cp-ar2
Alias: csIBM918

Name: IBM1026                                             [RFC1345,KXS2]
MIBenum: 2063
Source: IBM NLS RM Vol2 SE09-8002-01, March 1990
Alias: CP1026
Alias: csIBM1026

Name: EBCDIC-AT-DE                                        [RFC1345,KXS2]
MIBenum: 2064
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csIBMEBCDICATDE

Name: EBCDIC-AT-DE-A                                      [RFC1345,KXS2]
MIBenum: 2065 
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987 
Alias: csEBCDICATDEA

Name: EBCDIC-CA-FR                                        [RFC1345,KXS2]
MIBenum: 2066
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICCAFR

Name: EBCDIC-DK-NO                                        [RFC1345,KXS2]
MIBenum: 2067
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICDKNO

Name: EBCDIC-DK-NO-A                                      [RFC1345,KXS2]
MIBenum: 2068
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICDKNOA

Name: EBCDIC-FI-SE                                        [RFC1345,KXS2]
MIBenum: 2069
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICFISE

Name: EBCDIC-FI-SE-A                                      [RFC1345,KXS2]
MIBenum: 2070
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICFISEA

Name: EBCDIC-FR                                           [RFC1345,KXS2]
MIBenum: 2071
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICFR

Name: EBCDIC-IT                                           [RFC1345,KXS2]
MIBenum: 2072
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICIT

Name: EBCDIC-PT                                           [RFC1345,KXS2]
MIBenum: 2073
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICPT

Name: EBCDIC-ES                                           [RFC1345,KXS2]
MIBenum: 2074
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICES

Name: EBCDIC-ES-A                                         [RFC1345,KXS2]
MIBenum: 2075
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICESA

Name: EBCDIC-ES-S                                         [RFC1345,KXS2]
MIBenum: 2076
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICESS

Name: EBCDIC-UK                                           [RFC1345,KXS2]
MIBenum: 2077
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICUK

Name: EBCDIC-US                                           [RFC1345,KXS2]
MIBenum: 2078
Source: IBM 3270 Char Set Ref Ch 10, GA27-2837-9, April 1987
Alias: csEBCDICUS

Name: UNKNOWN-8BIT                                             [RFC1428]
MIBenum: 2079
Alias: csUnknown8BiT

Name: MNEMONIC                                            [RFC1345,KXS2]
MIBenum: 2080
Source: RFC 1345, also known as "mnemonic+ascii+38"
Alias: csMnemonic

Name: MNEM                                                [RFC1345,KXS2]
MIBenum: 2081
Source: RFC 1345, also known as "mnemonic+ascii+8200"
Alias: csMnem

Name: VISCII                                                   [RFC1456]
MIBenum: 2082
Source: RFC 1456
Alias: csVISCII

Name: VIQR                                                     [RFC1456]
MIBenum: 2083
Source: RFC 1456
Alias: csVIQR

Name: KOI8-R  (preferred MIME name)                            [RFC1489]
MIBenum: 2084
Source: RFC 1489, based on GOST-19768-74, ISO-6937/8, 
        INIS-Cyrillic, ISO-5427.
Alias: csKOI8R

Name: KOI8-U                                                   [RFC2319]
MIBenum: 2088
Source: RFC 2319

Name: IBM00858
MIBenum: 2089
Source: IBM See (.../assignments/character-set-info/IBM00858)    [Mahdi]
Alias: CCSID00858
Alias: CP00858
Alias: PC-Multilingual-850+euro

Name: IBM00924
MIBenum: 2090
Source: IBM See (.../assignments/character-set-info/IBM00924)    [Mahdi]
Alias: CCSID00924
Alias: CP00924
Alias: ebcdic-Latin9--euro

Name: IBM01140
MIBenum: 2091
Source: IBM See (.../assignments/character-set-info/IBM01140)    [Mahdi]
Alias: CCSID01140
Alias: CP01140
Alias: ebcdic-us-37+euro

Name: IBM01141
MIBenum: 2092
Source: IBM See (.../assignments/character-set-info/IBM01141)    [Mahdi]
Alias: CCSID01141
Alias: CP01141
Alias: ebcdic-de-273+euro

Name: IBM01142
MIBenum: 2093
Source: IBM See (.../assignments/character-set-info/IBM01142)    [Mahdi]
Alias: CCSID01142
Alias: CP01142
Alias: ebcdic-dk-277+euro
Alias: ebcdic-no-277+euro

Name: IBM01143
MIBenum: 2094
Source: IBM See (.../assignments/character-set-info/IBM01143)    [Mahdi]
Alias: CCSID01143
Alias: CP01143
Alias: ebcdic-fi-278+euro
Alias: ebcdic-se-278+euro

Name: IBM01144
MIBenum: 2095
Source: IBM See (.../assignments/character-set-info/IBM01144)    [Mahdi]
Alias: CCSID01144
Alias: CP01144
Alias: ebcdic-it-280+euro

Name: IBM01145
MIBenum: 2096
Source: IBM See (.../assignments/character-set-info/IBM01145)    [Mahdi]
Alias: CCSID01145
Alias: CP01145
Alias: ebcdic-es-284+euro

Name: IBM01146
MIBenum: 2097
Source: IBM See (.../assignments/character-set-info/IBM01146)    [Mahdi]
Alias: CCSID01146
Alias: CP01146
Alias: ebcdic-gb-285+euro

Name: IBM01147
MIBenum: 2098
Source: IBM See (.../assignments/character-set-info/IBM01147)    [Mahdi]
Alias: CCSID01147
Alias: CP01147
Alias: ebcdic-fr-297+euro

Name: IBM01148
MIBenum: 2099
Source: IBM See (.../assignments/character-set-info/IBM01148)    [Mahdi]
Alias: CCSID01148
Alias: CP01148
Alias: ebcdic-international-500+euro

Name: IBM01149
MIBenum: 2100
Source: IBM See (.../assignments/character-set-info/IBM01149)    [Mahdi]
Alias: CCSID01149
Alias: CP01149
Alias: ebcdic-is-871+euro

Name: Big5-HKSCS
MIBenum: 2101
Source:   See (.../assignments/character-set-info/Big5-HKSCS)     [Yick]
Alias: None

Name: UNICODE-1-1                                              [RFC1641]
MIBenum: 1010
Source: RFC 1641
Alias: csUnicode11

Name: SCSU
MIBenum: 1011
Source: SCSU See (.../assignments/character-set-info/SCSU)     [Scherer]
Alias: None 

Name: UTF-7                                                    [RFC2152]
MIBenum: 1012
Source: RFC 2152
Alias: None

Name: UTF-16BE                                                 [RFC2781]
MIBenum: 1013
Source: RFC 2781
Alias: None

Name: UTF-16LE                                                 [RFC2781]
MIBenum: 1014
Source: RFC 2781
Alias: None

Name: UTF-16                                                   [RFC2781]
MIBenum: 1015
Source: RFC 2781
Alias: None

Name: UNICODE-1-1-UTF-7                                        [RFC1642]
MIBenum: 103
Source: RFC 1642
Alias: csUnicode11UTF7

Name: UTF-8                                                    [RFC2279]
MIBenum: 106
Source: RFC 2279
Alias: None 

Name: iso-8859-13
MIBenum: 109
Source: ISO See (...assignments/character-set-info/iso-8859-13)[Tumasonis] 
Alias: None

Name: iso-8859-14
MIBenum: 110
Source: ISO See (...assignments/character-set-info/iso-8859-14) [Simonsen]
Alias: iso-ir-199
Alias: ISO_8859-14:1998
Alias: ISO_8859-14
Alias: latin8
Alias: iso-celtic
Alias: l8

Name: ISO-8859-15
MIBenum: 111
Source: ISO
Alias: ISO_8859-15

Name: ISO-8859-16
MIBenum: 112
Source: ISO
Alias: 

Name: JIS_Encoding
MIBenum: 16
Source: JIS X 0202-1991.  Uses ISO 2022 escape sequences to
        shift code sets as documented in JIS X 0202-1991.
Alias: csJISEncoding

Name: Shift_JIS  (preferred MIME name)
MIBenum: 17
Source: This charset is an extension of csHalfWidthKatakana by
        adding graphic characters in JIS X 0208.  The CCS's are
        JIS X0201:1997 and JIS X0208:1997.  The
        complete definition is shown in Appendix 1 of JIS
        X0208:1997.
        This charset can be used for the top-level media type "text".
Alias: MS_Kanji 
Alias: csShiftJIS

Name: Extended_UNIX_Code_Packed_Format_for_Japanese
MIBenum: 18
Source: Standardized by OSF, UNIX International, and UNIX Systems
        Laboratories Pacific.  Uses ISO 2022 rules to select
               code set 0: US-ASCII (a single 7-bit byte set)
               code set 1: JIS X0208-1990 (a double 8-bit byte set)
                           restricted to A0-FF in both bytes
               code set 2: Half Width Katakana (a single 7-bit byte set)
                           requiring SS2 as the character prefix
               code set 3: JIS X0212-1990 (a double 7-bit byte set)
                           restricted to A0-FF in both bytes
                           requiring SS3 as the character prefix
Alias: csEUCPkdFmtJapanese
Alias: EUC-JP  (preferred MIME name)

Name: Extended_UNIX_Code_Fixed_Width_for_Japanese
MIBenum: 19
Source: Used in Japan.  Each character is 2 octets.
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
                and 21-7E in the second byte
Alias: csEUCFixWidJapanese

Name: ISO-10646-UCS-Basic
MIBenum: 1002
Source: ASCII subset of Unicode.  Basic Latin = collection 1
        See ISO 10646, Appendix A
Alias: csUnicodeASCII

Name: ISO-10646-Unicode-Latin1
MIBenum: 1003
Source: ISO Latin-1 subset of Unicode. Basic Latin and Latin-1 
         Supplement  = collections 1 and 2.  See ISO 10646, 
         Appendix A.  See RFC 1815.
Alias: csUnicodeLatin1
Alias: ISO-10646

Name: ISO-10646-J-1
Source: ISO 10646 Japanese, see RFC 1815.

Name: ISO-Unicode-IBM-1261
MIBenum: 1005
Source: IBM Latin-2, -3, -5, Extended Presentation Set, GCSGID: 1261
Alias: csUnicodeIBM1261

Name: ISO-Unicode-IBM-1268
MIBenum: 1006
Source: IBM Latin-4 Extended Presentation Set, GCSGID: 1268
Alias: csUnidoceIBM1268

Name: ISO-Unicode-IBM-1276
MIBenum: 1007
Source: IBM Cyrillic Greek Extended Presentation Set, GCSGID: 1276
Alias: csUnicodeIBM1276

Name: ISO-Unicode-IBM-1264
MIBenum: 1008
Source: IBM Arabic Presentation Set, GCSGID: 1264
Alias: csUnicodeIBM1264

Name: ISO-Unicode-IBM-1265
MIBenum: 1009
Source: IBM Hebrew Presentation Set, GCSGID: 1265
Alias: csUnicodeIBM1265

Name: ISO-8859-1-Windows-3.0-Latin-1                           [HP-PCL5] 
MIBenum: 2000
Source: Extended ISO 8859-1 Latin-1 for Windows 3.0.  
        PCL Symbol Set id: 9U
Alias: csWindows30Latin1

Name: ISO-8859-1-Windows-3.1-Latin-1                           [HP-PCL5] 
MIBenum: 2001
Source: Extended ISO 8859-1 Latin-1 for Windows 3.1.  
        PCL Symbol Set id: 19U
Alias: csWindows31Latin1

Name: ISO-8859-2-Windows-Latin-2                               [HP-PCL5] 
MIBenum: 2002
Source: Extended ISO 8859-2.  Latin-2 for Windows 3.1.
        PCL Symbol Set id: 9E
Alias: csWindows31Latin2

Name: ISO-8859-9-Windows-Latin-5                               [HP-PCL5] 
MIBenum: 2003
Source: Extended ISO 8859-9.  Latin-5 for Windows 3.1
        PCL Symbol Set id: 5T
Alias: csWindows31Latin5

Name: Adobe-Standard-Encoding                                    [Adobe]
MIBenum: 2005
Source: PostScript Language Reference Manual
        PCL Symbol Set id: 10J
Alias: csAdobeStandardEncoding

Name: Ventura-US                                               [HP-PCL5]
MIBenum: 2006
Source: Ventura US.  ASCII plus characters typically used in 
        publishing, like pilcrow, copyright, registered, trade mark, 
        section, dagger, and double dagger in the range A0 (hex) 
        to FF (hex).  
        PCL Symbol Set id: 14J
Alias: csVenturaUS  

Name: Ventura-International                                    [HP-PCL5]
MIBenum: 2007
Source: Ventura International.  ASCII plus coded characters similar 
        to Roman8.
        PCL Symbol Set id: 13J
Alias: csVenturaInternational

Name: PC8-Danish-Norwegian                                     [HP-PCL5]
MIBenum: 2012
Source: PC Danish Norwegian
        8-bit PC set for Danish Norwegian
        PCL Symbol Set id: 11U
Alias: csPC8DanishNorwegian

Name: PC8-Turkish                                              [HP-PCL5]
MIBenum: 2014
Source: PC Latin Turkish.  PCL Symbol Set id: 9T
Alias: csPC8Turkish

Name: IBM-Symbols                                             [IBM-CIDT] 
MIBenum: 2015
Source: Presentation Set, CPGID: 259
Alias: csIBMSymbols

Name: IBM-Thai                                                [IBM-CIDT] 
MIBenum: 2016
Source: Presentation Set, CPGID: 838
Alias: csIBMThai

Name: HP-Legal                                                 [HP-PCL5]
MIBenum: 2017
Source: PCL 5 Comparison Guide, Hewlett-Packard,
        HP part number 5961-0510, October 1992
        PCL Symbol Set id: 1U
Alias: csHPLegal

Name: HP-Pi-font                                               [HP-PCL5]
MIBenum: 2018
Source: PCL 5 Comparison Guide, Hewlett-Packard,
        HP part number 5961-0510, October 1992
        PCL Symbol Set id: 15U
Alias: csHPPiFont

Name: HP-Math8                                                 [HP-PCL5]
MIBenum: 2019
Source: PCL 5 Comparison Guide, Hewlett-Packard,
        HP part number 5961-0510, October 1992
        PCL Symbol Set id: 8M
Alias: csHPMath8

Name: Adobe-Symbol-Encoding                                      [Adobe]
MIBenum: 2020
Source: PostScript Language Reference Manual
        PCL Symbol Set id: 5M
Alias: csHPPSMath

Name: HP-DeskTop                                               [HP-PCL5]
MIBenum: 2021
Source: PCL 5 Comparison Guide, Hewlett-Packard,
        HP part number 5961-0510, October 1992
        PCL Symbol Set id: 7J
Alias: csHPDesktop

Name: Ventura-Math                                             [HP-PCL5]
MIBenum: 2022
Source: PCL 5 Comparison Guide, Hewlett-Packard,
        HP part number 5961-0510, October 1992
        PCL Symbol Set id: 6M
Alias: csVenturaMath

Name: Microsoft-Publishing                                     [HP-PCL5]
MIBenum: 2023
Source: PCL 5 Comparison Guide, Hewlett-Packard,
        HP part number 5961-0510, October 1992
        PCL Symbol Set id: 6J
Alias: csMicrosoftPublishing

Name: Windows-31J
MIBenum: 2024
Source: Windows Japanese.  A further extension of Shift_JIS
        to include NEC special characters (Row 13), NEC
        selection of IBM extensions (Rows 89 to 92), and IBM
        extensions (Rows 115 to 119).  The CCS's are
        JIS X0201:1997, JIS X0208:1997, and these extensions.
        This charset can be used for the top-level media type "text",
        but it is of limited or specialized use (see RFC2278).
        PCL Symbol Set id: 19K
Alias: csWindows31J

Name: GB2312  (preferred MIME name)
MIBenum: 2025
Source: Chinese for People's Republic of China (PRC) mixed one byte, 
        two byte set: 
          20-7E = one byte ASCII 
          A1-FE = two byte PRC Kanji 
        See GB 2312-80 
        PCL Symbol Set Id: 18C
Alias: csGB2312

Name: Big5  (preferred MIME name)
MIBenum: 2026
Source: Chinese for Taiwan Multi-byte set.
        PCL Symbol Set Id: 18T
Alias: csBig5

Name: windows-1250
MIBenum: 2250
Source: Microsoft  (see ../character-set-info/windows-1250) [Lazhintseva]
Alias: None

Name: windows-1251
MIBenum: 2251
Source: Microsoft  (see ../character-set-info/windows-1251) [Lazhintseva]
Alias: None

Name: windows-1252
MIBenum: 2252
Source: Microsoft  (see ../character-set-info/windows-1252)       [Wendt]
Alias: None

Name: windows-1253
MIBenum: 2253
Source: Microsoft  (see ../character-set-info/windows-1253) [Lazhintseva]
Alias: None

Name: windows-1254
MIBenum: 2254
Source: Microsoft  (see ../character-set-info/windows-1254) [Lazhintseva]
Alias: None

Name: windows-1255
MIBenum: 2255
Source: Microsoft  (see ../character-set-info/windows-1255) [Lazhintseva]
Alias: None

Name: windows-1256
MIBenum: 2256
Source: Microsoft  (see ../character-set-info/windows-1256) [Lazhintseva]
Alias: None 

Name: windows-1257
MIBenum: 2257
Source: Microsoft  (see ../character-set-info/windows-1257) [Lazhintseva]
Alias: None

Name: windows-1258
MIBenum: 2258
Source: Microsoft  (see ../character-set-info/windows-1258) [Lazhintseva]
Alias: None

Name: TIS-620
MIBenum: 2259
Source: Thai Industrial Standards Institute (TISI)	     [Tantsetthi]

Name: HZ-GB-2312
MIBenum: 2085
Source: RFC 1842, RFC 1843                              [RFC1842, RFC1843]


REFERENCES

[RFC1345]  Simonsen, K., "Character Mnemonics & Character Sets",
           RFC 1345, Rationel Almen Planlaegning, Rationel Almen
           Planlaegning, June 1992.

[RFC1428]  Vaudreuil, G., "Transition of Internet Mail from
           Just-Send-8 to 8bit-SMTP/MIME", RFC1428, CNRI, February
           1993.

[RFC1456]  Vietnamese Standardization Working Group, "Conventions for
           Encoding the Vietnamese Language VISCII: VIetnamese 
           Standard Code for Information Interchange VIQR: VIetnamese 
           Quoted-Readable Specification Revision 1.1", RFC 1456, May
           1993.

[RFC1468]  Murai, J., Crispin, M., and E. van der Poel, "Japanese
           Character Encoding for Internet Messages", RFC 1468,
           Keio University, Panda Programming, June 1993.

[RFC1489]  Chernov, A., "Registration of a Cyrillic Character Set",
           RFC1489, RELCOM Development Team, July 1993. 

[RFC1554]  Ohta, M., and K. Handa, "ISO-2022-JP-2: Multilingual
           Extension of ISO-2022-JP", RFC1554, Tokyo Institute of
           Technology, ETL, December 1993. 

[RFC1556]  Nussbacher, H., "Handling of Bi-directional Texts in MIME",
           RFC1556, Israeli Inter-University, December 1993. 

[RFC1557]  Choi, U., Chon, K., and H. Park, "Korean Character Encoding
           for Internet Messages", KAIST, Solvit Chosun Media,
           December 1993.

[RFC1641]  Goldsmith, D., and M. Davis, "Using Unicode with MIME",
           RFC1641, Taligent, Inc., July 1994. 

[RFC1642]  Goldsmith, D., and M. Davis, "UTF-7", RFC1642, Taligent,
           Inc., July 1994.

[RFC1815]  Ohta, M., "Character Sets ISO-10646 and ISO-10646-J-1",
           RFC 1815, Tokyo Institute of Technology, July 1995.


[Adobe]    Adobe Systems Incorporated, PostScript Language Reference
           Manual, second edition, Addison-Wesley Publishing Company,
           Inc., 1990.

[HP-PCL5]  Hewlett-Packard Company, "HP PCL 5 Comparison Guide", 
           (P/N 5021-0329) pp B-13, 1996.

[IBM-CIDT] IBM Corporation, "ABOUT TYPE: IBM's Technical Reference
           for Core Interchange Digitized Type", Publication number
           S544-3708-01

[RFC1842]  Wei, Y., J. Li, and Y. Jiang, "ASCII Printable
           Characters-Based Chinese Character Encoding for Internet
           Messages", RFC 1842, Harvard University, Rice University,
           University of Maryland, August 1995.

[RFC1843]  Lee, F., "HZ - A Data Format for Exchanging Files of
           Arbitrarily Mixed Chinese and ASCII Characters", RFC 1843,
           Stanford University, August 1995.

[RFC2152]  Goldsmith, D., M. Davis, "UTF-7: A Mail-Safe Transformation
	   Format of Unicode", RFC 2152, Apple Computer, Inc.,
	   Taligent Inc., May 1997.

[RFC2279]  Yergeau, F., "UTF-8, A Transformation Format of ISO 10646",
           RFC 2279, Alis Technologies, January, 1998.

[RFC2781]  Hoffman, P., Yergeau, F., "UTF-16, an encoding of ISO 10646",
           RFC 2781, February 2000.


PEOPLE

[KXS2] Keld Simonsen <Keld.Simonsen@dkuug.dk>

[Choi] Woohyong Choi <whchoi@cosmos.kaist.ac.kr>

[Lazhintseva] Katya Lazhintseva, <katyal@MICROSOFT.com>, May 1996.

[Mahdi] Tamer Mahdi, <tamer@ca.ibm.com>, August 2000.

[Murai] Jun Murai <jun@wide.ad.jp>

[Ohta] Masataka Ohta, <mohta@cc.titech.ac.jp>, July 1995.

[Nussbacher] Hank Nussbacher, <hank@vm.tau.ac.il>

[Pond] Rick Pond, <rickpond@vnet.ibm.com> March 1997.

[Scherer] Markus Scherer, <markus.scherer@jtcsv.com>, August 2000.

[Simonsen] Keld Simonsen, <Keld.Simonsen@rap.dk>, August 2000.

[Tantsetthi] Trin Tantsetthi, <trin@mozart.inet.co.th>, September 1998.

[Tumasonis] Vladas Tumasonis, <vladas.tumasonis@maf.vu.lt>, August 2000.

[Wendt] Chris Wendt, <christw@microsoft.com>, December 1999.

[Yick] Nicky Yick, <cliac@itsd.gcn.gov.hk>, October 2000.

[]







