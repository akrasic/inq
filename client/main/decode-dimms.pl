#!/usr/bin/perl -w
#
# EEPROM data decoder for SDRAM DIMM modules
#
# Copyright 1998, 1999 Philip Edelbrock <phil@netroedge.com>
# modified by Christian Zuckschwerdt <zany@triq.net>
# modified by Burkart Lingner <burkart@bollchen.de>
# Copyright (C) 2005-2011  Jean Delvare <khali@linux-fr.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#    MA 02110-1301 USA.
#
#
# The eeprom driver must be loaded (unless option -x is used). For kernels
# older than 2.6.0, the eeprom driver can be found in the lm-sensors package.
#
# References:
# PC SDRAM Serial Presence
# Detect (SPD) Specification, Intel,
# 1997,1999, Rev 1.2B
#
# Jedec Standards 4.1.x & 4.5.x
# http://www.jedec.org
#

require 5.004;

use strict;
use POSIX qw(ceil);
use Fcntl qw(:DEFAULT :seek);
use vars qw($opt_html $opt_bodyonly $opt_side_by_side $opt_merge
	    $opt_igncheck $use_sysfs $use_hexdump $sbs_col_width
	    @vendors %decode_callback $revision @dimm $current %hexdump_cache);

use constant LITTLEENDIAN	=> "little-endian";
use constant BIGENDIAN		=> "big-endian";

$revision = '$Revision: 5929 $ ($Date: 2011-02-16 16:58:38 +0300 (Mi, 16. Feb 2011) $)';
$revision =~ s/\$\w+: (.*?) \$/$1/g;
$revision =~ s/ \([^()]*\)//;

