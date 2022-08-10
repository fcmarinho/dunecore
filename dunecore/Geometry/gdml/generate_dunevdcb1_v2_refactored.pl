#!/usr/bin/perl

#
#
#  First attempt to make a GDML fragment generator for the DUNE vertical drift 
#  10kt detector geometry with 3 views (2 orthogonal + induction at angle)
#  The lower chamber is not added yet. 
#  !!!NOTE!!!: the readout is on a positive Y plane (drift along horizontal X)
#              due to current reco limitations)
#  No photon detectors declared
#  Simplified treatment of inter-module dead spaces
#
#  Created: Thu Oct  1 16:45:27 CEST 2020
#           Vyacheslav Galymov <vgalymov@ipnl.in2p3.fr>
#
#  Modified:
#           VG: Added defs to enable use in the refactored sim framework
#           VG: 23.02.21 Adjust plane dimensions to fit a given number of ch per side
#           VG: 23.02.21 Group CRUs in CRPs
#
#     V2:   Laura Paulucci: 17.03.22 Include Cathode and Cathode mesh
#                                    Included 4 Mini-Arapucas and 1 X-Arapuca over the cathode
#				       TPC height = 23 cm (not 30 cm)
#           Franciole Marinho: 21.07.2022 Included 4 Mini-Arapuscas on the vertical orientation
#
#################################################################################

# Each subroutine generates a fragment GDML file, and the last subroutine
# creates an XML file that make_gdml.pl will use to appropriately arrange
# the fragment GDML files to create the final desired DUNE GDML file, 
# to be named by make_gdml output command

##################################################################################


#use warnings;
use gdmlMaterials;
use Math::Trig;
use Getopt::Long;
use Math::BigFloat;
Math::BigFloat->precision(-16);

###
GetOptions( "help|h" => \$help,
	    "suffix|s:s" => \$suffix,
	    "output|o:s" => \$output,
	    "wires|w:s" => \$wires,  
            "workspace|k:s" => \$wkspc);

my $FieldCage_switch="off";
my $Cathode_switch="on";

if ( defined $help )
{
    # If the user requested help, print the usage notes and exit.
    usage();
    exit;
}

if ( ! defined $suffix )
{
    # The user didn't supply a suffix, so append nothing to the file
    # names.
    $suffix = "";
}
else
{
    # Otherwise, stick a "-" before the suffix, so that a suffix of
    # "test" applied to filename.gdml becomes "filename-test.gdml".
    $suffix = "-" . $suffix;
}


$workspace = 0;
if(defined $wkspc ) 
{
    $workspace = $wkspc;
}
elsif ( $workspace != 0 )
{
    print "\t\tCreating smaller workspace geometry.\n";
}

# set wires on to be the default, unless given an input by the user
$wires_on = 1; # 1=on, 0=off
if (defined $wires)
{
    $wires_on = $wires;
}

$tpc_on = 1;
$basename="_";


##################################################################
############## Parameters for One Readout Panel ##################

# parameters for 1.5 x 1.7 sub-unit Charge Readout Module / Unit
#$widthPCBActive   = 169.0; # cm 
#$lengthPCBActive  = 150.0; # cm

# views and channel counts
%nChans = ('Ind1', 256, 'Ind1Bot', 128, 'Ind2', 320, 'Col', 288);
$nViews = keys %nChans;
#print "$nViews %nChans\n";

# first induction view
$wirePitchU      = 0.8695;  # cm
$wireAngleU      = 131.63;  #-48.37;  # deg

# second induction view
$wirePitchY      = 0.525;
$widthPCBActive  = 168.00;   #$wirePitchY * $nChans{'Ind2'};

# last collection view
$wirePitchZ      = 0.517;
$lengthPCBActive = 148.9009; #$wirePitchZ * $nChans{'Col'};

#
$borderCRM       = 0.0;      # border space aroud each CRM 

$widthCRM_active  = $widthPCBActive;  
$lengthCRM_active = $lengthPCBActive; 

$widthCRM  = $widthPCBActive  + 2 * $borderCRM;
$lengthCRM = $lengthPCBActive + 2 * $borderCRM;

$borderCRP = 0.5; # cm

# number of CRMs in y and z
$nCRM_x   = 2;
$nCRM_z   = 2;

# create a smaller geometry
if( $workspace == 1 )
{
    $nCRM_x = 1 * 2;
    $nCRM_z = 1 * 2;
}

# calculate tpc area based on number of CRMs and their dimensions 
# each CRP should have a 2x2 CRMs
$widthTPCActive  = $nCRM_x * $widthCRM + $nCRM_x * $borderCRP;  # around 1200 for full module
$lengthTPCActive = $nCRM_z * $lengthCRM + $nCRM_z * $borderCRP; # around 6000 for full module

# active volume dimensions 
$driftTPCActive  = 23.0;

# model anode strips as wires of some diameter
$padWidth          = 0.02;
$ReadoutPlane      = $nViews * $padWidth; # 3 readout planes (no space b/w)!

##################################################################
############## Parameters for TPC and inner volume ###############

# inner volume dimensions of the cryostat

# width of gas argon layer on top
$HeightGaseousAr = 40;

#if( $workspace != 0 )

#active tpc + some buffer on each side
$Argon_x = 100.0; #$driftTPCActive  + $HeightGaseousAr + $ReadoutPlane + 30; #~1 m 
$Argon_y = $widthTPCActive  + 52;
$Argon_z = $lengthTPCActive + 92;

$LArOverhead = 20;

# size of liquid argon buffer
$xLArBuffer = $Argon_x - $driftTPCActive - $HeightGaseousAr - $ReadoutPlane - $LArOverhead;
$yLArBuffer = 0.5 * ($Argon_y - $widthTPCActive);
$zLArBuffer = 0.5 * ($Argon_z - $lengthTPCActive);

# cryostat 
$SteelThickness = 0.12; # membrane

$Cryostat_x = $Argon_x + 2*$SteelThickness;
$Cryostat_y = $Argon_y + 2*$SteelThickness;
$Cryostat_z = $Argon_z + 2*$SteelThickness;

##################################################################
############## DetEnc and World relevant parameters  #############

$SteelSupport_x  =  50;
$SteelSupport_y  =  50;
$SteelSupport_z  =  50; 
$FoamPadding     =  50;  
$FracMassOfSteel =  0.5; #The steel support is not a solid block, but a mixture of air and steel
$FracMassOfAir   =  1 - $FracMassOfSteel;


$SpaceSteelSupportToWall    = 100;
$SpaceSteelSupportToCeiling = 100;

$DetEncX  =    $Cryostat_x
                  + 2*($SteelSupport_x + $FoamPadding) + $SpaceSteelSupportToCeiling;

$DetEncY  =    $Cryostat_y
                  + 2*($SteelSupport_y + $FoamPadding) + 2*$SpaceSteelSupportToWall;

$DetEncZ  =    $Cryostat_z
                  + 2*($SteelSupport_z + $FoamPadding) + 2*$SpaceSteelSupportToWall;

$posCryoInDetEnc_x = - $DetEncX/2 + $SteelSupport_x + $FoamPadding + $Cryostat_x/2;


$RockThickness = 4000;

  # We want the world origin to be vertically centered on active TPC
  # This is to be added to the x and y position of every volume in volWorld

$OriginXSet =  $DetEncX/2.0
             - $SteelSupport_x
             - $FoamPadding
             - $SteelThickness
             - $xLArBuffer
             - $driftTPCActive/2.0;

$OriginYSet =   $DetEncY/2.0
              - $SpaceSteelSupportToWall
              - $SteelSupport_y
              - $FoamPadding
              - $SteelThickness
              - $yLArBuffer
              - $widthTPCActive/2.0;

  # We want the world origin to be at the very front of the fiducial volume.
  # move it to the front of the enclosure, then back it up through the concrete/foam, 
  # then through the Cryostat shell, then through the upstream dead LAr (including the
  # dead LAr on the edge of the TPC)
  # This is to be added to the z position of every volume in volWorld