@vendors = (
["AMD", "AMI", "Fairchild", "Fujitsu",
 "GTE", "Harris", "Hitachi", "Inmos",
 "Intel", "I.T.T.", "Intersil", "Monolithic Memories",
 "Mostek", "Freescale (former Motorola)", "National", "NEC",
 "RCA", "Raytheon", "Conexant (Rockwell)", "Seeq",
 "NXP (former Signetics, Philips Semi.)", "Synertek", "Texas Instruments", "Toshiba",
 "Xicor", "Zilog", "Eurotechnique", "Mitsubishi",
 "Lucent (AT&T)", "Exel", "Atmel", "SGS/Thomson",
 "Lattice Semi.", "NCR", "Wafer Scale Integration", "IBM",
 "Tristar", "Visic", "Intl. CMOS Technology", "SSSI",
 "MicrochipTechnology", "Ricoh Ltd.", "VLSI", "Micron Technology",
 "Hyundai Electronics", "OKI Semiconductor", "ACTEL", "Sharp",
 "Catalyst", "Panasonic", "IDT", "Cypress",
 "DEC", "LSI Logic", "Zarlink (former Plessey)", "UTMC",
 "Thinking Machine", "Thomson CSF", "Integrated CMOS (Vertex)", "Honeywell",
 "Tektronix", "Sun Microsystems", "SST", "ProMos/Mosel Vitelic",
 "Infineon (former Siemens)", "Macronix", "Xerox", "Plus Logic",
 "SunDisk", "Elan Circuit Tech.", "European Silicon Str.", "Apple Computer",
 "Xilinx", "Compaq", "Protocol Engines", "SCI",
 "Seiko Instruments", "Samsung", "I3 Design System", "Klic",
 "Crosspoint Solutions", "Alliance Semiconductor", "Tandem", "Hewlett-Packard",
 "Intg. Silicon Solutions", "Brooktree", "New Media", "MHS Electronic",
 "Performance Semi.", "Winbond Electronic", "Kawasaki Steel", "Bright Micro",
 "TECMAR", "Exar", "PCMCIA", "LG Semi (former Goldstar)",
 "Northern Telecom", "Sanyo", "Array Microsystems", "Crystal Semiconductor",
 "Analog Devices", "PMC-Sierra", "Asparix", "Convex Computer",
 "Quality Semiconductor", "Nimbus Technology", "Transwitch", "Micronas (ITT Intermetall)",
 "Cannon", "Altera", "NEXCOM", "QUALCOMM",
 "Sony", "Cray Research", "AMS(Austria Micro)", "Vitesse",
 "Aster Electronics", "Bay Networks (Synoptic)", "Zentrum or ZMD", "TRW",
 "Thesys", "Solbourne Computer", "Allied-Signal", "Dialog",
 "Media Vision", "Level One Communication"],
["Cirrus Logic", "National Instruments", "ILC Data Device", "Alcatel Mietec",
 "Micro Linear", "Univ. of NC", "JTAG Technologies", "BAE Systems",
 "Nchip", "Galileo Tech", "Bestlink Systems", "Graychip",
 "GENNUM", "VideoLogic", "Robert Bosch", "Chip Express",
 "DATARAM", "United Microelec Corp.", "TCSI", "Smart Modular",
 "Hughes Aircraft", "Lanstar Semiconductor", "Qlogic", "Kingston",
 "Music Semi", "Ericsson Components", "SpaSE", "Eon Silicon Devices",
 "Programmable Micro Corp", "DoD", "Integ. Memories Tech.", "Corollary Inc.",
 "Dallas Semiconductor", "Omnivision", "EIV(Switzerland)", "Novatel Wireless",
 "Zarlink (former Mitel)", "Clearpoint", "Cabletron", "STEC (former Silicon Technology)",
 "Vanguard", "Hagiwara Sys-Com", "Vantis", "Celestica",
 "Century", "Hal Computers", "Rohm Company Ltd.", "Juniper Networks",
 "Libit Signal Processing", "Mushkin Enhanced Memory", "Tundra Semiconductor", "Adaptec Inc.",
 "LightSpeed Semi.", "ZSP Corp.", "AMIC Technology", "Adobe Systems",
 "Dynachip", "PNY Electronics", "Newport Digital", "MMC Networks",
 "T Square", "Seiko Epson", "Broadcom", "Viking Components",
 "V3 Semiconductor", "Flextronics (former Orbit)", "Suwa Electronics", "Transmeta",
 "Micron CMS", "American Computer & Digital Components Inc", "Enhance 3000 Inc", "Tower Semiconductor",
 "CPU Design", "Price Point", "Maxim Integrated Product", "Tellabs",
 "Centaur Technology", "Unigen Corporation", "Transcend Information", "Memory Card Technology",
 "CKD Corporation Ltd.", "Capital Instruments, Inc.", "Aica Kogyo, Ltd.", "Linvex Technology",
 "MSC Vertriebs GmbH", "AKM Company, Ltd.", "Dynamem, Inc.", "NERA ASA",
 "GSI Technology", "Dane-Elec (C Memory)", "Acorn Computers", "Lara Technology",
 "Oak Technology, Inc.", "Itec Memory", "Tanisys Technology", "Truevision",
 "Wintec Industries", "Super PC Memory", "MGV Memory", "Galvantech",
 "Gadzoox Nteworks", "Multi Dimensional Cons.", "GateField", "Integrated Memory System",
 "Triscend", "XaQti", "Goldenram", "Clear Logic",
 "Cimaron Communications", "Nippon Steel Semi. Corp.", "Advantage Memory", "AMCC",
 "LeCroy", "Yamaha Corporation", "Digital Microwave", "NetLogic Microsystems",
 "MIMOS Semiconductor", "Advanced Fibre", "BF Goodrich Data.", "Epigram",
 "Acbel Polytech Inc.", "Apacer Technology", "Admor Memory", "FOXCONN",
 "Quadratics Superconductor", "3COM"],
["Camintonn Corporation", "ISOA Incorporated", "Agate Semiconductor", "ADMtek Incorporated",
 "HYPERTEC", "Adhoc Technologies", "MOSAID Technologies", "Ardent Technologies",
 "Switchcore", "Cisco Systems, Inc.", "Allayer Technologies", "WorkX AG",
 "Oasis Semiconductor", "Novanet Semiconductor", "E-M Solutions", "Power General",
 "Advanced Hardware Arch.", "Inova Semiconductors GmbH", "Telocity", "Delkin Devices",
 "Symagery Microsystems", "C-Port Corporation", "SiberCore Technologies", "Southland Microsystems",
 "Malleable Technologies", "Kendin Communications", "Great Technology Microcomputer", "Sanmina Corporation",
 "HADCO Corporation", "Corsair", "Actrans System Inc.", "ALPHA Technologies",
 "Silicon Laboratories, Inc. (Cygnal)", "Artesyn Technologies", "Align Manufacturing", "Peregrine Semiconductor",
 "Chameleon Systems", "Aplus Flash Technology", "MIPS Technologies", "Chrysalis ITS",
 "ADTEC Corporation", "Kentron Technologies", "Win Technologies", "Tachyon Semiconductor (former ASIC Designs Inc.)",
 "Extreme Packet Devices", "RF Micro Devices", "Siemens AG", "Sarnoff Corporation",
 "Itautec Philco SA", "Radiata Inc.", "Benchmark Elect. (AVEX)", "Legend",
 "SpecTek Incorporated", "Hi/fn", "Enikia Incorporated", "SwitchOn Networks",
 "AANetcom Incorporated", "Micro Memory Bank", "ESS Technology", "Virata Corporation",
 "Excess Bandwidth", "West Bay Semiconductor", "DSP Group", "Newport Communications",
 "Chip2Chip Incorporated", "Phobos Corporation", "Intellitech Corporation", "Nordic VLSI ASA",
 "Ishoni Networks", "Silicon Spice", "Alchemy Semiconductor", "Agilent Technologies",
 "Centillium Communications", "W.L. Gore", "HanBit Electronics", "GlobeSpan",
 "Element 14", "Pycon", "Saifun Semiconductors", "Sibyte, Incorporated",
 "MetaLink Technologies", "Feiya Technology", "I & C Technology", "Shikatronics",
 "Elektrobit", "Megic", "Com-Tier", "Malaysia Micro Solutions",
 "Hyperchip", "Gemstone Communications", "Anadigm (former Anadyne)", "3ParData",
 "Mellanox Technologies", "Tenx Technologies", "Helix AG", "Domosys",
 "Skyup Technology", "HiNT Corporation", "Chiaro", "MDT Technologies GmbH (former MCI Computer GMBH)",
 "Exbit Technology A/S", "Integrated Technology Express", "AVED Memory", "Legerity",
 "Jasmine Networks", "Caspian Networks", "nCUBE", "Silicon Access Networks",
 "FDK Corporation", "High Bandwidth Access", "MultiLink Technology", "BRECIS",
 "World Wide Packets", "APW", "Chicory Systems", "Xstream Logic",
 "Fast-Chip", "Zucotto Wireless", "Realchip", "Galaxy Power",
 "eSilicon", "Morphics Technology", "Accelerant Networks", "Silicon Wave",
 "SandCraft", "Elpida"],
["Solectron", "Optosys Technologies", "Buffalo (former Melco)", "TriMedia Technologies",
 "Cyan Technologies", "Global Locate", "Optillion", "Terago Communications",
 "Ikanos Communications", "Princeton Technology", "Nanya Technology", "Elite Flash Storage",
 "Mysticom", "LightSand Communications", "ATI Technologies", "Agere Systems",
 "NeoMagic", "AuroraNetics", "Golden Empire", "Mushkin",
 "Tioga Technologies", "Netlist", "TeraLogic", "Cicada Semiconductor",
 "Centon Electronics", "Tyco Electronics", "Magis Works", "Zettacom",
 "Cogency Semiconductor", "Chipcon AS", "Aspex Technology", "F5 Networks",
 "Programmable Silicon Solutions", "ChipWrights", "Acorn Networks", "Quicklogic",
 "Kingmax Semiconductor", "BOPS", "Flasys", "BitBlitz Communications",
 "eMemory Technology", "Procket Networks", "Purple Ray", "Trebia Networks",
 "Delta Electronics", "Onex Communications", "Ample Communications", "Memory Experts Intl",
 "Astute Networks", "Azanda Network Devices", "Dibcom", "Tekmos",
 "API NetWorks", "Bay Microsystems", "Firecron Ltd", "Resonext Communications",
 "Tachys Technologies", "Equator Technology", "Concept Computer", "SILCOM",
 "3Dlabs", "c't Magazine", "Sanera Systems", "Silicon Packets",
 "Viasystems Group", "Simtek", "Semicon Devices Singapore", "Satron Handelsges",
 "Improv Systems", "INDUSYS GmbH", "Corrent", "Infrant Technologies",
 "Ritek Corp", "empowerTel Networks", "Hypertec", "Cavium Networks",
 "PLX Technology", "Massana Design", "Intrinsity", "Valence Semiconductor",
 "Terawave Communications", "IceFyre Semiconductor", "Primarion", "Picochip Designs Ltd",
 "Silverback Systems", "Jade Star Technologies", "Pijnenburg Securealink",
 "TakeMS International AG", "Cambridge Silicon Radio",
 "Swissbit", "Nazomi Communications", "eWave System",
 "Rockwell Collins", "Picocel Co., Ltd.", "Alphamosaic Ltd", "Sandburst",
 "SiCon Video", "NanoAmp Solutions", "Ericsson Technology", "PrairieComm",
 "Mitac International", "Layer N Networks", "MtekVision", "Allegro Networks",
 "Marvell Semiconductors", "Netergy Microelectronic", "NVIDIA", "Internet Machines",
 "Peak Electronics", "Litchfield Communication", "Accton Technology", "Teradiant Networks",
 "Europe Technologies", "Cortina Systems", "RAM Components", "Raqia Networks",
 "ClearSpeed", "Matsushita Battery", "Xelerated", "SimpleTech",
 "Utron Technology", "Astec International", "AVM gmbH", "Redux Communications",
 "Dot Hill Systems", "TeraChip"],
["T-RAM Incorporated", "Innovics Wireless", "Teknovus", "KeyEye Communications",
 "Runcom Technologies", "RedSwitch", "Dotcast", "Silicon Mountain Memory",
 "Signia Technologies", "Pixim", "Galazar Networks", "White Electronic Designs",
 "Patriot Scientific", "Neoaxiom Corporation", "3Y Power Technology", "Europe Technologies",
 "Potentia Power Systems", "C-guys Incorporated", "Digital Communications Technology Incorporated", "Silicon-Based Technology",
 "Fulcrum Microsystems", "Positivo Informatica Ltd", "XIOtech Corporation", "PortalPlayer",
 "Zhiying Software", "Direct2Data", "Phonex Broadband", "Skyworks Solutions",
 "Entropic Communications", "Pacific Force Technology", "Zensys A/S", "Legend Silicon Corp.",
 "sci-worx GmbH", "SMSC (former Oasis Silicon Systems)", "Renesas Technology", "Raza Microelectronics",
 "Phyworks", "MediaTek", "Non-cents Productions", "US Modular",
 "Wintegra Ltd", "Mathstar", "StarCore", "Oplus Technologies",
 "Mindspeed", "Just Young Computer", "Radia Communications", "OCZ",
 "Emuzed", "LOGIC Devices", "Inphi Corporation", "Quake Technologies",
 "Vixel", "SolusTek", "Kongsberg Maritime", "Faraday Technology",
 "Altium Ltd.", "Insyte", "ARM Ltd.", "DigiVision",
 "Vativ Technologies", "Endicott Interconnect Technologies", "Pericom", "Bandspeed",
 "LeWiz Communications", "CPU Technology", "Ramaxel Technology", "DSP Group",
 "Axis Communications", "Legacy Electronics", "Chrontel", "Powerchip Semiconductor",
 "MobilEye Technologies", "Excel Semiconductor", "A-DATA Technology", "VirtualDigm",
 "G Skill Intl", "Quanta Computer", "Yield Microelectronics", "Afa Technologies",
 "KINGBOX Technology Co. Ltd.", "Ceva", "iStor Networks", "Advance Modules",
 "Microsoft", "Open-Silicon", "Goal Semiconductor", "ARC International",
 "Simmtec", "Metanoia", "Key Stream", "Lowrance Electronics",
 "Adimos", "SiGe Semiconductor", "Fodus Communications", "Credence Systems Corp.",
 "Genesis Microchip Inc.", "Vihana, Inc.", "WIS Technologies", "GateChange Technologies",
 "High Density Devices AS", "Synopsys", "Gigaram", "Enigma Semiconductor Inc.",
 "Century Micro Inc.", "Icera Semiconductor", "Mediaworks Integrated Systems", "O'Neil Product Development",
 "Supreme Top Technology Ltd.", "MicroDisplay Corporation", "Team Group Inc.", "Sinett Corporation",
 "Toshiba Corporation", "Tensilica", "SiRF Technology", "Bacoc Inc.",
 "SMaL Camera Technologies", "Thomson SC", "Airgo Networks", "Wisair Ltd.",
 "SigmaTel", "Arkados", "Compete IT gmbH Co. KG", "Eudar Technology Inc.",
 "Focus Enhancements", "Xyratex"],
["Specular Networks", "Patriot Memory", "U-Chip Technology Corp.", "Silicon Optix",
 "Greenfield Networks", "CompuRAM GmbH", "Stargen, Inc.", "NetCell Corporation",
 "Excalibrus Technologies Ltd", "SCM Microsystems", "Xsigo Systems, Inc.", "CHIPS & Systems Inc",
 "Tier 1 Multichip Solutions", "CWRL Labs", "Teradici", "Gigaram, Inc.",
 "g2 Microsystems", "PowerFlash Semiconductor", "P.A. Semi, Inc.", "NovaTech Solutions, S.A.",
 "c2 Microsystems, Inc.", "Level5 Networks", "COS Memory AG", "Innovasic Semiconductor",
 "02IC Co. Ltd", "Tabula, Inc.", "Crucial Technology", "Chelsio Communications",
 "Solarflare Communications", "Xambala Inc.", "EADS Astrium", "ATO Semicon Co. Ltd.",
 "Imaging Works, Inc.", "Astute Networks, Inc.", "Tzero", "Emulex",
 "Power-One", "Pulse~LINK Inc.", "Hon Hai Precision Industry", "White Rock Networks Inc.",
 "Telegent Systems USA, Inc.", "Atrua Technologies, Inc.", "Acbel Polytech Inc.",
 "eRide Inc.","ULi Electronics Inc.", "Magnum Semiconductor Inc.", "neoOne Technology, Inc.",
 "Connex Technology, Inc.", "Stream Processors, Inc.", "Focus Enhancements", "Telecis Wireless, Inc.",
 "uNav Microelectronics", "Tarari, Inc.", "Ambric, Inc.", "Newport Media, Inc.", "VMTS",
 "Enuclia Semiconductor, Inc.", "Virtium Technology Inc.", "Solid State System Co., Ltd.", "Kian Tech LLC",
 "Artimi", "Power Quotient International", "Avago Technologies", "ADTechnology", "Sigma Designs",
 "SiCortex, Inc.", "Ventura Technology Group", "eASIC", "M.H.S. SAS", "Micro Star International",
 "Rapport Inc.", "Makway International", "Broad Reach Engineering Co.",
 "Semiconductor Mfg Intl Corp", "SiConnect", "FCI USA Inc.", "Validity Sensors",
 "Coney Technology Co. Ltd.", "Spans Logic", "Neterion Inc.", "Qimonda",
 "New Japan Radio Co. Ltd.", "Velogix", "Montalvo Systems", "iVivity Inc.", "Walton Chaintech",
 "AENEON", "Lorom Industrial Co. Ltd.", "Radiospire Networks", "Sensio Technologies, Inc.",
 "Nethra Imaging", "Hexon Technology Pte Ltd", "CompuStocx (CSX)", "Methode Electronics, Inc.",
 "Connect One Ltd.", "Opulan Technologies", "Septentrio NV", "Goldenmars Technology Inc.",
 "Kreton Corporation", "Cochlear Ltd.", "Altair Semiconductor", "NetEffect, Inc.",
 "Spansion, Inc.", "Taiwan Semiconductor Mfg", "Emphany Systems Inc.",
 "ApaceWave Technologies", "Mobilygen Corporation", "Tego", "Cswitch Corporation",
 "Haier (Beijing) IC Design Co.", "MetaRAM", "Axel Electronics Co. Ltd.", "Tilera Corporation",
 "Aquantia", "Vivace Semiconductor", "Redpine Signals", "Octalica", "InterDigital Communications",
 "Avant Technology", "Asrock, Inc.", "Availink", "Quartics, Inc.", "Element CXI",
 "Innovaciones Microelectronicas", "VeriSilicon Microelectronics", "W5 Networks"],
["MOVEKING", "Mavrix Technology, Inc.", "CellGuide Ltd.", "Faraday Technology",
 "Diablo Technologies, Inc.", "Jennic", "Octasic", "Molex Incorporated", "3Leaf Networks",
 "Bright Micron Technology", "Netxen", "NextWave Broadband Inc.", "DisplayLink", "ZMOS Technology",
 "Tec-Hill", "Multigig, Inc.", "Amimon", "Euphonic Technologies, Inc.", "BRN Phoenix",
 "InSilica", "Ember Corporation", "Avexir Technologies Corporation", "Echelon Corporation",
 "Edgewater Computer Systems", "XMOS Semiconductor Ltd.", "GENUSION, Inc.", "Memory Corp NV",
 "SiliconBlue Technologies", "Rambus Inc."]);

$use_sysfs = -d '/sys/bus';

# We consider that no data was written to this area of the SPD EEPROM if
# all bytes read 0x00 or all bytes read 0xff
sub spd_written(@)
{
	my $all_00 = 1;
	my $all_ff = 1;

	foreach my $b (@_) {
		$all_00 = 0 unless $b == 0x00;
		$all_ff = 0 unless $b == 0xff;
		return 1 unless $all_00 or $all_ff;
	}

	return 0;
}

sub parity($)
{
	my $n = shift;
	my $parity = 0;

	while ($n) {
		$parity++ if ($n & 1);
		$n >>= 1;
	}

	return ($parity & 1);
}

# New encoding format (as of DDR3) for manufacturer just has a count of
# leading 0x7F rather than all the individual bytes.  The count bytes includes
# parity!
sub manufacturer_ddr3($$)
{
	my ($count, $code) = @_;
	return "Invalid" if parity($count) != 1;
	return "Invalid" if parity($code) != 1;
	return (($code & 0x7F) - 1 > $vendors[$count & 0x7F]) ? "Unknown" :
		$vendors[$count & 0x7F][($code & 0x7F) - 1];
}

sub manufacturer(@)
{
	my @bytes = @_;
	my $ai = 0;
	my $first;

	return ("Undefined", []) unless spd_written(@bytes);

	while (defined($first = shift(@bytes)) && $first == 0x7F) {
		$ai++;
	}

	return ("Invalid", []) unless defined $first;
	return ("Invalid", [$first, @bytes]) if parity($first) != 1;
	if (parity($ai) == 0) {
		$ai |= 0x80;
	}
	return (manufacturer_ddr3($ai, $first), \@bytes);
}

sub manufacturer_data(@)
{
	my $hex = "";
	my $asc = "";

	return unless spd_written(@_);

	foreach my $byte (@_) {
		$hex .= sprintf("\%02X ", $byte);
		$asc .= ($byte >= 32 && $byte < 127) ? chr($byte) : '?';
	}

	return "$hex(\"$asc\")";
}

sub part_number(@)
{
	my $asc = "";
	my $byte;

	while (defined ($byte = shift) && $byte >= 32 && $byte < 127) {
		$asc .= chr($byte);
	}

	return ($asc eq "") ? "Undefined" : $asc;
}

sub cas_latencies(@)
{
	return "None" unless @_;
	return join ', ', map("${_}T", sort { $b <=> $a } @_);
}

# Real printing functions

sub html_encode($)
{
	my $text = shift;
	$text =~ s/</\&lt;/sg;
	$text =~ s/>/\&gt;/sg;
	$text =~ s/\n/<br>\n/sg;
	return $text;
}

sub same_values(@)
{
	my $value = shift;
	while (@_) {
		return 0 unless $value eq shift;
	}
	return 1;
}

sub real_printl($$) # print a line w/ label and values
{
	my ($label, @values) = @_;
	local $_;
	my $same_values = same_values(@values);

	# If all values are N/A, don't bother printing
	return if $values[0] eq "N/A" and $same_values;

	if ($opt_html) {
		$label = html_encode($label);
		@values = map { html_encode($_) } @values;
		print "<tr><td valign=top>$label</td>";
		if ($opt_merge && $same_values) {
			print "<td colspan=".(scalar @values).">$values[0]</td>";
		} else {
			print "<td>$_</td>" foreach @values;
		}
		print "</tr>\n";
	} else {
		if ($opt_merge && $same_values) {
			splice(@values, 1);
		}

		my $format = "%-47s".((" %-".$sbs_col_width."s") x (scalar @values - 1))." %s\n";
		my $maxl = 0; # Keep track of the max number of lines

		# It's a bit tricky because each value may span over more than
		# one line. We can easily extract the values per column, but
		# we need them per line at printing time. So we have to
		# prepare a 2D array with all the individual string fragments.
		my ($col, @lines);
		for ($col = 0; $col < @values; $col++) {
			my @cells = split /\n/, $values[$col];
			$maxl = @cells if @cells > $maxl;
			for (my $l = 0; $l < @cells; $l++) {
				$lines[$l]->[$col] = $cells[$l];
			}
		}

		# Also make sure there are no holes in the array
		for (my $l = 0; $l < $maxl; $l++) {
			for ($col = 0; $col < @values; $col++) {
				$lines[$l]->[$col] = ""
					if not defined $lines[$l]->[$col];
			}
		}

		printf $format, $label, @{shift @lines};
		printf $format, "", @{$_} foreach (@lines);
	}
}

sub printl2($$) # print a line w/ label and value (outside a table)
{
	my ($label, $value) = @_;
	if ($opt_html) {
		$label = html_encode($label);
		$value = html_encode($value);
	}
	print "$label: $value\n";
}

sub real_prints($) # print separator w/ given text
{
	my ($label, $ncol) = @_;
	$ncol = 1 unless $ncol;
	if ($opt_html) {
		$label = html_encode($label);
		print "<tr><td align=center colspan=".(1+$ncol)."><b>$label</b></td></tr>\n";
	} else {
		print "\n---=== $label ===---\n";
	}
}

sub printh($$) # print header w/ given text
{
	my ($header, $sub) = @_;
	if ($opt_html) {
		$header = html_encode($header);
		$sub = html_encode($sub);
		print "<h1>$header</h1>\n";
		print "<p>$sub</p>\n";
	} else {
		print "\n$header\n$sub\n";
	}
}

sub printc($) # print comment
{
	my ($comment) = @_;
	if ($opt_html) {
		$comment = html_encode($comment);
		print "<!-- $comment -->\n";
	} else {
		print "# $comment\n";
	}
}

# Fake printing functions
# These don't actually print anything, instead they store the desired
# output for later processing.

sub printl($$) # print a line w/ label and value
{
	my @output = (\&real_printl, @_);
	push @{$dimm[$current]->{output}}, \@output;
}

sub printl_cond($$$) # same as printl but conditional
{
	my ($cond, $label, $value) = @_;
	return unless $cond || $opt_side_by_side;
	printl($label, $cond ? $value : "N/A");
}

sub prints($) # print separator w/ given text
{
	my @output = (\&real_prints, @_);
	push @{$dimm[$current]->{output}}, \@output;
}

# Helper functions

sub tns($) # print a time in ns
{
	return sprintf("%3.2f ns", $_[0]);
}

sub tns3($) # print a time in ns, with 3 decimal digits
{
	return sprintf("%.3f ns", $_[0]);
}

sub value_or_undefined
{
	my ($value, $unit) = @_;
	return "Undefined!" unless $value;
	$value .= " $unit" if defined $unit;
	return $value;
}

# Common to SDR, DDR and DDR2 SDRAM
sub sdram_voltage_interface_level($)
{
	my @levels = (
		"TTL (5V tolerant)",		#  0
		"LVTTL (not 5V tolerant)",	#  1
		"HSTL 1.5V",			#  2
		"SSTL 3.3V",			#  3
		"SSTL 2.5V",			#  4
		"SSTL 1.8V",			#  5
	);
	
	return ($_[0] < @levels) ? $levels[$_[0]] : "Undefined!";
}

# Common to SDR and DDR SDRAM
sub sdram_module_configuration_type($)
{
	my @types = (
		"No Parity",			# 0
		"Parity",			# 1
		"ECC",				# 2
	);

	return ($_[0] < @types) ? $types[$_[0]] : "Undefined!";
}