$OriginZSet =   $DetEncZ/2.0 
              - $SpaceSteelSupportToWall
              - $SteelSupport_z
              - $FoamPadding
              - $SteelThickness
              - $zLArBuffer
              - $borderCRM;

##################################################################
############## Field Cage Parameters ###############
$FieldShaperLongTubeLength  =  $lengthTPCActive;
$FieldShaperShortTubeLength =  $widthTPCActive;
$FieldShaperInnerRadius = 1.485;
$FieldShaperOuterRadius = 1.685;
$FieldShaperTorRad = 1.69;

$FieldShaperLength = $FieldShaperLongTubeLength + 2*$FieldShaperOuterRadius+ 2*$FieldShaperTorRad;
$FieldShaperWidth =  $FieldShaperShortTubeLength + 2*$FieldShaperOuterRadius+ 2*$FieldShaperTorRad;

$FieldShaperSeparation = 5.0;
$NFieldShapers = ($driftTPCActive/$FieldShaperSeparation) - 1;

$FieldCageSizeX = $FieldShaperSeparation*$NFieldShapers+2;
$FieldCageSizeY = $FieldShaperWidth+2;
$FieldCageSizeZ = $FieldShaperLength+2;

##################################################################
############## Cathode Parameters ###############
$heightCathode=4.0; #cm
$CathodeBorder=4.0; #cm
$widthCathode=$widthTPCActive; #2*$widthCRM;
$lengthCathode=$lengthTPCActive; #2*$lengthCRM;
$widthCathodeVoid=76.35;
$lengthCathodeVoid=67.0;

#Cathode Mesh

$mesh_diameter = 0.063; #diameter of mesh profiles in cm
$mesh_dist = 1.27; #center to center of mesh profiles in cm
$buffer_mesh = 0.0005; #small gap to avoid overlap of mesh and cathode structure
$NY_mesh = $widthCathode/1.27; #wire count along CB width
$NZ_mesh = $lengthCathode/1.27; #wire count along CB length


####################################################################
######################## PDS ########################
## in cm

$TileOut_x = 2.5; #height
$TileOut_y = 65.0;
$TileOut_z = 65.0; 
$TileIn_x = 2.0;
$TileIn_y = 60.0;
$TileIn_z = 60.0;
$TileAcceptanceWindow_x = 1.0;
$TileAcceptanceWindow_y = 60.0;
$TileAcceptanceWindow_z = 60.0;
$TileposY = 37.2; #with respect to cathode center
$TileposZ = 37.3; #with respect to cathode center
#$TileposZ = -37.3; #with respect to cathode center
#MiniArapucas dimensions
$MiniArapucaOut_x = 2.5; 
$MiniArapucaOut_y = 10.5;
$MiniArapucaOut_z = 14.0; 
$MiniArapucaIn_x = 2.0;
$MiniArapucaIn_y = 7.7;
$MiniArapucaIn_z = 10.0;
$MiniArapucaAcceptanceWindow_x = 1.0;
$MiniArapucaAcceptanceWindow_y = 7.7;
$MiniArapucaAcceptanceWindow_z = 10.0;
#Positions of the 4 MiniArapucas with respect to Cathode center
$list_posy[0]=-74.9;
$list_posz[0]= 118.4;
$list_posy[1]=$list_posy[0];
$list_posz[1]= 88.4;
$list_posy[2]=-$list_posy[1];
$list_posz[2]=$list_posz[1];
$list_posy[3]=-$list_posy[0];
$list_posz[3]=$list_posz[0];
$WallMiniArapucaOut_x = 10.5;
$WallMiniArapucaOut_y = 2.5;
$WallMiniArapucaOut_z = 14.0;
$WallMiniArapucaIn_x = 7.7;
$WallMiniArapucaIn_y = 2.0;
$WallMiniArapucaIn_z = 10.0;
$WallMiniArapucaAcceptanceWindow_x = 7.7;
$WallMiniArapucaAcceptanceWindow_y = 1.0;
$WallMiniArapucaAcceptanceWindow_z = 10.0;
$W_posx[0] = 6.0;
$W_posy[0] = $widthCathode/2.+10.0;
$W_posz[0] = 0.0;
$W_posx[1] = 16.5;
$W_posy[1] = $widthCathode/2.+10.0;
$W_posz[1] = 0.0;
$W_posx[2] = 6.0;
$W_posy[2] = $widthCathode/2.+10.0;
$W_posz[2] = $lengthCathode/4.;
$W_posx[3] = 16.5;
$W_posy[3] = $widthCathode/2.+10.0;
$W_posz[3] = $lengthCathode/4.;

#+++++++++++++++++++++++++ End defining variables ++++++++++++++++++++++++++


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++ usage +++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub usage()
{
    print "Usage: $0 [-h|--help] [-o|--output <fragments-file>] [-s|--suffix <string>]\n";
    print "       if -o is omitted, output goes to STDOUT; <fragments-file> is input to make_gdml.pl\n";
    print "       -s <string> appends the string to the file names; useful for multiple detector versions\n";
    print "       -h prints this message, then quits\n";
}