# Parameter: EEPROM bytes 0-127 (using 3-62)
sub decode_sdr_sdram($)
{
	my $bytes = shift;
	my $temp;

# SPD revision
	printl("SPD Revision", $bytes->[62]);

#size computation

	prints("Memory Characteristics");

	my $k = 0;
	my $ii = 0;

	$ii = ($bytes->[3] & 0x0f) + ($bytes->[4] & 0x0f) - 17;
	if (($bytes->[5] <= 8) && ($bytes->[17] <= 8)) {
		 $k = $bytes->[5] * $bytes->[17];
	}

	if ($ii > 0 && $ii <= 12 && $k > 0) {
		printl("Size", ((1 << $ii) * $k) . " MB");
	} else {
		printl("Size", "INVALID: " . $bytes->[3] . "," . $bytes->[4] . "," .
			       $bytes->[5] . "," . $bytes->[17]);
	}

	my @cas;
	for ($ii = 0; $ii < 7; $ii++) {
		push(@cas, $ii + 1) if ($bytes->[18] & (1 << $ii));
	}

	my $trcd;
	my $trp;
	my $tras;
	my $ctime = ($bytes->[9] >> 4) + ($bytes->[9] & 0xf) * 0.1;

	$trcd = $bytes->[29];
	$trp = $bytes->[27];;
	$tras = $bytes->[30];

	printl("tCL-tRCD-tRP-tRAS",
		$cas[$#cas] . "-" .
		ceil($trcd/$ctime) . "-" .
		ceil($trp/$ctime) . "-" .
		ceil($tras/$ctime));

	if ($bytes->[3] == 0) { $temp = "Undefined!"; }
	elsif ($bytes->[3] == 1) { $temp = "1/16"; }
	elsif ($bytes->[3] == 2) { $temp = "2/17"; }
	elsif ($bytes->[3] == 3) { $temp = "3/18"; }
	else { $temp = $bytes->[3]; }
	printl("Number of Row Address Bits", $temp);

	if ($bytes->[4] == 0) { $temp = "Undefined!"; }
	elsif ($bytes->[4] == 1) { $temp = "1/16"; }
	elsif ($bytes->[4] == 2) { $temp = "2/17"; }
	elsif ($bytes->[4] == 3) { $temp = "3/18"; }
	else { $temp = $bytes->[4]; }
	printl("Number of Col Address Bits", $temp);

	printl("Number of Module Rows", value_or_undefined($bytes->[5]));

	if ($bytes->[7] > 1) { $temp = "Undefined!"; }
	else { $temp = ($bytes->[7] * 256) + $bytes->[6]; }
	printl("Data Width", $temp);

	printl("Voltage Interface Level",
	       sdram_voltage_interface_level($bytes->[8]));

	printl("Module Configuration Type",
	       sdram_module_configuration_type($bytes->[11]));

	printl("Refresh Rate", ddr2_refresh_rate($bytes->[12]));

	if ($bytes->[13] & 0x80) { $temp = "Bank2 = 2 x Bank1"; }
	else { $temp = "No Bank2 OR Bank2 = Bank1 width"; }
	printl("Primary SDRAM Component Bank Config", $temp);
	printl("Primary SDRAM Component Widths",
	       value_or_undefined($bytes->[13] & 0x7f));

	if ($bytes->[14] & 0x80) { $temp = "Bank2 = 2 x Bank1"; }
	else { $temp = "No Bank2 OR Bank2 = Bank1 width"; }
	printl("Error Checking SDRAM Component Bank Config", $temp);
	printl("Error Checking SDRAM Component Widths",
	       value_or_undefined($bytes->[14] & 0x7f));

	printl("Min Clock Delay for Back to Back Random Access",
	       value_or_undefined($bytes->[15]));

	my @array;
	for ($ii = 0; $ii < 4; $ii++) {
		push(@array, 1 << $ii) if ($bytes->[16] & (1 << $ii));
	}
	push(@array, "Page") if ($bytes->[16] & 128);
	if (@array) { $temp = join ', ', @array; }
	else { $temp = "None"; }
	printl("Supported Burst Lengths", $temp);

	printl("Number of Device Banks",
	       value_or_undefined($bytes->[17]));

	printl("Supported CAS Latencies", cas_latencies(@cas));

	@array = ();
	for ($ii = 0; $ii < 7; $ii++) {
		push(@array, $ii) if ($bytes->[19] & (1 << $ii));
	}
	if (@array) { $temp = join ', ', @array; }
	else { $temp = "None"; }
	printl("Supported CS Latencies", $temp);

	@array = ();
	for ($ii = 0; $ii < 7; $ii++) {
		push(@array, $ii) if ($bytes->[20] & (1 << $ii));
	}
	if (@array) { $temp = join ', ', @array; }
	else { $temp = "None"; }
	printl("Supported WE Latencies", $temp);

	my ($cycle_time, $access_time);

	if (@cas >= 1) {
		$cycle_time = "$ctime ns at CAS ".$cas[$#cas];

		$temp = ($bytes->[10] >> 4) + ($bytes->[10] & 0xf) * 0.1;
		$access_time = "$temp ns at CAS ".$cas[$#cas];
	}

	if (@cas >= 2 && spd_written(@$bytes[23..24])) {
		$temp = $bytes->[23] >> 4;
		if ($temp == 0) { $temp = "Undefined!"; }
		else {
			$temp += 15 if $temp < 4;
			$temp += ($bytes->[23] & 0xf) * 0.1;
			$temp .= " ns";
		}
		$cycle_time .= "\n$temp ns at CAS ".$cas[$#cas-1];

		$temp = $bytes->[24] >> 4;
		if ($temp == 0) { $temp = "Undefined!"; }
		else {
			$temp += 15 if $temp < 4;
			$temp += ($bytes->[24] & 0xf) * 0.1;
			$temp .= " ns";
		}
		$access_time .= "\n$temp ns at CAS ".$cas[$#cas-1];
	}

	if (@cas >= 3 && spd_written(@$bytes[25..26])) {
		$temp = $bytes->[25] >> 2;
		if ($temp == 0) { $temp = "Undefined!"; }
		else {
			$temp += ($bytes->[25] & 0x3) * 0.25;
			$temp .= " ns";
		}
		$cycle_time .= "\n$temp ns at CAS ".$cas[$#cas-2];

		$temp = $bytes->[26] >> 2;
		if ($temp == 0) { $temp = "Undefined!"; }
		else {
			$temp += ($bytes->[26] & 0x3) * 0.25;
			$temp .= " ns";
		}
		$access_time .= "\n$temp ns at CAS ".$cas[$#cas-2];
	}

	printl_cond(defined $cycle_time, "Cycle Time", $cycle_time);
	printl_cond(defined $access_time, "Access Time", $access_time);

	$temp = "";
	if ($bytes->[21] & 1) { $temp .= "Buffered Address/Control Inputs\n"; }
	if ($bytes->[21] & 2) { $temp .= "Registered Address/Control Inputs\n"; }
	if ($bytes->[21] & 4) { $temp .= "On card PLL (clock)\n"; }
	if ($bytes->[21] & 8) { $temp .= "Buffered DQMB Inputs\n"; }
	if ($bytes->[21] & 16) { $temp .= "Registered DQMB Inputs\n"; }
	if ($bytes->[21] & 32) { $temp .= "Differential Clock Input\n"; }
	if ($bytes->[21] & 64) { $temp .= "Redundant Row Address\n"; }
	if ($bytes->[21] & 128) { $temp .= "Undefined (bit 7)\n"; }
	if ($bytes->[21] == 0) { $temp .= "(None Reported)\n"; }
	printl("SDRAM Module Attributes", $temp);

	$temp = "";
	if ($bytes->[22] & 1) { $temp .= "Supports Early RAS# Recharge\n"; }
	if ($bytes->[22] & 2) { $temp .= "Supports Auto-Precharge\n"; }
	if ($bytes->[22] & 4) { $temp .= "Supports Precharge All\n"; }
	if ($bytes->[22] & 8) { $temp .= "Supports Write1/Read Burst\n"; }
	if ($bytes->[22] & 16) { $temp .= "Lower VCC Tolerance: 5%\n"; }
	else { $temp .= "Lower VCC Tolerance: 10%\n"; }
	if ($bytes->[22] & 32) { $temp .= "Upper VCC Tolerance: 5%\n"; }
	else { $temp .= "Upper VCC Tolerance: 10%\n"; }
	if ($bytes->[22] & 64) { $temp .= "Undefined (bit 6)\n"; }
	if ($bytes->[22] & 128) { $temp .= "Undefined (bit 7)\n"; }
	printl("SDRAM Device Attributes (General)", $temp);

	printl("Minimum Row Precharge Time",
	       value_or_undefined($bytes->[27], "ns"));

	printl("Row Active to Row Active Min",
	       value_or_undefined($bytes->[28], "ns"));

	printl("RAS to CAS Delay",
	       value_or_undefined($bytes->[29], "ns"));

	printl("Min RAS Pulse Width",
	       value_or_undefined($bytes->[30], "ns"));

	$temp = "";
	if ($bytes->[31] & 1) { $temp .= "4 MByte\n"; }
	if ($bytes->[31] & 2) { $temp .= "8 MByte\n"; }
	if ($bytes->[31] & 4) { $temp .= "16 MByte\n"; }
	if ($bytes->[31] & 8) { $temp .= "32 MByte\n"; }
	if ($bytes->[31] & 16) { $temp .= "64 MByte\n"; }
	if ($bytes->[31] & 32) { $temp .= "128 MByte\n"; }
	if ($bytes->[31] & 64) { $temp .= "256 MByte\n"; }
	if ($bytes->[31] & 128) { $temp .= "512 MByte\n"; }
	if ($bytes->[31] == 0) { $temp .= "(Undefined! -- None Reported!)\n"; }
	printl("Row Densities", $temp);

	$temp = (($bytes->[32] & 0x7f) >> 4) + ($bytes->[32] & 0xf) * 0.1;
	printl_cond(($bytes->[32] & 0xf) <= 9,
		    "Command and Address Signal Setup Time",
		    (($bytes->[32] >> 7) ? -$temp : $temp) . " ns");

	$temp = (($bytes->[33] & 0x7f) >> 4) + ($bytes->[33] & 0xf) * 0.1;
	printl_cond(($bytes->[33] & 0xf) <= 9,
		    "Command and Address Signal Hold Time",
		    (($bytes->[33] >> 7) ? -$temp : $temp) . " ns");

	$temp = (($bytes->[34] & 0x7f) >> 4) + ($bytes->[34] & 0xf) * 0.1;
	printl_cond(($bytes->[34] & 0xf) <= 9, "Data Signal Setup Time",
		    (($bytes->[34] >> 7) ? -$temp : $temp) . " ns");

	$temp = (($bytes->[35] & 0x7f) >> 4) + ($bytes->[35] & 0xf) * 0.1;
	printl_cond(($bytes->[35] & 0xf) <= 9, "Data Signal Hold Time",
		    (($bytes->[35] >> 7) ? -$temp : $temp) . " ns");
}

# Parameter: EEPROM bytes 0-127 (using 3-62)
sub decode_ddr_sdram($)
{
	my $bytes = shift;
	my $temp;

# SPD revision
	printl_cond($bytes->[62] != 0xff, "SPD Revision",
		    ($bytes->[62] >> 4) . "." . ($bytes->[62] & 0xf));

# speed
	prints("Memory Characteristics");

	$temp = ($bytes->[9] >> 4) + ($bytes->[9] & 0xf) * 0.1;
	my $ddrclk = 2 * (1000 / $temp);
	my $tbits = ($bytes->[7] * 256) + $bytes->[6];
	if (($bytes->[11] == 2) || ($bytes->[11] == 1)) { $tbits = $tbits - 8; }
	my $pcclk = int ($ddrclk * $tbits / 8);
	$pcclk += 100 if ($pcclk % 100) >= 50; # Round properly
	$pcclk = $pcclk - ($pcclk % 100);
	$ddrclk = int ($ddrclk);
	printl("Maximum module speed", "${ddrclk}MHz (PC${pcclk})");

#size computation
	my $k = 0;
	my $ii = 0;

	$ii = ($bytes->[3] & 0x0f) + ($bytes->[4] & 0x0f) - 17;
	if (($bytes->[5] <= 8) && ($bytes->[17] <= 8)) {
		 $k = $bytes->[5] * $bytes->[17];
	}

	if ($ii > 0 && $ii <= 12 && $k > 0) {
		printl("Size", ((1 << $ii) * $k) . " MB");
	} else {
		printl("Size", "INVALID: " . $bytes->[3] . ", " . $bytes->[4] . ", " .
			       $bytes->[5] . ", " . $bytes->[17]);
	}

	printl("Voltage Interface Level",
	       sdram_voltage_interface_level($bytes->[8]));

	printl("Module Configuration Type",
	       sdram_module_configuration_type($bytes->[11]));

	printl("Refresh Rate", ddr2_refresh_rate($bytes->[12]));

	my $highestCAS = 0;
	my %cas;
	for ($ii = 0; $ii < 7; $ii++) {
		if ($bytes->[18] & (1 << $ii)) {
			$highestCAS = 1+$ii*0.5;
			$cas{$highestCAS}++;
		}
	}

	my $trcd;
	my $trp;
	my $tras;
	my $ctime = ($bytes->[9] >> 4) + ($bytes->[9] & 0xf) * 0.1;

	$trcd = ($bytes->[29] >> 2) + (($bytes->[29] & 3) * 0.25);
	$trp = ($bytes->[27] >> 2) + (($bytes->[27] & 3) * 0.25);
	$tras = $bytes->[30];

	printl("tCL-tRCD-tRP-tRAS",
		$highestCAS . "-" .
		ceil($trcd/$ctime) . "-" .
		ceil($trp/$ctime) . "-" .
		ceil($tras/$ctime));

# latencies
	printl("Supported CAS Latencies", cas_latencies(keys %cas));

	my @array;
	for ($ii = 0; $ii < 7; $ii++) {
		push(@array, $ii) if ($bytes->[19] & (1 << $ii));
	}
	if (@array) { $temp = join ', ', @array; }
	else { $temp = "None"; }
	printl("Supported CS Latencies", $temp);

	@array = ();
	for ($ii = 0; $ii < 7; $ii++) {
		push(@array, $ii) if ($bytes->[20] & (1 << $ii));
	}
	if (@array) { $temp = join ', ', @array; }
	else { $temp = "None"; }
	printl("Supported WE Latencies", $temp);

# timings
	my ($cycle_time, $access_time);

	if (exists $cas{$highestCAS}) {
		$cycle_time = "$ctime ns at CAS $highestCAS";
		$access_time = (($bytes->[10] >> 4) * 0.1 + ($bytes->[10] & 0xf) * 0.01)
			     . " ns at CAS $highestCAS";
	}

	if (exists $cas{$highestCAS-0.5} && spd_written(@$bytes[23..24])) {
		$cycle_time .= "\n".(($bytes->[23] >> 4) + ($bytes->[23] & 0xf) * 0.1)
			     . " ns at CAS ".($highestCAS-0.5);
		$access_time .= "\n".(($bytes->[24] >> 4) * 0.1 + ($bytes->[24] & 0xf) * 0.01)
			      . " ns at CAS ".($highestCAS-0.5);
	}

	if (exists $cas{$highestCAS-1} && spd_written(@$bytes[25..26])) {
		$cycle_time .= "\n".(($bytes->[25] >> 4) + ($bytes->[25] & 0xf) * 0.1)
			     . " ns at CAS ".($highestCAS-1);
		$access_time .= "\n".(($bytes->[26] >> 4) * 0.1 + ($bytes->[26] & 0xf) * 0.01)
			      . " ns at CAS ".($highestCAS-1);
	}

	printl_cond(defined $cycle_time, "Minimum Cycle Time", $cycle_time);
	printl_cond(defined $access_time, "Maximum Access Time", $access_time);

# module attributes
	if ($bytes->[47] & 0x03) {
		if (($bytes->[47] & 0x03) == 0x01) { $temp = "1.125\" to 1.25\""; }
		elsif (($bytes->[47] & 0x03) == 0x02) { $temp = "1.7\""; }
		elsif (($bytes->[47] & 0x03) == 0x03) { $temp = "Other"; }
		printl("Module Height", $temp);
	}
}

sub ddr2_sdram_ctime($)
{
	my $byte = shift;
	my $ctime;

	$ctime = $byte >> 4;
	if (($byte & 0xf) <= 9) { $ctime += ($byte & 0xf) * 0.1; }
	elsif (($byte & 0xf) == 10) { $ctime += 0.25; }
	elsif (($byte & 0xf) == 11) { $ctime += 0.33; }
	elsif (($byte & 0xf) == 12) { $ctime += 0.66; }
	elsif (($byte & 0xf) == 13) { $ctime += 0.75; }

	return $ctime;
}

sub ddr2_sdram_atime($)
{
	my $byte = shift;
	my $atime;

	$atime = ($byte >> 4) * 0.1 + ($byte & 0xf) * 0.01;

	return $atime;
}

# Base, high-bit, 3-bit fraction code
sub ddr2_sdram_rtime($$$)
{
	my ($rtime, $msb, $ext) = @_;
	my @table = (0, .25, .33, .50, .66, .75);

	return $rtime + $msb * 256 + $table[$ext];
}

sub ddr2_module_types($)
{
	my $byte = shift;
	my @types = qw(RDIMM UDIMM SO-DIMM Micro-DIMM Mini-RDIMM Mini-UDIMM);
	my @widths = (133.35, 133.25, 67.6, 45.5, 82.0, 82.0);
	my @suptypes;
	local $_;

	foreach (0..5) {
		push @suptypes, "$types[$_] ($widths[$_] mm)"
			if ($byte & (1 << $_));
	}

	return @suptypes;
}

# Common to SDR, DDR and DDR2 SDRAM
sub ddr2_refresh_rate($)
{
	my $byte = shift;
	my @refresh = qw(Normal Reduced Reduced Extended Extended Extended);
	my @refresht = (15.625, 3.9, 7.8, 31.3, 62.5, 125);

	return "$refresh[$byte & 0x7f] ($refresht[$byte & 0x7f] us)".
	       ($byte & 0x80 ? " - Self Refresh" : "");
}

# Parameter: EEPROM bytes 0-127 (using 3-62)
sub decode_ddr2_sdram($)
{
	my $bytes = shift;
	my $temp;
	my $ctime;

# SPD revision
	if ($bytes->[62] != 0xff) {
		printl("SPD Revision", ($bytes->[62] >> 4) . "." .
				       ($bytes->[62] & 0xf));
	}

# speed
	prints("Memory Characteristics");

	$ctime = ddr2_sdram_ctime($bytes->[9]);
	my $ddrclk = 2 * (1000 / $ctime);
	my $tbits = ($bytes->[7] * 256) + $bytes->[6];
	if ($bytes->[11] & 0x03) { $tbits = $tbits - 8; }
	my $pcclk = int ($ddrclk * $tbits / 8);
	# Round down to comply with Jedec
	$pcclk = $pcclk - ($pcclk % 100);
	$ddrclk = int ($ddrclk);
	printl("Maximum module speed", "${ddrclk}MHz (PC2-${pcclk})");

#size computation
	my $k = 0;
	my $ii = 0;

	$ii = ($bytes->[3] & 0x0f) + ($bytes->[4] & 0x0f) - 17;
	$k = (($bytes->[5] & 0x7) + 1) * $bytes->[17];

	if($ii > 0 && $ii <= 12 && $k > 0) {
		printl("Size", ((1 << $ii) * $k) . " MB");
	} else {
		printl("Size", "INVALID: " . $bytes->[3] . "," . $bytes->[4] . "," .
			       $bytes->[5] . "," . $bytes->[17]);
	}

	printl("Banks x Rows x Columns x Bits",
	       join(' x ', $bytes->[17], $bytes->[3], $bytes->[4], $bytes->[6]));
	printl("Ranks", ($bytes->[5] & 7) + 1);

	printl("SDRAM Device Width", $bytes->[13]." bits");

	my @heights = ('< 25.4', '25.4', '25.4 - 30.0', '30.0', '30.5', '> 30.5');
	printl("Module Height", $heights[$bytes->[5] >> 5]." mm");

	my @suptypes = ddr2_module_types($bytes->[20]);
	printl("Module Type".(@suptypes > 1 ? 's' : ''), join(', ', @suptypes));

	printl("DRAM Package", $bytes->[5] & 0x10 ? "Stack" : "Planar");

	printl("Voltage Interface Level",
	       sdram_voltage_interface_level($bytes->[8]));

	printl("Refresh Rate", ddr2_refresh_rate($bytes->[12]));

	my @burst;
	push @burst, 4 if ($bytes->[16] & 4);
	push @burst, 8 if ($bytes->[16] & 8);
	$burst[0] = 'None' if !@burst;
	printl("Supported Burst Lengths", join(', ', @burst));

	my $highestCAS = 0;
	my %cas;
	for ($ii = 2; $ii < 7; $ii++) {
		if ($bytes->[18] & (1 << $ii)) {
			$highestCAS = $ii;
			$cas{$highestCAS}++;
		}
	}

	my $trcd;
	my $trp;
	my $tras;

	$trcd = ($bytes->[29] >> 2) + (($bytes->[29] & 3) * 0.25);
	$trp = ($bytes->[27] >> 2) + (($bytes->[27] & 3) * 0.25);
	$tras = $bytes->[30];

	printl("tCL-tRCD-tRP-tRAS",
		$highestCAS . "-" .
		ceil($trcd/$ctime) . "-" .
		ceil($trp/$ctime) . "-" .
		ceil($tras/$ctime));

# latencies
	printl("Supported CAS Latencies (tCL)", cas_latencies(keys %cas));

# timings
	my ($cycle_time, $access_time);

	if (exists $cas{$highestCAS}) {
		$cycle_time = tns($ctime) . " at CAS $highestCAS (tCK min)";
		$access_time = tns(ddr2_sdram_atime($bytes->[10]))
			     . " at CAS $highestCAS (tAC)";
	}

	if (exists $cas{$highestCAS-1} && spd_written(@$bytes[23..24])) {
		$cycle_time .= "\n".tns(ddr2_sdram_ctime($bytes->[23]))
			     . " at CAS ".($highestCAS-1);
		$access_time .= "\n".tns(ddr2_sdram_atime($bytes->[24]))
			      . " at CAS ".($highestCAS-1);
	}

	if (exists $cas{$highestCAS-2} && spd_written(@$bytes[25..26])) {
		$cycle_time .= "\n".tns(ddr2_sdram_ctime($bytes->[25]))
			     . " at CAS ".($highestCAS-2);
		$access_time .= "\n".tns(ddr2_sdram_atime($bytes->[26]))
			      . " at CAS ".($highestCAS-2);
	}

	printl_cond(defined $cycle_time, "Minimum Cycle Time", $cycle_time);
	printl_cond(defined $access_time, "Maximum Access Time", $access_time);

	printl("Maximum Cycle Time (tCK max)",
	       tns(ddr2_sdram_ctime($bytes->[43])));

# more timing information
	prints("Timing Parameters");
	printl("Address/Command Setup Time Before Clock (tIS)",
	       tns(ddr2_sdram_atime($bytes->[32])));
	printl("Address/Command Hold Time After Clock (tIH)",
	       tns(ddr2_sdram_atime($bytes->[33])));
	printl("Data Input Setup Time Before Strobe (tDS)",
	       tns(ddr2_sdram_atime($bytes->[34])));
	printl("Data Input Hold Time After Strobe (tDH)",
	       tns(ddr2_sdram_atime($bytes->[35])));
	printl("Minimum Row Precharge Delay (tRP)", tns($trp));
	printl("Minimum Row Active to Row Active Delay (tRRD)",
	       tns($bytes->[28]/4));
	printl("Minimum RAS# to CAS# Delay (tRCD)", tns($trcd));
	printl("Minimum RAS# Pulse Width (tRAS)", tns($tras));
	printl("Write Recovery Time (tWR)", tns($bytes->[36]/4));
	printl("Minimum Write to Read CMD Delay (tWTR)", tns($bytes->[37]/4));
	printl("Minimum Read to Pre-charge CMD Delay (tRTP)", tns($bytes->[38]/4));
	printl("Minimum Active to Auto-refresh Delay (tRC)",
	       tns(ddr2_sdram_rtime($bytes->[41], 0, ($bytes->[40] >> 4) & 7)));
	printl("Minimum Recovery Delay (tRFC)",
	       tns(ddr2_sdram_rtime($bytes->[42], $bytes->[40] & 1,
				    ($bytes->[40] >> 1) & 7)));
	printl("Maximum DQS to DQ Skew (tDQSQ)", tns($bytes->[44]/100));
	printl("Maximum Read Data Hold Skew (tQHS)", tns($bytes->[45]/100));
	printl("PLL Relock Time", $bytes->[46] . " us") if ($bytes->[46]);
}

# Parameter: EEPROM bytes 0-127 (using 3-76)
sub decode_ddr3_sdram($)
{
	my $bytes = shift;
	my $temp;
	my $ctime;

	my @module_types = ("Undefined", "RDIMM", "UDIMM", "SO-DIMM",
			    "Micro-DIMM", "Mini-RDIMM", "Mini-UDIMM");

	printl("Module Type", ($bytes->[3] <= $#module_types) ?
					$module_types[$bytes->[3]] :
					sprint("Reserved (0x%.2X)", $bytes->[3]));

# speed
	prints("Memory Characteristics");

	my $dividend = ($bytes->[9] >> 4) & 15;
	my $divisor  = $bytes->[9] & 15;
	printl("Fine time base", sprintf("%.3f", $dividend / $divisor) . " ps");

	$dividend = $bytes->[10];
	$divisor  = $bytes->[11];
	my $mtb = $dividend / $divisor;
	printl("Medium time base", tns3($mtb));

	$ctime = $bytes->[12] * $mtb;
	my $ddrclk = 2 * (1000 / $ctime);
	my $tbits = 1 << (($bytes->[8] & 7) + 3);
	my $pcclk = int ($ddrclk * $tbits / 8);
	$ddrclk = int ($ddrclk);
	printl("Maximum module speed", "${ddrclk}MHz (PC3-${pcclk})");

# Size computation

	my $cap =  ($bytes->[4]       & 15) + 28;
	$cap   +=  ($bytes->[8]       & 7)  + 3;
	$cap   -=  ($bytes->[7]       & 7)  + 2;
	$cap   -= 20 + 3;
	my $k   = (($bytes->[7] >> 3) & 31) + 1;
	printl("Size", ((1 << $cap) * $k) . " MB");

	printl("Banks x Rows x Columns x Bits",
	       join(' x ', 1 << ((($bytes->[4] >> 4) &  7) +  3),
			   ((($bytes->[5] >> 3) & 31) + 12),
			   ( ($bytes->[5]       &  7) +  9),
			   ( 1 << (($bytes->[8] &  7) + 3)) ));
	printl("Ranks", $k);

	printl("SDRAM Device Width", (1 << (($bytes->[7] & 7) + 2))." bits");

	my $taa;
	my $trcd;
	my $trp;
	my $tras;

	$taa  = int($bytes->[16] / $bytes->[12]);
	$trcd = int($bytes->[18] / $bytes->[12]);
	$trp  = int($bytes->[20] / $bytes->[12]);
	$tras = int((($bytes->[21] >> 4) * 256 + $bytes->[22]) / $bytes->[12]);

	printl("tCL-tRCD-tRP-tRAS", join("-", $taa, $trcd, $trp, $tras));

# latencies
	my $highestCAS = 0;
	my %cas;
	my $ii;
	my $cas_sup = ($bytes->[15] << 8) + $bytes->[14];
	for ($ii = 0; $ii < 15; $ii++) {
		if ($cas_sup & (1 << $ii)) {
			$highestCAS = $ii + 4;
			$cas{$highestCAS}++;
		}
	}
	printl("Supported CAS Latencies (tCL)", cas_latencies(keys %cas));

# more timing information
	prints("Timing Parameters");

	printl("Minimum Write Recovery time (tWR)", tns3($bytes->[17] * $mtb));
	printl("Minimum Row Active to Row Active Delay (tRRD)",
		tns3($bytes->[19] * $mtb));
	printl("Minimum Active to Auto-Refresh Delay (tRC)",
		tns3((((($bytes->[21] >> 4) & 15) << 8) + $bytes->[23]) * $mtb));
	printl("Minimum Recovery Delay (tRFC)",
		tns3((($bytes->[25] << 8) + $bytes->[24]) * $mtb));
	printl("Minimum Write to Read CMD Delay (tWTR)",
		tns3($bytes->[26] * $mtb));
	printl("Minimum Read to Pre-charge CMD Delay (tRTP)",
		tns3($bytes->[27] * $mtb));
	printl("Minimum Four Activate Window Delay (tFAW)",
		tns3(((($bytes->[28] & 15) << 8) + $bytes->[29]) * $mtb));

# miscellaneous stuff
	prints("Optional Features");

	my $volts = "1.5V";
	if ($bytes->[6] & 1) {
		$volts .= " tolerant";
	}
	if ($bytes->[6] & 2) {
		$volts .= ", 1.35V ";
	}
	if ($bytes->[6] & 4) {
		$volts .= ", 1.2X V";
	}
	printl("Operable voltages", $volts);
	printl("RZQ/6 supported?", ($bytes->[30] & 1) ? "Yes" : "No");
	printl("RZQ/7 supported?", ($bytes->[30] & 2) ? "Yes" : "No");
	printl("DLL-Off Mode supported?", ($bytes->[30] & 128) ? "Yes" : "No");
	printl("Operating temperature range", sprintf "0-%dC",
		($bytes->[31] & 1) ? 95 : 85);
	printl("Refresh Rate in extended temp range",
		($bytes->[31] & 2) ? "2X" : "1X");
	printl("Auto Self-Refresh?", ($bytes->[31] & 4) ? "Yes" : "No");
	printl("On-Die Thermal Sensor readout?",
		($bytes->[31] & 8) ? "Yes" : "No");
	printl("Partial Array Self-Refresh?",
		($bytes->[31] & 128) ? "Yes" : "No");
	printl("Thermal Sensor Accuracy",
		($bytes->[32] & 128) ? sprintf($bytes->[32] & 127) :
					"Not implemented");
	printl("SDRAM Device Type",
		($bytes->[33] & 128) ? sprintf($bytes->[33] & 127) :
					"Standard Monolithic");
	if ($bytes->[3] >= 1 && $bytes->[3] <= 6) {

		prints("Physical Characteristics");
		printl("Module Height (mm)", ($bytes->[60] & 31) + 15);
		printl("Module Thickness (mm)", sprintf("%d front, %d back",
						($bytes->[61] & 15) + 1,
						(($bytes->[61] >> 4) & 15) +1));
		printl("Module Width (mm)", ($bytes->[3] <= 2) ? 133.5 :
					($bytes->[3] == 3) ? 67.6 : "TBD");

		my $alphabet = "ABCDEFGHJKLMNPRTUVWY";
		my $ref = $bytes->[62] & 31;
		my $ref_card;
		if ($ref == 31) {
			$ref_card = "ZZ";
		} else {
			if ($bytes->[62] & 128) {
				$ref += 31;
			}
			if ($ref < length $alphabet) {
				$ref_card = substr $alphabet, $ref, 1;
			} else {
				my $ref1 = int($ref / (length $alphabet));
				$ref -= (length $alphabet) * $ref1;
				$ref_card = (substr $alphabet, $ref1, 1) .
					    (substr $alphabet, $ref, 1);
			}
		}
		printl("Module Reference Card", $ref_card);
	}
	if ($bytes->[3] == 1 || $bytes->[3] == 5) {
		prints("Registered DIMM");

		my @rows = ("Undefined", 1, 2, 4);
		printl("# DRAM Rows", $rows[($bytes->[63] >> 2) & 3]);
		printl("# Registers", $rows[$bytes->[63] & 3]);
		printl("Register manufacturer",
			manufacturer_ddr3($bytes->[65], $bytes->[66]));
		printl("Register device type",
				(($bytes->[68] & 7) == 0) ? "SSTE32882" :
					"Undefined");
		printl("Register revision", sprintf("0x%.2X", $bytes->[67]));
		printl("Heat spreader characteristics",
				($bytes->[64] < 128) ? "Not incorporated" :
					sprintf("%.2X", ($bytes->[64] & 127)));
		my $regs;
		for (my $i = 0; $i < 8; $i++) {
			$regs = sprintf("SSTE32882 RC%d/RC%d",
					$i * 2, $i * 2 + 1);
			printl($regs, sprintf("%.2X", $bytes->[$i + 69]));
		}
	}
}

# Parameter: EEPROM bytes 0-127 (using 4-5)
sub decode_direct_rambus($)
{
	my $bytes = shift;

#size computation
	prints("Memory Characteristics");

	my $ii;

	$ii = ($bytes->[4] & 0x0f) + ($bytes->[4] >> 4) + ($bytes->[5] & 0x07) - 13;

	if ($ii > 0 && $ii < 16) {
		printl("Size", (1 << $ii) . " MB");
	} else {
		printl("Size", sprintf("INVALID: 0x%02x, 0x%02x",
				       $bytes->[4], $bytes->[5]));
	}
}

# Parameter: EEPROM bytes 0-127 (using 3-5)
sub decode_rambus($)
{
	my $bytes = shift;

#size computation
	prints("Memory Characteristics");

	my $ii;

	$ii = ($bytes->[3] & 0x0f) + ($bytes->[3] >> 4) + ($bytes->[5] & 0x07) - 13;

	if ($ii > 0 && $ii < 16) {
		printl("Size", (1 << $ii) . " MB");
	} else {
		printl("Size", "INVALID: " . sprintf("0x%02x, 0x%02x",
					       $bytes->[3], $bytes->[5]));
	}
}

%decode_callback = (
	"SDR SDRAM"	=> \&decode_sdr_sdram,
	"DDR SDRAM"	=> \&decode_ddr_sdram,
	"DDR2 SDRAM"	=> \&decode_ddr2_sdram,
	"DDR3 SDRAM"	=> \&decode_ddr3_sdram,
	"Direct Rambus"	=> \&decode_direct_rambus,
	"Rambus"	=> \&decode_rambus,
);

# Parameter: Manufacturing year/week bytes
sub manufacture_date($$)
{
	my ($year, $week) = @_;

	# In theory the year and week are in BCD format, but
	# this is not always true in practice :(
	if (($year & 0xf0) <= 0x90 && ($year & 0x0f) <= 0x09
	 && ($week & 0xf0) <= 0x90 && ($week & 0x0f) <= 0x09) {
		# Note that this heuristic will break in year 2080
		return sprintf("%d%02X-W%02X",
				$year >= 0x80 ? 19 : 20, $year, $week);
	# Fallback to binary format if it seems to make sense
	} elsif ($year <= 99 && $week >= 1 && $week <= 53) {
		return sprintf("%d%02d-W%02d",
				$year >= 80 ? 19 : 20, $year, $week);
	} else {
		return sprintf("0x%02X%02X", $year, $week);
	}
}

sub printl_mfg_location_code($)
{
	my $code = shift;
	my $letter = chr($code);

	# Try the location code as ASCII first, as earlier specifications
	# suggested this. As newer specifications don't mention it anymore,
	# we still fall back to binary.
	printl_cond(spd_written($code), "Manufacturing Location Code",
		    $letter =~ m/^[\w\d]$/ ? $letter : sprintf("0x%.2X", $code));
}

sub printl_mfg_assembly_serial(@)
{
	printl_cond(spd_written(@_), "Assembly Serial Number",
		    sprintf("0x%02X%02X%02X%02X", @_));
}

# Parameter: EEPROM bytes 0-175 (using 117-149)
sub decode_ddr3_mfg_data($)
{
	my $bytes = shift;

	prints("Manufacturer Data");

	printl("Module Manufacturer",
	       manufacturer_ddr3($bytes->[117], $bytes->[118]));

	if (spd_written(@{$bytes}[148..149])) {
		printl("DRAM Manufacturer",
		       manufacturer_ddr3($bytes->[148], $bytes->[149]));
	}

	printl_mfg_location_code($bytes->[119]);

	if (spd_written(@{$bytes}[120..121])) {
		printl("Manufacturing Date",
		       manufacture_date($bytes->[120], $bytes->[121]));
	}

	printl_mfg_assembly_serial(@{$bytes}[122..125]);

	printl("Part Number", part_number(@{$bytes}[128..145]));

	if (spd_written(@{$bytes}[146..147])) {
		printl("Revision Code",
		       sprintf("0x%02X%02X", $bytes->[146], $bytes->[147]));
	}
}

# Parameter: EEPROM bytes 0-127 (using 64-98)
sub decode_manufacturing_information($)
{
	my $bytes = shift;
	my ($temp, $extra);

	prints("Manufacturing Information");

	# $extra is a reference to an array containing up to
	# 7 extra bytes from the Manufacturer field. Sometimes
	# these bytes are filled with interesting data.
	($temp, $extra) = manufacturer(@{$bytes}[64..71]);
	printl("Manufacturer", $temp);
	$temp = manufacturer_data(@{$extra});
	printl_cond(defined $temp, "Custom Manufacturer Data", $temp);

	printl_mfg_location_code($bytes->[72]);

	printl("Part Number", part_number(@{$bytes}[73..90]));

	printl_cond(spd_written(@{$bytes}[91..92]), "Revision Code",
		    sprintf("0x%02X%02X", @{$bytes}[91..92]));

	printl_cond(spd_written(@{$bytes}[93..94]), "Manufacturing Date",
	       manufacture_date($bytes->[93], $bytes->[94]));

	printl_mfg_assembly_serial(@{$bytes}[95..98]);
}

# Parameter: EEPROM bytes 0-127 (using 126-127)
sub decode_intel_spec_freq($)
{
	my $bytes = shift;
	my $temp;

	prints("Intel Specification");

	if ($bytes->[126] == 0x66) { $temp = "66MHz"; }
	elsif ($bytes->[126] == 100) { $temp = "100MHz or 133MHz"; }
	elsif ($bytes->[126] == 133) { $temp = "133MHz"; }
	else { $temp = "Undefined!"; }
	printl("Frequency", $temp);

	$temp = "";
	if ($bytes->[127] & 1) { $temp .= "Intel Concurrent Auto-precharge\n"; }
	if ($bytes->[127] & 2) { $temp .= "CAS Latency = 2\n"; }
	if ($bytes->[127] & 4) { $temp .= "CAS Latency = 3\n"; }
	if ($bytes->[127] & 8) { $temp .= "Junction Temp A (100 degrees C)\n"; }
	else { $temp .= "Junction Temp B (90 degrees C)\n"; }
	if ($bytes->[127] & 16) { $temp .= "CLK 3 Connected\n"; }
	if ($bytes->[127] & 32) { $temp .= "CLK 2 Connected\n"; }
	if ($bytes->[127] & 64) { $temp .= "CLK 1 Connected\n"; }
	if ($bytes->[127] & 128) { $temp .= "CLK 0 Connected\n"; }
	if (($bytes->[127] & 192) == 192) { $temp .= "Double-sided DIMM\n"; }
	elsif (($bytes->[127] & 192) != 0) { $temp .= "Single-sided DIMM\n"; }
	printl("Details for 100MHz Support", $temp);
}

# Read various hex dump style formats: hexdump, hexdump -C, i2cdump, eeprog
# note that normal 'hexdump' format on a little-endian system byte-swaps
# words, using hexdump -C is better.
sub read_hexdump($)
{
	my $addr = 0;
	my $repstart = 0;
	my @bytes;
	my $header = 1;
	my $word = 0;

	# Look in the cache first
	return @{$hexdump_cache{$_[0]}} if exists $hexdump_cache{$_[0]};

	open F, '<', $_[0] or die "Unable to open: $_[0]";
	while (<F>) {
		chomp;
		if (/^\*$/) {
			$repstart = $addr;
			next;
		}
		/^(?:0000 )?([a-f\d]{2,8}):?\s+((:?[a-f\d]{4}\s*){8}|(:?[a-f\d]{2}\s*){16})/i ||
		/^(?:0000 )?([a-f\d]{2,8}):?\s*$/i;
		next if (!defined $1 && $header);		# skip leading unparsed lines

		defined $1 or die "Unable to parse input";
		$header = 0;

		$addr = hex $1;
		if ($repstart) {
			@bytes[$repstart .. ($addr-1)] =
				(@bytes[($repstart-16)..($repstart-1)]) x (($addr-$repstart)/16);
			$repstart = 0;
		}
		last unless defined $2;
		foreach (split(/\s+/, $2)) {
			if (/^(..)(..)$/) {
			        $word |= 1;
				if ($use_hexdump eq LITTLEENDIAN) {
					$bytes[$addr++] = hex($2);
					$bytes[$addr++] = hex($1);
				} else {
					$bytes[$addr++] = hex($1);
					$bytes[$addr++] = hex($2);
				}
			} else {
				$bytes[$addr++] = hex($_);
			}
		}
	}
	close F;
	$header and die "Unable to parse any data from hexdump '$_[0]'";
	$word and printc("Using $use_hexdump 16-bit hex dump");

	# Cache the data for later use
	$hexdump_cache{$_[0]} = \@bytes;
	return @bytes;
}

# Returns the (total, used) number of bytes in the EEPROM,
# assuming it is a non-Rambus SPD EEPROM.
sub spd_sizes($)
{
	my $bytes = shift;

	if ($bytes->[2] >= 9) {
		# For FB-DIMM and newer, decode number of bytes written
		my $spd_len = ($bytes->[0] >> 4) & 7;
		my $size = 64 << ($bytes->[0] & 15);
		if ($spd_len == 0) {
			return ($size, 128);
		} elsif ($spd_len == 1) {
			return ($size, 176);
		} elsif ($spd_len == 2) {
			return ($size, 256);
		} else {
			return (64, 64);
		}
	} else {
		my $size;
		if ($bytes->[1] <= 14) {
			$size = 1 << $bytes->[1];
		} elsif ($bytes->[1] == 0) {
			$size = "RFU";
		} else { $size = "ERROR!" }

		return ($size, ($bytes->[0] < 64) ? 64 : $bytes->[0]);
	}
}

# Read bytes from SPD-EEPROM
# Note: offset must be a multiple of 16!
sub readspd($$$)
{
	my ($offset, $size, $dimm_i) = @_;
	my @bytes;
	if ($use_hexdump) {
		@bytes = read_hexdump($dimm_i);
		return @bytes[$offset..($offset + $size - 1)];
	} elsif ($use_sysfs) {
		# Kernel 2.6 with sysfs
		sysopen(HANDLE, "$dimm_i/eeprom", O_RDONLY)
			or die "Cannot open $dimm_i/eeprom";
		binmode HANDLE;
		sysseek(HANDLE, $offset, SEEK_SET)
			or die "Cannot seek $dimm_i/eeprom";
		sysread(HANDLE, my $eeprom, $size)
			or die "Cannot read $dimm_i/eeprom";
		close HANDLE;
		@bytes = unpack("C*", $eeprom);
	} else {
		# Kernel 2.4 with procfs
		for my $i (0 .. ($size-1)/16) {
			my $hexoff = sprintf('%02x', $offset + $i * 16);
			push @bytes, split(" ", `cat $dimm_i/$hexoff`);
		}
	}
	return @bytes;
}

# Calculate and verify checksum of first 63 bytes
sub checksum($)
{
	my $bytes = shift;
	my $dimm_checksum = 0;
	local $_;

	$dimm_checksum += $bytes->[$_] foreach (0 .. 62);
	$dimm_checksum &= 0xff;

	return ("EEPROM Checksum of bytes 0-62",
		($bytes->[63] == $dimm_checksum) ? 1 : 0,
		sprintf('0x%02X', $bytes->[63]),
		sprintf('0x%02X', $dimm_checksum));
}

# Calculate and verify CRC
sub check_crc($)
{
	my $bytes = shift;
	my $crc = 0;
	my $crc_cover = $bytes->[0] & 0x80 ? 116 : 125;
	my $crc_ptr = 0;
	my $crc_bit;

	while ($crc_ptr <= $crc_cover) {
		$crc = $crc ^ ($bytes->[$crc_ptr] << 8);
		for ($crc_bit = 0; $crc_bit < 8; $crc_bit++) {
			if ($crc & 0x8000) {
				$crc = ($crc << 1) ^ 0x1021;
			} else {
				$crc = $crc << 1
			}
		}
		$crc_ptr++;
	}
	$crc &= 0xffff;

	my $dimm_crc = ($bytes->[127] << 8) | $bytes->[126];
	return ("EEPROM CRC of bytes 0-$crc_cover",
		($dimm_crc == $crc) ? 1 : 0,
		sprintf("0x%04X", $dimm_crc),
		sprintf("0x%04X", $crc));
}

# Parse command-line
foreach (@ARGV) {
	if ($_ eq '-h' || $_ eq '--help') {
		print "Usage: $0 [-c] [-f [-b]] [-x|-X file [files..]]\n",
			"       $0 -h\n\n",
			"  -f, --format            Print nice html output\n",
			"  -b, --bodyonly          Don't print html header\n",
			"                          (useful for postprocessing the output)\n",
			"      --side-by-side      Display all DIMMs side-by-side if possible\n",
			"      --merge-cells       Merge neighbour cells with identical values\n",
			"                          (side-by-side output only)\n",
			"  -c, --checksum          Decode completely even if checksum fails\n",
			"  -x,                     Read data from hexdump files\n",
			"  -X,                     Same as -x except treat multibyte hex\n",
			"                          data as little endian\n",
			"  -h, --help              Display this usage summary\n";
		print <<"EOF";

Hexdumps can be the output from hexdump, hexdump -C, i2cdump, eeprog and
likely many other progams producing hex dumps of one kind or another.  Note
that the default output of "hexdump" will be byte-swapped on little-endian
systems and you must use -X instead of -x, otherwise the dump will not be
parsed correctly.  It is better to use "hexdump -C", which is not ambiguous.
EOF
		exit;
	}

	if ($_ eq '-f' || $_ eq '--format') {
		$opt_html = 1;
		next;
	}
	if ($_ eq '-b' || $_ eq '--bodyonly') {
		$opt_bodyonly = 1;
		next;
	}
	if ($_ eq '--side-by-side') {
		$opt_side_by_side = 1;
		next;
	}
	if ($_ eq '--merge-cells') {
		$opt_merge = 1;
		next;
	}
	if ($_ eq '-c' || $_ eq '--checksum') {
		$opt_igncheck = 1;
		next;
	}
	if ($_ eq '-x') {
		$use_hexdump = BIGENDIAN;
		next;
	}
	if ($_ eq '-X') {
		$use_hexdump = LITTLEENDIAN;
		next;
	}

	if (m/^-/) {
		print STDERR "Unrecognized option $_\n";
		exit;
	}

	push @dimm, { eeprom => $_, file => $_ } if $use_hexdump;
}

if ($opt_html && !$opt_bodyonly) {
	print "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">\n",
	      "<html><head>\n",
		  "\t<meta HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">\n",
		  "\t<title>PC DIMM Serial Presence Detect Tester/Decoder Output</title>\n",
		  "</head><body>\n";
}

printc("decode-dimms version $revision");
printh('Memory Serial Presence Detect Decoder',
'By Philip Edelbrock, Christian Zuckschwerdt, Burkart Lingner,
Jean Delvare, Trent Piepho and others');


# From a sysfs device path and an attribute name, return the attribute
# value, or undef (stolen from sensors-detect)
sub sysfs_device_attribute
{
	my ($device, $attr) = @_;
	my $value;

	open(local *FILE, "$device/$attr") or return "";
	$value = <FILE>;
	close(FILE);
	return unless defined $value;

	chomp($value);
	return $value;
}

sub get_dimm_list
{
	my (@dirs, $dir, $file, @files);

	if ($use_sysfs) {
		@dirs = ('/sys/bus/i2c/drivers/eeprom', '/sys/bus/i2c/drivers/at24');
	} else {
		@dirs = ('/proc/sys/dev/sensors');
	}

	foreach $dir (@dirs) {
		next unless opendir(local *DIR, $dir);
		while (defined($file = readdir(DIR))) {
			if ($use_sysfs) {
				# We look for I2C devices like 0-0050 or 2-0051
				next unless $file =~ /^\d+-[\da-f]+$/i;
				next unless -d "$dir/$file";

				# Device name must be eeprom (driver eeprom)
				# or spd (driver at24)
				my $attr = sysfs_device_attribute("$dir/$file", "name");
				next unless defined $attr &&
					    ($attr eq "eeprom" || $attr eq "spd");
			} else {
				next unless $file =~ /^eeprom-/;
			}
			push @files, { eeprom => "$file",
				       file => "$dir/$file" };
		}
		close(DIR);
	}

	if (@files) {
		return sort { $a->{file} cmp $b->{file} } @files;
	} elsif (! -d '/sys/module/eeprom') {
		print "No EEPROM found, are you sure the eeprom module is loaded?\n";
		exit;
	}
}

# @dimm is a list of hashes. There's one hash for each EEPROM we found.
# Each hash has the following keys:
#  * eeprom: Name of the eeprom data file
#  * file: Full path to the eeprom data file
#  * bytes: The EEPROM data (array)
#  * is_rambus: Whether this is a RAMBUS DIMM or not (boolean)
#  * chk_label: The label to display for the checksum or CRC
#  * chk_valid: Whether the checksum or CRC is valid or not (boolean)
#  * chk_spd: The checksum or CRC value found in the EEPROM
#  * chk_calc: The checksum or CRC computed from the EEPROM data
# Keys are added over time.
@dimm = get_dimm_list() unless $use_hexdump;

for my $i (0 .. $#dimm) {
	my @bytes = readspd(0, 128, $dimm[$i]->{file});
	$dimm[$i]->{bytes} = \@bytes;
	$dimm[$i]->{is_rambus} = $bytes[0] < 4;		# Simple heuristic
	if ($dimm[$i]->{is_rambus} || $bytes[2] < 9) {
		($dimm[$i]->{chk_label}, $dimm[$i]->{chk_valid},
		 $dimm[$i]->{chk_spd}, $dimm[$i]->{chk_calc}) =
			checksum(\@bytes);
	} else {
		($dimm[$i]->{chk_label}, $dimm[$i]->{chk_valid},
		 $dimm[$i]->{chk_spd}, $dimm[$i]->{chk_calc}) =
			check_crc(\@bytes);
	}
}

# Checksum or CRC validation
if (!$opt_igncheck) {
	for (my $i = 0; $i < @dimm; ) {
		if ($dimm[$i]->{chk_valid}) {
			$i++;
		} else {
			splice(@dimm, $i, 1);
		}
	}
}

# Process the valid entries
for $current (0 .. $#dimm) {
	my @bytes = @{$dimm[$current]->{bytes}};

	if ($opt_side_by_side) {
		printl("Decoding EEPROM", $dimm[$current]->{eeprom});
	}

	if (!$use_hexdump) {
		if ($dimm[$current]->{file} =~ /-([\da-f]+)$/i) {
			my $dimm_num = hex($1) - 0x50 + 1;
			if ($dimm_num >= 1 && $dimm_num <= 8) {
				printl("Guessing DIMM is in", "bank $dimm_num");
			}
		}
	}

# Decode first 3 bytes (0-2)
	prints("SPD EEPROM Information");

	printl($dimm[$current]->{chk_label}, ($dimm[$current]->{chk_valid} ?
		sprintf("OK (%s)", $dimm[$current]->{chk_calc}) :
		sprintf("Bad\n(found %s, calculated %s)",
			$dimm[$current]->{chk_spd}, $dimm[$current]->{chk_calc})));

	my $temp;
	if ($dimm[$current]->{is_rambus}) {
		if ($bytes[0] == 1) { $temp = "0.7"; }
		elsif ($bytes[0] == 2) { $temp = "1.0"; }
		elsif ($bytes[0] == 0) { $temp = "Invalid"; }
		else { $temp = "Reserved"; }
		printl("SPD Revision", $temp);
	} else {
		my ($spd_size, $spd_used) = spd_sizes(\@bytes);
		printl("# of bytes written to SDRAM EEPROM", $spd_used);
		printl("Total number of bytes in EEPROM", $spd_size);

		# If there's more data than what we've read, let's
		# read it now.  DDR3 will need this data.
		if ($spd_used > @bytes) {
			push (@bytes,
			      readspd(@bytes, $spd_used - @bytes,
				      $dimm[$current]->{file}));
		}
	}

	my $type = sprintf("Unknown (0x%02x)", $bytes[2]);
	if ($dimm[$current]->{is_rambus}) {
		if ($bytes[2] == 1) { $type = "Direct Rambus"; }
		elsif ($bytes[2] == 17) { $type = "Rambus"; }
	} else {
		my @type_list = (
			"Reserved", "FPM DRAM",		# 0, 1
			"EDO", "Pipelined Nibble",	# 2, 3
			"SDR SDRAM", "Multiplexed ROM",	# 4, 5
			"DDR SGRAM", "DDR SDRAM",	# 6, 7
			"DDR2 SDRAM", "FB-DIMM",	# 8, 9
			"FB-DIMM Probe", "DDR3 SDRAM",	# 10, 11
		);
		if ($bytes[2] < @type_list) {
			$type = $type_list[$bytes[2]];
		}
	}
	printl("Fundamental Memory type", $type);

# Decode next 61 bytes (3-63, depend on memory type)
	$decode_callback{$type}->(\@bytes)
		if exists $decode_callback{$type};

	if ($type eq "DDR3 SDRAM") {
		# Decode DDR3-specific manufacturing data in bytes
		# 117-149
		decode_ddr3_mfg_data(\@bytes)
	} else {
		# Decode next 35 bytes (64-98, common to most
		# memory types)
		decode_manufacturing_information(\@bytes);
	}

# Next 27 bytes (99-125) are manufacturer specific, can't decode

# Last 2 bytes (126-127) are reserved, Intel used them as an extension
	if ($type eq "SDR SDRAM") {
		decode_intel_spec_freq(\@bytes);
	}
}

# Side-by-side output format is only possible if all DIMMs have a similar
# output structure
if ($opt_side_by_side) {
	for $current (1 .. $#dimm) {
		my @ref_output = @{$dimm[0]->{output}};
		my @test_output = @{$dimm[$current]->{output}};
		my $line;

		if (scalar @ref_output != scalar @test_output) {
			$opt_side_by_side = 0;
			last;
		}

		for ($line = 0; $line < @ref_output; $line++) {
			my ($ref_func, $ref_label, @ref_dummy) = @{$ref_output[$line]};
			my ($test_func, $test_label, @test_dummy) = @{$test_output[$line]};

			if ($ref_func != $test_func || $ref_label ne $test_label) {
				$opt_side_by_side = 0;
				last;
			}
		}
	}

	if (!$opt_side_by_side) {
		printc("Side-by-side output only possible if all DIMMS are similar\n");

		# Discard "Decoding EEPROM" entry from all outputs
		for $current (0 .. $#dimm) {
			shift(@{$dimm[$current]->{output}});
		}
	}
}

# Find out the longest value string to adjust the column width
# Note: this could be improved a bit by not taking into account strings
# which will end up being merged.
$sbs_col_width = 15;
if ($opt_side_by_side && !$opt_html) {
	for $current (0 .. $#dimm) {
		my @output = @{$dimm[$current]->{output}};
		my $line;
		my @strings;

		for ($line = 0; $line < @output; $line++) {
			my ($func, $label, $value) = @{$output[$line]};
			push @strings, split("\n", $value) if defined $value;
		}

		foreach $line (@strings) {
			my $len = length($line);
			$sbs_col_width = $len if $len > $sbs_col_width;
		}
	}
}

# Print the decoded information for all DIMMs
for $current (0 .. $#dimm) {
	if ($opt_side_by_side) {
		print "\n\n";
	} else {
		print "<b><u>" if $opt_html;
		printl2("\n\nDecoding EEPROM", $dimm[$current]->{file});
		print "</u></b>" if $opt_html;
	}
	print "<table border=1>\n" if $opt_html;

	my @output = @{$dimm[$current]->{output}};
	for (my $line = 0; $line < @output; $line++) {
		my ($func, @param) = @{$output[$line]};

		if ($opt_side_by_side) {
			foreach ($current+1 .. $#dimm) {
				my @xoutput = @{$dimm[$_]->{output}};
				if (@{$xoutput[$line]} == 3) {
					# Line with data, stack all values
					push @param, @{$xoutput[$line]}[2];
				} else {
					# Separator, make it span
					push @param, scalar @dimm;
				}
			}
		}

		$func->(@param);
	}

	print "</table>\n" if $opt_html;
	last if $opt_side_by_side;
}
printl2("\n\nNumber of SDRAM DIMMs detected and decoded", scalar @dimm);

print "</body></html>\n" if ($opt_html && !$opt_bodyonly);