sub gen_Extend()
{

# Create the <define> fragment file name, 
# add file to list of fragments,
# and open it
    $DEF = $basename."_Ext" . $suffix . ".gdml";
    push (@gdmlFiles, $DEF);
    $DEF = ">" . $DEF;
    open(DEF) or die("Could not open file $DEF for writing");

print DEF <<EOF;
<?xml version='1.0'?>
<gdml>
<extension>
   <color name="magenta"     R="0.0"  G="1.0"  B="0.0"  A="1.0" />
   <color name="green"       R="0.0"  G="1.0"  B="0.0"  A="1.0" />
   <color name="red"         R="1.0"  G="0.0"  B="0.0"  A="1.0" />
   <color name="blue"        R="0.0"  G="0.0"  B="1.0"  A="1.0" />
   <color name="yellow"      R="1.0"  G="1.0"  B="0.0"  A="1.0" />    
</extension>
</gdml>
EOF
    close (DEF);
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#++++++++++++++++++++++++++++++++++++++ gen_Define +++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_Define()
{

# Create the <define> fragment file name, 
# add file to list of fragments,
# and open it
    $DEF = $basename."_Def" . $suffix . ".gdml";
    push (@gdmlFiles, $DEF);
    $DEF = ">" . $DEF;
    open(DEF) or die("Could not open file $DEF for writing");


print DEF <<EOF;
<?xml version='1.0'?>
<gdml>
<define>

<!--



-->

   <position name="posCryoInDetEnc"     unit="cm" x="$posCryoInDetEnc_x" y="0" z="0"/>
   <position name="posCenter"           unit="cm" x="0" y="0" z="0"/>
   <rotation name="rUWireAboutX"        unit="deg" x="$wireAngleU" y="0" z="0"/>
   <rotation name="rPlus90AboutX"       unit="deg" x="90" y="0" z="0"/>
   <rotation name="rPlus90AboutY"       unit="deg" x="0" y="90" z="0"/>
   <rotation name="rPlus90AboutXPlus90AboutY" unit="deg" x="90" y="90" z="0"/>
   <rotation name="rMinus90AboutX"      unit="deg" x="270" y="0" z="0"/>
   <rotation name="rMinus90AboutY"      unit="deg" x="0" y="270" z="0"/>
   <rotation name="rMinus90AboutYMinus90AboutX"       unit="deg" x="270" y="270" z="0"/>
   <rotation name="rPlus180AboutX"	unit="deg" x="180" y="0"   z="0"/>
   <rotation name="rPlus180AboutY"	unit="deg" x="0" y="180"   z="0"/>
   <rotation name="rPlus180AboutXPlus180AboutY"	unit="deg" x="180" y="180"   z="0"/>
   <rotation name="rIdentity"		unit="deg" x="0" y="0"   z="0"/>
</define>
</gdml>
EOF
    close (DEF);
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++ gen_Materials +++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_Materials()
{

# Create the <materials> fragment file name,
# add file to list of output GDML fragments,
# and open it
    $MAT = $basename."_Materials" . $suffix . ".gdml";
    push (@gdmlFiles, $MAT);
    $MAT = ">" . $MAT;

    open(MAT) or die("Could not open file $MAT for writing");

    # Add any materials special to this geometry by defining a mulitline string
    # and passing it to the gdmlMaterials::gen_Materials() function.
my $asmix = <<EOF;
  <!-- preliminary values -->
  <material name="AirSteelMixture" formula="AirSteelMixture">
   <D value=" 0.001205*(1-$FracMassOfSteel) + 7.9300*$FracMassOfSteel " unit="g/cm3"/>
   <fraction n="$FracMassOfSteel" ref="STEEL_STAINLESS_Fe7Cr2Ni"/>
   <fraction n="$FracMassOfAir"   ref="Air"/>
  </material>
  <material name="vm2000" formula="vm2000">
    <D value="1.2" unit="g/cm3"/>
    <composite n="2" ref="carbon"/>
    <composite n="4" ref="hydrogen"/>
  </material>
EOF

    # add the general materials used anywere
    print MAT gdmlMaterials::gen_Materials( $asmix );

    close(MAT);
}


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#++++++++++++++++++++++++++++++++++++++++ gen_TPC ++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# line clip on the rectangle boundary
sub lineClip {
    my $x0  = $_[0];
    my $y0  = $_[1];
    my $nx  = $_[2];
    my $ny  = $_[3];
    my $rcl = $_[4];
    my $rcw = $_[5];

    my $tol = 1.0E-4;
    my @endpts = ();
    if( abs( nx ) < tol ){
	push( @endpts, ($x0, 0) );
	push( @endpts, ($x0, $rcw) );
	return @endpts;
    }
    if( abs( ny ) < tol ){
	push( @endpts, (0, $y0) );
	push( @endpts, ($rcl, $y0) );
	return @endpts;
    }
    
    # left border at x = 0
    my $y = $y0 - $x0 * $ny/$nx;
    if( $y >= 0 && $y <= $rcw ){
	push( @endpts, (0, $y) );
    }

    # right border at x = l
    $y = $y0 + ($rcl-$x0) * $ny/$nx;
    if( $y >= 0 && $y <= $rcw ){
	push( @endpts, ($rcl, $y) );
	if( scalar(@endpts) == 4 ){
	    return @endpts;
	}
    }

    # bottom border at y = 0
    my $x = $x0 - $y0 * $nx/$ny;
    if( $x >= 0 && $x <= $rcl ){
	push( @endpts, ($x, 0) );
	if( scalar(@endpts) == 4 ){
	    return @endpts;
	}
    }
    
    # top border at y = w
    $x = $x0 + ($rcw-$y0)* $nx/$ny;
    if( $x >= 0 && $x <= $rcl ){
	push( @endpts, ($x, $rcw) );
    }
    
    return @endpts;
}

sub gen_Wires
{
    my $length = $_[0];  # 
    my $width  = $_[1];  # 
    my $nch    = $_[2];  # 
    my $nchb   = $_[3];  # nch per bottom side
    my $pitch  = $_[4];  # 
    my $theta  = $_[5];  # deg
    my $dia    = $_[6];  #
    
    $theta  = $theta * pi()/180.0;
    my @dirw   = (cos($theta), sin($theta));
    my @dirp   = (cos($theta - pi()/2), sin($theta - pi()/2));

    # calculate
    my $alpha = $theta;
    if( $alpha > pi()/2 ){
	$alpha = pi() - $alpha;
    }
    my $dX = $pitch / sin( $alpha );
    my $dY = $pitch / sin( pi()/2 - $alpha );
    if( $length <= 0 ){
        $length = $dX * $nchb;
    }
    if( $width <= 0 ){
	$width = $dY * ($nch - $nchb);
    }

    my @orig   = (0, 0);
    if( $dirp[0] < 0 ){
	$orig[0] = $length;
    }
    if( $dirp[1] < 0 ){
	$orig[1] = $width;
    }
  
    #print "origin    : @orig\n";
    #print "pitch dir : @dirp\n";
    #print "wire dir  : @dirw\n";
    #print "$length x $width cm2\n";
    
    # gen wires
    my @winfo  = ();
    my $offset = $pitch/2;
    foreach my $ch (0..$nch-1){
	#print "Processing $ch\n";

	# calculate reference point for this strip
	my @wcn = (0, 0);
	$wcn[0] = $orig[0] + $offset * $dirp[0];
	$wcn[1] = $orig[1] + $offset * $dirp[1];

	# line clip on the rectangle boundary
	@endpts = lineClip( $wcn[0], $wcn[1], $dirw[0], $dirw[1], $length, $width );

	if( scalar(@endpts) != 4 ){
	    print "Could not find end points for wire $ch : @endpts\n";
	    $offset = $offset + $pitch;
	    next;
	}

	# re-center on the mid-point
	$endpts[0] -= $length/2;
	$endpts[2] -= $length/2;
	$endpts[1] -= $width/2;
	$endpts[3] -= $width/2;

	# calculate the strip center in the rectangle of CRU
	$wcn[0] = ($endpts[0] + $endpts[2])/2;
	$wcn[1] = ($endpts[1] + $endpts[3])/2;

	# calculate the length
	my $dx = $endpts[0] - $endpts[2];
	my $dy = $endpts[1] - $endpts[3];
	my $wlen = sqrt($dx**2 + $dy**2);

	# put all info together
	my @wire = ($ch, $wcn[0], $wcn[1], $wlen);
	push( @wire, @endpts );
	push( @winfo, \@wire);
	$offset = $offset + $pitch;
	#last;
    }
    return @winfo;
}

#
sub gen_TPC()
{
    # CRM active volume
    my $TPCActive_x = $driftTPCActive;
    my $TPCActive_y = $widthCRM_active;
    my $TPCActive_z = $lengthCRM_active;

    # CRM total volume
    my $TPC_x = $TPCActive_x + $ReadoutPlane;
    my $TPC_y = $widthCRM;
    my $TPC_z = $lengthCRM;

    print " TPC dimensions     : $TPC_x x $TPC_y x $TPC_z\n";
    
    $TPC = $basename."_TPC" . $suffix . ".gdml";
    push (@gdmlFiles, $TPC);
    $TPC = ">" . $TPC;
    open(TPC) or die("Could not open file $TPC for writing");

    # The standard XML prefix and starting the gdml
print TPC <<EOF;
    <?xml version='1.0'?>
	<gdml>
EOF

    # compute wires for 1st induction
    my @winfo = ();
    if( $wires_on == 1 ){
	@winfo = gen_Wires( 0, 0, # $TPCActive_y,
			    $nChans{'Ind1'}, $nChans{'Ind1Bot'}, 
			    $wirePitchU, $wireAngleU, $padWidth );
    }

    # All the TPC solids save the wires.
print TPC <<EOF;
    <solids>
EOF

print TPC <<EOF;
   <box name="CRM"
      x="$TPC_x" 
      y="$TPC_y" 
      z="$TPC_z"
      lunit="cm"/>
   <box name="CRMUPlane" 
      x="$padWidth" 
      y="$TPCActive_y" 
      z="$TPCActive_z"
      lunit="cm"/>
   <box name="CRMYPlane" 
      x="$padWidth" 
      y="$TPCActive_y" 
      z="$TPCActive_z"
      lunit="cm"/>
   <box name="CRMZPlane" 
      x="$padWidth"
      y="$TPCActive_y"
      z="$TPCActive_z"
      lunit="cm"/>
   <box name="CRMActive" 
      x="$TPCActive_x"
      y="$TPCActive_y"
      z="$TPCActive_z"
      lunit="cm"/>
EOF

#++++++++++++++++++++++++++++ Wire Solids ++++++++++++++++++++++++++++++
if($wires_on==1){
	    
    foreach my $wire (@winfo) {
	my $wid = $wire->[0];
	my $wln = $wire->[3];
print TPC <<EOF;
   <tube name="CRMWireU$wid"
      rmax="0.5*$padWidth"
      z="$wln"               
      deltaphi="360"
      aunit="deg" lunit="cm"/>
EOF
    }
    
print TPC <<EOF;
   <tube name="CRMWireY"
      rmax="0.5*$padWidth"
      z="$TPCActive_z"               
      deltaphi="360" 
      aunit="deg" lunit="cm"/>
   <tube name="CRMWireZ"
      rmax="0.5*$padWidth"
      z="$TPCActive_y"               
      deltaphi="360"
      aunit="deg" lunit="cm"/>
EOF
}
print TPC <<EOF;
</solids>
EOF


# Begin structure and create wire logical volumes
print TPC <<EOF;
<structure>
    <volume name="volTPCActive">
      <materialref ref="LAr"/>
      <solidref ref="CRMActive"/>
      <auxiliary auxtype="SensDet" auxvalue="SimEnergyDeposit"/>
      <auxiliary auxtype="StepLimit" auxunit="cm" auxvalue="0.5208*cm"/>
      <auxiliary auxtype="Efield" auxunit="V/cm" auxvalue="500*V/cm"/>
      <colorref ref="blue"/>
    </volume>
EOF

if($wires_on==1) 
{
    foreach my $wire (@winfo) 
    {
	my $wid = $wire->[0];
print TPC <<EOF;
    <volume name="volTPCWireU$wid">
      <materialref ref="Copper_Beryllium_alloy25"/>
      <solidref ref="CRMWireU$wid"/>
    </volume>
EOF
    }

print TPC <<EOF;
    <volume name="volTPCWireY">
      <materialref ref="Copper_Beryllium_alloy25"/>
      <solidref ref="CRMWireY"/>
    </volume>
    <volume name="volTPCWireZ">
      <materialref ref="Copper_Beryllium_alloy25"/>
      <solidref ref="CRMWireZ"/>
    </volume>
EOF
}
    # 1st induction plane
print TPC <<EOF;
   <volume name="volTPCPlaneU">
     <materialref ref="LAr"/>
     <solidref ref="CRMUPlane"/>
EOF
if ($wires_on==1) # add wires to U plane 
{
    # the coordinates were computed with a corner at (0,0)
    # so we need to move to plane coordinates
    my $offsetZ = 0; #-0.5 * $TPCActive_z;
    my $offsetY = 0; #-0.5 * $TPCActive_y;

    foreach my $wire (@winfo) {
	my $wid  = $wire->[0];
	my $zpos = $wire->[1] + $offsetZ;
	my $ypos = $wire->[2] + $offsetY;
print TPC <<EOF;
     <physvol>
       <volumeref ref="volTPCWireU$wid"/> 
       <position name="posWireU$wid" unit="cm" x="0" y="$ypos" z="$zpos"/>
       <rotationref ref="rUWireAboutX"/> 
     </physvol>
EOF
    }
}
print TPC <<EOF;
   </volume>
EOF

# 2nd induction plane
print TPC <<EOF;
  <volume name="volTPCPlaneY">
    <materialref ref="LAr"/>
    <solidref ref="CRMYPlane"/>
EOF

if ($wires_on==1) # add wires to Y plane (plane with wires reading y position)
{
    for(my $i=0;$i<$nChans{'Ind2'};++$i)
    {
	#my $ypos = -0.5 * $TPCActive_y + ($i+0.5)*$wirePitchY + 0.5*$padWidth;
	my $ypos = ($i + 0.5 - $nChans{'Ind2'}/2)*$wirePitchY;
	if( (0.5 * $TPCActive_y - abs($ypos)) < 0 ){
	    die "Cannot place wire $i in view Y, as plane is too small\n";
	}
print TPC <<EOF;
      <physvol>
        <volumeref ref="volTPCWireY"/> 
        <position name="posWireY$i" unit="cm" x="0" y="$ypos" z="0"/>
	<rotationref ref="rIdentity"/> 
      </physvol>
EOF
   }
}
print TPC <<EOF;
  </volume>
EOF

# collection plane
print TPC <<EOF;
  <volume name="volTPCPlaneZ">
    <materialref ref="LAr"/>
    <solidref ref="CRMZPlane"/>
EOF
if ($wires_on==1) # add wires to Z plane (plane with wires reading z position)
   {
       for(my $i=0;$i<$nChans{'Col'};++$i)
       {
	   #my $zpos = -0.5 * $TPCActive_z + ($i+0.5)*$wirePitchZ + 0.5*$padWidth;
	   my $zpos = ($i + 0.5 - $nChans{'Col'}/2)*$wirePitchZ;
	   if( (0.5 * $TPCActive_z - abs($zpos)) < 0 ){
	       die "Cannot place wire $i in view Z, as plane is too small\n";
	   }
print TPC <<EOF;
       <physvol>
         <volumeref ref="volTPCWireZ"/>
         <position name="posWireZ$i" unit="cm" x="0" y="0" z="$zpos"/>
         <rotationref ref="rPlus90AboutX"/>
       </physvol>
EOF
       }
}
print TPC <<EOF;
  </volume>
EOF

       
$posUplane[0] = 0.5*$TPC_x - 2.5*$padWidth;
$posUplane[1] = 0;
$posUplane[2] = 0;

$posYplane[0] = 0.5*$TPC_x - 1.5*$padWidth;
$posYplane[1] = 0;
$posYplane[2] = 0;

$posZplane[0] = 0.5*$TPC_x - 0.5*$padWidth;
$posZplane[1] = 0; 
$posZplane[2] = 0;

$posTPCActive[0] = -$ReadoutPlane/2;
$posTPCActive[1] = 0;
$posTPCActive[2] = 0;


#wrap up the TPC file
print TPC <<EOF;
   <volume name="volTPC">
     <materialref ref="LAr"/>
       <solidref ref="CRM"/>
       <physvol>
       <volumeref ref="volTPCPlaneU"/>
       <position name="posPlaneU" unit="cm" 
         x="$posUplane[0]" y="$posUplane[1]" z="$posUplane[2]"/>
       <rotationref ref="rIdentity"/>
     </physvol>
     <physvol>
       <volumeref ref="volTPCPlaneY"/>
       <position name="posPlaneY" unit="cm" 
         x="$posYplane[0]" y="$posYplane[1]" z="$posYplane[2]"/>
       <rotationref ref="rIdentity"/>
     </physvol>
     <physvol>
       <volumeref ref="volTPCPlaneZ"/>
       <position name="posPlaneZ" unit="cm" 
         x="$posZplane[0]" y="$posZplane[1]" z="$posZplane[2]"/>
       <rotationref ref="rIdentity"/>
     </physvol>
     <physvol>
       <volumeref ref="volTPCActive"/>
       <position name="posActive" unit="cm" 
        x="$posTPCActive[0]" y="$posTPCAtive[1]" z="$posTPCActive[2]"/>
       <rotationref ref="rIdentity"/>
     </physvol>
   </volume>
EOF
## x="@{[$posTPCActive[0]+$padWidth]}" y="$posTPCActive[1]" z="$posTPCActive[2]"/>

print TPC <<EOF;
 </structure>
 </gdml>
EOF

    close(TPC);
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#++++++++++++++++++++++++++++++++++++++ gen_FieldCage ++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_FieldCage {

    $FieldCage = $basename."_FieldCage" . $suffix . ".gdml";
    push (@gdmlFiles, $FieldCage);
    $FieldCage = ">" . $FieldCage;
    open(FieldCage) or die("Could not open file $FieldCage for writing");

# The standard XML prefix and starting the gdml
print FieldCage <<EOF;
   <?xml version='1.0'?>
   <gdml>
EOF
# The printing solids used in the Field Cage
#print "lengthTPCActive      : $lengthTPCActive \n";
#print "widthTPCActive       : $widthTPCActive \n";


print FieldCage <<EOF;
<solids>
     <torus name="FieldShaperCorner" rmin="$FieldShaperInnerRadius" rmax="$FieldShaperOuterRadius" rtor="$FieldShaperTorRad" deltaphi="90" startphi="0" aunit="deg" lunit="cm"/>
     <tube name="FieldShaperLongtube" rmin="$FieldShaperInnerRadius" rmax="$FieldShaperOuterRadius" z="$FieldShaperLongTubeLength" deltaphi="360" startphi="0" aunit="deg" lunit="cm"/>
     <tube name="FieldShaperShorttube" rmin="$FieldShaperInnerRadius" rmax="$FieldShaperOuterRadius" z="$FieldShaperShortTubeLength" deltaphi="360" startphi="0" aunit="deg" lunit="cm"/>

    <union name="FSunion1">
      <first ref="FieldShaperLongtube"/>
      <second ref="FieldShaperCorner"/>
   		<position name="esquinapos1" unit="cm" x="@{[-$FieldShaperTorRad]}" y="0" z="@{[0.5*$FieldShaperLongTubeLength]}"/>
		<rotation name="rot1" unit="deg" x="90" y="0" z="0" />
    </union>

    <union name="FSunion2">
      <first ref="FSunion1"/>
      <second ref="FieldShaperShorttube"/>
   		<position name="esquinapos2" unit="cm" x="@{[-0.5*$FieldShaperShortTubeLength-$FieldShaperTorRad]}" y="0" z="@{[+0.5*$FieldShaperLongTubeLength+$FieldShaperTorRad]}"/>
   		<rotation name="rot2" unit="deg" x="0" y="90" z="0" />
    </union>

    <union name="FSunion3">
      <first ref="FSunion2"/>
      <second ref="FieldShaperCorner"/>
   		<position name="esquinapos3" unit="cm" x="@{[-$FieldShaperShortTubeLength-$FieldShaperTorRad]}" y="0" z="@{[0.5*$FieldShaperLongTubeLength]}"/>
		<rotation name="rot3" unit="deg" x="90" y="270" z="0" />
    </union>

    <union name="FSunion4">
      <first ref="FSunion3"/>
      <second ref="FieldShaperLongtube"/>
   		<position name="esquinapos4" unit="cm" x="@{[-$FieldShaperShortTubeLength-2*$FieldShaperTorRad]}" y="0" z="0"/>
    </union>

    <union name="FSunion5">
      <first ref="FSunion4"/>
      <second ref="FieldShaperCorner"/>
   		<position name="esquinapos5" unit="cm" x="@{[-$FieldShaperShortTubeLength-$FieldShaperTorRad]}" y="0" z="@{[-0.5*$FieldShaperLongTubeLength]}"/>
		<rotation name="rot5" unit="deg" x="90" y="180" z="0" />
    </union>

    <union name="FSunion6">
      <first ref="FSunion5"/>
      <second ref="FieldShaperShorttube"/>
   		<position name="esquinapos6" unit="cm" x="@{[-0.5*$FieldShaperShortTubeLength-$FieldShaperTorRad]}" y="0" z="@{[-0.5*$FieldShaperLongTubeLength-$FieldShaperTorRad]}"/>
		<rotation name="rot6" unit="deg" x="0" y="90" z="0" />
    </union>

    <union name="FieldShaperSolid">
      <first ref="FSunion6"/>
      <second ref="FieldShaperCorner"/>
   		<position name="esquinapos7" unit="cm" x="@{[-$FieldShaperTorRad]}" y="0" z="@{[-0.5*$FieldShaperLongTubeLength]}"/>
		<rotation name="rot7" unit="deg" x="90" y="90" z="0" />
    </union>
</solids>

EOF

print FieldCage <<EOF;

<structure>
<volume name="volFieldShaper">
  <materialref ref="Al2O3"/>
  <solidref ref="FieldShaperSolid"/>
</volume>
</structure>

EOF

print FieldCage <<EOF;

</gdml>
EOF
close(FieldCage);
}


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++ gen_Cathode +++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_Cathode {

    $Cathode = $basename."_Catode" . $suffix . ".gdml";
    push (@gdmlFiles, $Cathode);
    $Cathode = ">" . $Cathode;
    open(Cathode) or die("Could not open file $Cathode for writing");

# The standard XML prefix and starting the gdml
print Cathode <<EOF;
   <?xml version='1.0'?>
   <gdml>
EOF
# The printing solids used in the Field Cage
#print "lengthTPCActive      : $lengthTPCActive \n";
#print "widthTPCActive       : $widthTPCActive \n";


print Cathode <<EOF;
<solids>
     <tube name="CatMeshZSolid" rmax="0.5*$mesh_diameter" z="$lengthCathode"      
      deltaphi="360" aunit="deg" lunit="cm"/>
    <tube name="CatMeshYSolid" rmax="0.5*$mesh_diameter" z="$widthCathode"      
      deltaphi="360" aunit="deg" lunit="cm"/>
</solids>

EOF

print Cathode <<EOF;

<structure>
<volume name="volCatMeshY">
  <materialref ref="STEEL_STAINLESS_Fe7Cr2Ni"/>
  <solidref ref="CatMeshYSolid"/>
</volume>
<volume name="volCatMeshZ">
  <materialref ref="STEEL_STAINLESS_Fe7Cr2Ni"/>
  <solidref ref="CatMeshZSolid"/>
</volume> 
</structure>

EOF

print Cathode <<EOF;

</gdml>
EOF
close(Cathode);
}


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#++++++++++++++++++++++++++++++++++++++ gen_Cryostat +++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_Cryostat()
{

# Create the cryostat fragment file name,
# add file to list of output GDML fragments,
# and open it
    $CRYO = $basename."_Cryostat" . $suffix . ".gdml";
    push (@gdmlFiles, $CRYO);
    $CRYO = ">" . $CRYO;
    open(CRYO) or die("Could not open file $CRYO for writing");


# The standard XML prefix and starting the gdml
    print CRYO <<EOF;
<?xml version='1.0'?>
<gdml>
EOF

# All the cryostat solids.
print CRYO <<EOF;
<solids>
    <box name="Cryostat" lunit="cm" 
      x="$Cryostat_x" 
      y="$Cryostat_y" 
      z="$Cryostat_z"/>

    <box name="ArgonInterior" lunit="cm" 
      x="$Argon_x"
      y="$Argon_y"
      z="$Argon_z"/>

    <box name="GaseousArgon" lunit="cm" 
      x="$HeightGaseousAr"
      y="$Argon_y"
      z="$Argon_z"/>

    <subtraction name="SteelShell">
      <first ref="Cryostat"/>
      <second ref="ArgonInterior"/>
    </subtraction>

</solids>
EOF

#PDS
#1 large X-Arapuca = TILE and 4 mini-Arapucas + 4 wall mini-arapucas
print CRYO <<EOF;
<solids>
    <box name="TileOut" lunit="cm"
      x="@{[$TileOut_x]}"
      y="@{[$TileOut_y]}"
      z="@{[$TileOut_z]}"/>

    <box name="TileIn" lunit="cm"
      x="@{[$TileOut_x]}"
      y="@{[$TileIn_y]}"
      z="@{[$TileIn_z]}"/>

     <subtraction name="TileWalls">
      <first  ref="TileOut"/>
      <second ref="TileIn"/>
      <position name="posTileSub" x="@{[$TileOut_x/2.0]}" y="0" z="0." unit="cm"/>
      </subtraction>

    <box name="TileAcceptanceWindow" lunit="cm"
      x="@{[$TileAcceptanceWindow_x]}"
      y="@{[$TileAcceptanceWindow_y]}"
      z="@{[$TileAcceptanceWindow_z]}"/>

    <box name="MiniArapucaOut" lunit="cm"
      x="@{[$MiniArapucaOut_x]}"
      y="@{[$MiniArapucaOut_y]}"
      z="@{[$MiniArapucaOut_z]}"/>

    <box name="MiniArapucaIn" lunit="cm"
      x="@{[$MiniArapucaOut_x]}"
      y="@{[$MiniArapucaIn_y]}"
      z="@{[$MiniArapucaIn_z]}"/>

     <subtraction name="MiniArapucaWalls">
      <first  ref="MiniArapucaOut"/>
      <second ref="MiniArapucaIn"/>
      <position name="posMiniArapucaSub" x="@{[$MiniArapucaOut_x/2.0]}" y="0" z="0." unit="cm"/>
      </subtraction>

    <box name="MiniArapucaAcceptanceWindow" lunit="cm"
      x="@{[$MiniArapucaAcceptanceWindow_x]}"
      y="@{[$MiniArapucaAcceptanceWindow_y]}"
      z="@{[$MiniArapucaAcceptanceWindow_z]}"/>

    <box name="WallMiniArapucaOut" lunit="cm"
      x="@{[$WallMiniArapucaOut_x]}"
      y="@{[$WallMiniArapucaOut_y]}"
      z="@{[$WallMiniArapucaOut_z]}"/>

    <box name="WallMiniArapucaIn" lunit="cm"
      x="@{[$WallMiniArapucaOut_x]}"
      y="@{[$WallMiniArapucaIn_y]}"
      z="@{[$WallMiniArapucaIn_z]}"/>

     <subtraction name="WallMiniArapucaWalls">
      <first  ref="WallMiniArapucaOut"/>
      <second ref="WallMiniArapucaIn"/>
      <position name="posWallMiniArapucaSub" x="0" y="@{[$WallMiniArapucaOut_y/2.0]}" z="0." unit="cm"/>
      </subtraction>

    <box name="WallMiniArapucaAcceptanceWindow" lunit="cm"
      x="@{[$WallMiniArapucaAcceptanceWindow_x]}"
      y="@{[$WallMiniArapucaAcceptanceWindow_y]}"
      z="@{[$WallMiniArapucaAcceptanceWindow_z]}"/>

</solids>
EOF

# Cryostat structure
print CRYO <<EOF;
<structure>
    <volume name="volSteelShell">
      <materialref ref="STEEL_STAINLESS_Fe7Cr2Ni" />
      <solidref ref="SteelShell" />
    </volume>
    <volume name="volGroundGrid">
      <materialref ref="STEEL_STAINLESS_Fe7Cr2Ni" />
      <solidref ref="CathodeGrid" />
    </volume>
    <volume name="volGaseousArgon">
      <materialref ref="ArGas"/>
      <solidref ref="GaseousArgon"/>
    </volume>
EOF

  print CRYO <<EOF;
    <volume name="volTile">
      <materialref ref="G10"/>
      <solidref ref="TileWalls"/>
    </volume>
    <volume name="volOpDetSensitive_Tile">
      <materialref ref="LAr"/>
      <solidref ref="TileAcceptanceWindow"/>
    </volume>
EOF

for($p=0 ; $p<4 ; $p++){
  print CRYO <<EOF;
    <volume name="volMiniArapuca\-$p">
      <materialref ref="G10" />
      <solidref ref="MiniArapucaWalls" />
    </volume>
    <volume name="volOpDetSensitive_MiniArapuca\-$p">
      <materialref ref="LAr"/>
      <solidref ref="MiniArapucaAcceptanceWindow"/>
    </volume>
EOF
}

for($p=0 ; $p<4 ; $p++){
  print CRYO <<EOF;
    <volume name="volWallMiniArapuca\-$p">
      <materialref ref="G10" />
      <solidref ref="WallMiniArapucaWalls" />
    </volume>
    <volume name="volOpDetSensitive_WallMiniArapuca\-$p">
      <materialref ref="LAr"/>
      <solidref ref="WallMiniArapucaAcceptanceWindow"/>
    </volume>
EOF
}   

      print CRYO <<EOF;

    <volume name="volCryostat">
      <materialref ref="LAr" />
	<solidref ref="Cryostat" />
	<auxiliary auxtype="SensDet" auxvalue="SimEnergyDeposit"/>
	<auxiliary auxtype="StepLimit" auxunit="cm" auxvalue="0.47625*cm"/>
	<auxiliary auxtype="Efield" auxunit="V/cm" auxvalue="0*V/cm"/>
      <physvol>
        <volumeref ref="volGaseousArgon"/>
        <position name="posGaseousArgon" unit="cm" x="@{[$Argon_x/2-$HeightGaseousAr/2]}" y="0" z="0"/>
      </physvol>
      <physvol>
        <volumeref ref="volSteelShell"/>
        <position name="posSteelShell" unit="cm" x="0" y="0" z="0"/>
      </physvol>
EOF


if ($tpc_on==1) # place TPC inside croysotat offsetting each pair of CRMs by borderCRP
{
  $posX =  $Argon_x/2 - $HeightGaseousAr - 0.5*($driftTPCActive + $ReadoutPlane) - $LArOverhead; #20 cm overhead lar 
    #$posX =  10 - 0.5*($driftTPCActive + $ReadoutPlane); 
  $idx = 0;
  my $posZ = -0.5*$Argon_z + $zLArBuffer + 0.5*$lengthCRM;
  for(my $ii=0;$ii<$nCRM_z;$ii++)
  {
    if( $ii % 2 == 0 ){
	$posZ += $borderCRP;
	if( $ii>0 ){
	    $posZ += $borderCRP;
	}
    }
    my $posY = -0.5*$Argon_y + $yLArBuffer + 0.5*$widthCRM;
    for(my $jj=0;$jj<$nCRM_x;$jj++)
    {
	if( $jj % 2 == 0 ){
	    $posY += $borderCRP;
	    if( $jj>0 ){
		$posY += $borderCRP;
	    }
	}
	print CRYO <<EOF;
      <physvol>
        <volumeref ref="volTPC"/>
	<position name="posTPC\-$idx" unit="cm"
           x="$posX" y="$posY" z="$posZ"/>
      </physvol>
EOF
       $idx++;
       $posY += $widthCRM;
    }

    $posZ += $lengthCRM;
  }

}

#The +50 in the x positions must depend on some other parameter
  if ( $FieldCage_switch eq "on" ) {
    for ( $i=0; $i<$NFieldShapers; $i=$i+1 ) {
$posX =  $Argon_x/2 - $HeightGaseousAr - 0.5*($driftTPCActive + $ReadoutPlane); 
	print CRYO <<EOF;
  <physvol>
     <volumeref ref="volFieldShaper"/>
     <position name="posFieldShaper$i" unit="cm"  x="@{[-$OriginXSet+50+($i-$NFieldShapers*0.5)*$FieldShaperSeparation]}" y="@{[-0.5*$FieldShaperShortTubeLength-$FieldShaperTorRad]}" z="0" />
     <rotation name="rotFS$i" unit="deg" x="0" y="0" z="90" />
  </physvol>
EOF
    }
  }	

$CathodePosX =-$OriginXSet+50+(-1-$NFieldShapers*0.5)*$FieldShaperSeparation - $heightCathode/2. - 2.*$mesh_diameter - 2.*$buffer_mesh;#new cathode position to accomodate the cathode mesh
$CathodePosY = 0;
$CathodePosZ = 0;
  if ( $Cathode_switch eq "on" )
  {
      print CRYO <<EOF;
  <physvol>
   <volumeref ref="volGroundGrid"/>
   <position name="posGroundGrid01" unit="cm" x="@{[$CathodePosX]}" y="@{[-$CathodePosY]}" z="@{[$CathodePosZ]}"/>
  </physvol>

EOF
  }

for ( $i=0; $i<$NZ_mesh; $i=$i+1 ) { 
$posZ = $CathodePosZ - $lengthCathode/2. + $i*$mesh_dist; 
	print CRYO <<EOF;
<physvol>
<volumeref ref="volCatMeshY"/>
<position name="posCatMeshY$i" unit="cm" x="@{[$CathodePosX + $heightCathode/2. + $mesh_diameter/2. + $buffer_mesh]}" y="@{[-$CathodePosY]}" z="@{[$posZ]}" />
<rotationref ref="rPlus90AboutX"/>
</physvol>
EOF
}
for ( $i=0; $i<$NY_mesh; $i=$i+1 ) { 
$posY = $CathodePosY - $widthCathode/2. + $i*$mesh_dist; 
	print CRYO <<EOF;
<physvol>
<volumeref ref="volCatMeshZ"/>
<position name="posCatMeshZ$i" unit="cm" x="@{[$CathodePosX + $heightCathode/2. + 3.*$mesh_diameter/2. + 2.*$buffer_mesh]}" y="@{[$posY]}" z="@{[$CathodePosZ]}" />
</physvol>
EOF
}

place_OpDetsCathode($CathodePosX,-$CathodePosY, $CathodePosZ);
  
 print CRYO <<EOF;
    </volume>
</structure>
</gdml>
EOF

close(CRYO);
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++ place_CathodeMesh +++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub place_CathodeMesh()
{

    $CathodePos_x = $_[0];
    $CathodePos_y = $_[1];
    $CathodePos_z = $_[2];

for ( $i=0; $i<$NZ_mesh; $i=$i+1 ) { 
$posZ = $CathodePos_z - $lengthCathode/2. + $i*$mesh_dist; 
	print CRYO <<EOF;
  <physvol>
     <volumeref ref="volCatMeshY"/>
     <position name="posCatMeshY$i" unit="cm"  x="@{[$CathodePos_x + $heightCathode/2. + $mesh_diameter/2. + $buffer_mesh]}" y="@{[$CathodePos_y]}" z="@{[$posZ]}" />
     <rotationref ref="rPlus90AboutX"/>
  </physvol>
EOF
}
for ( $i=0; $i<$NY_mesh; $i=$i+1 ) { 
$posY = $CathodePos_y - $widthCathode/2. + $i*$mesh_dist; 
	print CRYO <<EOF;
  <physvol>
     <volumeref ref="volCatMeshZ"/>
     <position name="posCatMeshZ$i" unit="cm"  x="@{[$CathodePos_x + $heightCathode/2. + 3.*$mesh_diameter/2. + 2.*$buffer_mesh]}" y="@{[$posY]}" z="@{[$CathodePos_z]}" />
  </physvol>
EOF
}
}
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#++++++++++++++++++++++++++++++++++++ place_OpDets +++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub place_OpDetsCathode()
{

    $FrameCenter_x = $_[0];
    $FrameCenter_y = $_[1];
    $FrameCenter_z = $_[2];

#Placing Arapucas over the Cathode
#Tile
	print CRYO <<EOF;
     <physvol>
       <volumeref ref="volTile"/>
       <position name="posTile" unit="cm" 
         x="@{[$FrameCenter_x]}"
	 y="@{[$FrameCenter_y+$TileposY]}" 
	 z="@{[$FrameCenter_z+$TileposZ]}"/>
     </physvol>
     <physvol>
       <volumeref ref="volOpDetSensitive_Tile"/>
       <position name="posOpTile" unit="cm" 
         x="@{[$FrameCenter_x+0.5*$TileOut_x-0.5*$TileAcceptanceWindow_x-0.01]}"
	 y="@{[$FrameCenter_y+$TileposY]}" 
	 z="@{[$FrameCenter_z+$TileposZ]}"/>
     </physvol>
EOF
#Placing the miniArapucas
for ($ara = 0; $ara<4; $ara++)
{
 	     $Ara_X = $FrameCenter_x;
             $Ara_Y = $FrameCenter_y +$list_posy[$ara];
 	     $Ara_Z = $FrameCenter_z+$list_posz[$ara];

	print CRYO <<EOF;
     <physvol>
       <volumeref ref="volMiniArapuca\-$ara"/>
       <position name="posMiniArapuca$ara" unit="cm" 
         x="@{[$Ara_X]}"
	 y="@{[$Ara_Y]}" 
	 z="@{[$Ara_Z]}"/>
     </physvol>
     <physvol>
       <volumeref ref="volOpDetSensitive_MiniArapuca-$ara"/>
       <position name="posOpMiniArapuca$ara" unit="cm" 
         x="@{[$Ara_X+0.5*$MiniArapucaOut_x-0.5*$MiniArapucaAcceptanceWindow_x-0.01]}"
	 y="@{[$Ara_Y]}" 
	 z="@{[$Ara_Z]}"/>
     </physvol>
EOF

}#end Ara for-loop

for ($ara = 0; $ara<4; $ara++)
{
 	     $Ara_X = $FrameCenter_x+$W_posx[$ara];
             $Ara_Y = $FrameCenter_y+$W_posy[$ara];
 	     $Ara_Z = $FrameCenter_z+$W_posz[$ara];

	print CRYO <<EOF;
     <physvol>
       <volumeref ref="volWallMiniArapuca\-$ara"/>
       <position name="posWallMiniArapuca$ara" unit="cm" 
         x="@{[$Ara_X]}"
	 y="@{[$Ara_Y]}" 
	 z="@{[$Ara_Z]}"/>
     </physvol>
     <physvol>
       <volumeref ref="volOpDetSensitive_WallMiniArapuca-$ara"/>
       <position name="posOpWallMiniArapuca$ara" unit="cm" 
         x="@{[$Ara_X]}"
	 y="@{[$Ara_Y-0.5*$WallMiniArapucaOut_y-0.5*$WallMiniArapucaAcceptanceWindow_y-0.01]}" 
	 z="@{[$Ara_Z]}"/>
     </physvol>
EOF

}#end WAra for-loop

}



#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++ gen_Enclosure +++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_Enclosure()
{

# Create the detector enclosure fragment file name,
# add file to list of output GDML fragments,
# and open it
    $ENCL = $basename."_DetEnclosure" . $suffix . ".gdml";
    push (@gdmlFiles, $ENCL);
    $ENCL = ">" . $ENCL;
    open(ENCL) or die("Could not open file $ENCL for writing");


# The standard XML prefix and starting the gdml
    print ENCL <<EOF;
<?xml version='1.0'?>
<gdml>
EOF


# All the detector enclosure solids.
print ENCL <<EOF;
<solids>

    <box name="CathodeBlock" lunit="cm"
      x="@{[$heightCathode]}"
      y="@{[$widthCathode]}"
      z="@{[$lengthCathode]}" />

    <box name="CathodeVoid" lunit="cm"
      x="@{[$heightCathode+1.0]}"
      y="@{[$widthCathodeVoid]}"
      z="@{[$lengthCathodeVoid]}" />

    <subtraction name="Cathode1">
      <first ref="CathodeBlock"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub1" x="0" y="@{[-1.5*$widthCathodeVoid-2.0*$CathodeBorder]}" z="@{[-1.5*$lengthCathodeVoid-2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode2">
      <first ref="Cathode1"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub2" x="0" y="@{[-1.5*$widthCathodeVoid-2.0*$CathodeBorder]}" z="@{[-0.5*$lengthCathodeVoid-1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode3">
      <first ref="Cathode2"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub3" x="0" y="@{[-1.5*$widthCathodeVoid-2.0*$CathodeBorder]}" z="@{[0.5*$lengthCathodeVoid+1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode4">
      <first ref="Cathode3"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub4" x="0" y="@{[-1.5*$widthCathodeVoid-2.0*$CathodeBorder]}" z="@{[1.5*$lengthCathodeVoid+2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode5">
      <first ref="Cathode4"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub5" x="0" y="@{[-0.5*$widthCathodeVoid-1.0*$CathodeBorder]}" z="@{[-1.5*$lengthCathodeVoid-2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode6">
      <first ref="Cathode5"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub6" x="0" y="@{[-0.5*$widthCathodeVoid-1.0*$CathodeBorder]}" z="@{[-0.5*$lengthCathodeVoid-1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode7">
      <first ref="Cathode6"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub7" x="0" y="@{[-0.5*$widthCathodeVoid-1.0*$CathodeBorder]}" z="@{[0.5*$lengthCathodeVoid+1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode8">
      <first ref="Cathode7"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub8" x="0" y="@{[-0.5*$widthCathodeVoid-1.0*$CathodeBorder]}" z="@{[1.5*$lengthCathodeVoid+2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode9">
      <first ref="Cathode8"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub9" x="0" y="@{[0.5*$widthCathodeVoid+1.0*$CathodeBorder]}" z="@{[-1.5*$lengthCathodeVoid-2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode10">
      <first ref="Cathode9"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub10" x="0" y="@{[0.5*$widthCathodeVoid+1.0*$CathodeBorder]}" z="@{[-0.5*$lengthCathodeVoid-1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode11">
      <first ref="Cathode10"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub11" x="0" y="@{[0.5*$widthCathodeVoid+1.0*$CathodeBorder]}" z="@{[0.5*$lengthCathodeVoid+1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode12">
      <first ref="Cathode11"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub12" x="0" y="@{[0.5*$widthCathodeVoid+1.0*$CathodeBorder]}" z="@{[1.5*$lengthCathodeVoid+2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode13">
      <first ref="Cathode12"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub13" x="0" y="@{[1.5*$widthCathodeVoid+2.0*$CathodeBorder]}" z="@{[-1.5*$lengthCathodeVoid-2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode14">
      <first ref="Cathode13"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub14" x="0" y="@{[1.5*$widthCathodeVoid+2.0*$CathodeBorder]}" z="@{[-0.5*$lengthCathodeVoid-1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="Cathode15">
      <first ref="Cathode14"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub15" x="0" y="@{[1.5*$widthCathodeVoid+2.0*$CathodeBorder]}" z="@{[0.5*$lengthCathodeVoid+1.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>
    <subtraction name="CathodeGrid">
      <first ref="Cathode15"/>
      <second ref="CathodeVoid"/>
      <position name="posCathodeSub16" x="0" y="@{[1.5*$widthCathodeVoid+2.0*$CathodeBorder]}" z="@{[1.5*$lengthCathodeVoid+2.0*$CathodeBorder]}" unit="cm"/>
    </subtraction>

    <box name="FoamPadBlock" lunit="cm"
      x="@{[$Cryostat_x + 2*$FoamPadding]}"
      y="@{[$Cryostat_y + 2*$FoamPadding]}"
      z="@{[$Cryostat_z + 2*$FoamPadding]}" />

    <subtraction name="FoamPadding">
      <first ref="FoamPadBlock"/>
      <second ref="Cryostat"/>
      <positionref ref="posCenter"/>
    </subtraction>

    <box name="SteelSupportBlock" lunit="cm"
      x="@{[$Cryostat_x + 2*$FoamPadding + 2*$SteelSupport_x]}"
      y="@{[$Cryostat_y + 2*$FoamPadding + 2*$SteelSupport_y]}"
      z="@{[$Cryostat_z + 2*$FoamPadding + 2*$SteelSupport_z]}" />

    <subtraction name="SteelSupport">
      <first ref="SteelSupportBlock"/>
      <second ref="FoamPadBlock"/>
      <positionref ref="posCenter"/>
    </subtraction>

    <box name="DetEnclosure" lunit="cm" 
      x="$DetEncX"
      y="$DetEncY"
      z="$DetEncZ"/>

</solids>
EOF


# Detector enclosure structure
    print ENCL <<EOF;
<structure>
    <volume name="volFoamPadding">
      <materialref ref="fibrous_glass"/>
      <solidref ref="FoamPadding"/>
    </volume>

    <volume name="volSteelSupport">
      <materialref ref="AirSteelMixture"/>
      <solidref ref="SteelSupport"/>
    </volume>

    <volume name="volDetEnclosure">
      <materialref ref="Air"/>
      <solidref ref="DetEnclosure"/>

       <physvol>
           <volumeref ref="volFoamPadding"/>
           <positionref ref="posCryoInDetEnc"/>
       </physvol>
       <physvol>
           <volumeref ref="volSteelSupport"/>
           <positionref ref="posCryoInDetEnc"/>
       </physvol>
       <physvol>
           <volumeref ref="volCryostat"/>
           <positionref ref="posCryoInDetEnc"/>
       </physvol>
EOF


print ENCL <<EOF;
    </volume>
EOF

print ENCL <<EOF;
</structure>
</gdml>
EOF

close(ENCL);
}



#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++ gen_World +++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub gen_World()
{

# Create the WORLD fragment file name,
# add file to list of output GDML fragments,
# and open it
    $WORLD = $basename."_World" . $suffix . ".gdml";
    push (@gdmlFiles, $WORLD);
    $WORLD = ">" . $WORLD;
    open(WORLD) or die("Could not open file $WORLD for writing");


# The standard XML prefix and starting the gdml
    print WORLD <<EOF;
<?xml version='1.0'?>
<gdml>
EOF


# All the World solids.
print WORLD <<EOF;
<solids>
    <box name="World" lunit="cm" 
      x="@{[$DetEncX+2*$RockThickness]}" 
      y="@{[$DetEncY+2*$RockThickness]}" 
      z="@{[$DetEncZ+2*$RockThickness]}"/>
</solids>
EOF

# World structure
print WORLD <<EOF;
<structure>
    <volume name="volWorld" >
      <materialref ref="DUSEL_Rock"/>
      <solidref ref="World"/>

      <physvol>
        <volumeref ref="volDetEnclosure"/>
	<position name="posDetEnclosure" unit="cm" x="$OriginXSet" y="$OriginYSet" z="$OriginZSet"/>
      </physvol>

    </volume>
</structure>
</gdml>
EOF

# make_gdml.pl will take care of <setup/>

close(WORLD);
}



#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#++++++++++++++++++++++++++++++++++++ write_fragments ++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub write_fragments()
{
   # This subroutine creates an XML file that summarizes the the subfiles output
   # by the other sub routines - it is the input file for make_gdml.pl which will
   # give the final desired GDML file. Specify its name with the output option.
   # (you can change the name when running make_gdml)

   # This code is taken straigh from the similar MicroBooNE generate script, Thank you.

    if ( ! defined $output )
    {
	$output = "-"; # write to STDOUT 
    }

    # Set up the output file.
    $OUTPUT = ">" . $output;
    open(OUTPUT) or die("Could not open file $OUTPUT");

    print OUTPUT <<EOF;
<?xml version='1.0'?>

<!-- Input to Geometry/gdml/make_gdml.pl; define the GDML fragments
     that will be zipped together to create a detector description. 
     -->

<config>

   <constantfiles>

      <!-- These files contain GDML <constant></constant>
           blocks. They are read in separately, so they can be
           interpreted into the remaining GDML. See make_gdml.pl for
           more information. 
	   -->
	   
EOF

    foreach $filename (@defFiles)
    {
	print OUTPUT <<EOF;
      <filename> $filename </filename>
EOF
    }

    print OUTPUT <<EOF;

   </constantfiles>

   <gdmlfiles>

      <!-- The GDML file fragments to be zipped together. -->

EOF

    foreach $filename (@gdmlFiles)
    {
	print OUTPUT <<EOF;
      <filename> $filename </filename>
EOF
    }

    print OUTPUT <<EOF;

   </gdmlfiles>

</config>
EOF

    close(OUTPUT);
}


print "Some of the principal parameters for this TPC geometry (unit cm unless noted otherwise)\n";
print " CRM active area       : $widthCRM_active x $lengthCRM_active\n";
print " CRM total area        : $widthCRM x $lengthCRM\n";
print " Wire pitch in U, Y, Z : $wirePitchU, $wirePitchY, $wirePitchZ\n";
print " TPC active volume  : $driftTPCActive x $widthTPCActive x $lengthTPCActive\n";
print " Argon volume       : ($Argon_x, $Argon_y, $Argon_z) \n"; 
print " Argon buffer       : ($xLArBuffer, $yLArBuffer, $zLArBuffer) \n"; 
print " Detector enclosure : $DetEncX x $DetEncY x $DetEncZ\n";
print " TPC Origin         : ($OriginXSet, $OriginYSet, $OriginZSet) \n";
print " Field Cage         : $FieldCage_switch \n";
print " Cathode            : $Cathode_switch \n";
print " Workspace          : $workspace \n";
print " Wires              : $wires_on \n";

# run the sub routines that generate the fragments
if ( $FieldCage_switch eq "on" ) {  gen_FieldCage();	}
if ( $Cathode_switch eq "on" ) {  gen_Cathode();	} #Cathode for now has the same geometry as the Ground Grid

gen_Extend();    # generates the GDML color extension for the refactored geometry 
gen_Define(); 	 # generates definitions at beginning of GDML
gen_Materials(); # generates materials to be used
gen_TPC();       # generate TPC for a given unit CRM
gen_Cryostat();  # 
gen_Enclosure(); # 
gen_World();	 # places the enclosure among DUSEL Rock
write_fragments(); # writes the XML input for make_gdml.pl
		   # which zips together the final GDML
print "--- done\n\n\n";
exit;
