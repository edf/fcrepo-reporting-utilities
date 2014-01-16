#!/usr/bin/perl
# collection space used reporting  -edf 2013-1222
use strict;
use warnings;
no warnings qw(uninitialized);
use URI::Escape;
use XML::LibXSLT;
use XML::LibXML;

if ( $#ARGV != 0 ) {
    print "\n Usage is $0 <collection pid> \n\n";
    exit(8);
}

#TODO add comments
#TODO check if item in collection is a collection
#TODO report nested collection space used

my $collectionPid = $ARGV[0];
chomp $collectionPid;

my ($ServerName,$ServerPort,$fedoraContext,$UserName,$PassWord);          # local settings 
my $configFile = "settings.config";
open my $configFH, "<", "$configFile" or die "\n\n   Program $0 stopping, couldn't open the configuration file '$configFile' $!.\n\n";
    my $config = join "", <$configFH>;                                    # print "\n$config\n";
    close $configFH;
eval $config;
die "Couldn't interpret the configuration file ($configFile) that was given.\nError details follow: $@\n" if $@;
my $fedoraURI = $ServerName . ":" . $ServerPort . "/" . $fedoraContext;

## calculate space used by collection PID
my $collectionFoxml = qx(curl -s -u ${UserName}:$PassWord -X GET "$fedoraURI/objects/$collectionPid/objectXML");      #print $collectionFoxml;

my $sizeCalc = q(
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:foxml="info:fedora/fedora-system:def/foxml#"
    exclude-result-prefixes="xs foxml"
    version="1.0">
<xsl:output method="xml" omit-xml-declaration="yes"/>
    <xsl:template match="/">
<!-- pid,sum,count -->
<xsl:value-of select="/foxml:digitalObject/@PID" /><xsl:call-template name="summary"></xsl:call-template></xsl:template><xsl:template name="summary">,<xsl:value-of select="sum(//foxml:datastreamVersion/@SIZE)" />,<xsl:value-of select="count(//foxml:datastreamVersion/@SIZE)" />
</xsl:template>
</xsl:stylesheet>
);

my $xml_parserCollection  = XML::LibXML->new;
my $xslt_parserCollection = XML::LibXSLT->new;

my $xmlCollection = $xml_parserCollection->parse_string($collectionFoxml);
my $xslCollection = $xml_parserCollection->parse_string($sizeCalc);
my $stylesheetCollection = $xslt_parserCollection->parse_stylesheet($xslCollection);
my $resultsCollection = $stylesheetCollection->transform($xmlCollection);
my $outputCollection = $stylesheetCollection->output_string($resultsCollection);

chomp $outputCollection;
#print "$outputCollection\n";       # uncomment for verbose report
my @runningTotal;
push( @runningTotal, $outputCollection );

my ( $nameSpace, $pidNumber ) = split( /:/, $collectionPid );
##  get members of collection from ITQL query
my $pidNumberCollectionSearchString = 'select $object from <#ri> where ($object <fedora-rels-ext:isMemberOf> <info:fedora/'
  . $nameSpace . ':' . $pidNumber
  . '> or $object <fedora-rels-ext:isMemberOfCollection> <info:fedora/'
  . $nameSpace . ':' . $pidNumber
  . '> ) minus $object <fedora-model:hasModel> <info:fedora/'
  . $nameSpace . ':' . $nameSpace
  . 'BasicCollection> order by $object ';
my $pidNumberCollectionSearchStringEncode = uri_escape($pidNumberCollectionSearchString);
my @pidNumberCollectionSearchStringEncodeCurlCommand =
 `curl -s '$fedoraURI/risearch?type=tuples&lang=itql&format=CSV&dt=on&query=$pidNumberCollectionSearchStringEncode'`;
my @pidsInCollection;
foreach my $line (@pidNumberCollectionSearchStringEncodeCurlCommand) {
    next if $line =~ m#^"object"#;
    chomp $line;
    $line =~ s#info:fedora/##g;
    $line =~ s#$nameSpace:##g;
    push( @pidsInCollection, $line );
}
my @sortedPidsInCollection = sort { $a <=> $b; } @pidsInCollection;

foreach my $line (@sortedPidsInCollection) {
    chomp $line;
    my $pid = $nameSpace . ":" . $line; #    print "$pid\n";
    my $foxml = qx(curl -s -u ${UserName}:$PassWord -X GET "$fedoraURI/objects/$pid/objectXML");
    my $xml_parser  = XML::LibXML->new;
    my $xslt_parser = XML::LibXSLT->new;

    my $xml        = $xml_parser->parse_string($foxml);
    my $xsl        = $xml_parser->parse_string($sizeCalc);
    my $stylesheet = $xslt_parser->parse_stylesheet($xsl);
    my $results    = $stylesheet->transform($xml);
    my $output     = $stylesheet->output_string($results);

    chomp $output;
#   print "$output\n";      # uncomment for verbose report
    push( @runningTotal, $output );
}
my ( $pidCounter, $sum, $countPid );
foreach my $line (@runningTotal) {
    my ( $pid, $size, $count ) = split( /,/, $line );
    $pidCounter++;
    $sum      = $sum + $size;
    $countPid = $countPid + $count;
}
print "\nCollection $collectionPid Totals\n\n  Fedora Objects: $pidCounter";
print "\n  Space Used: ";
   if ( $sum > 1024 * 1024 * 1024 * 1024 ) {
        my $humanSize = $sum / 1024 / 1024 / 1024 / 1024;
        my $rounded = sprintf "%.3f", $humanSize;  # rounded to 2 decimal places
        print "$rounded TB\n";
    }
    elsif ( $sum > 1024 * 1024 * 1024 ) {
        my $humanSize = $sum / 1024 / 1024 / 1024;
        my $rounded = sprintf "%.3f", $humanSize;  # rounded to 2 decimal places
        print "$rounded GB\n";
    }
    elsif ( $sum > 1024 * 1024 ) {
        my $humanSize = $sum / 1024 / 1024;
        my $rounded = sprintf "%.3f", $humanSize;  # rounded to 2 decimal places
        print "$rounded MB\n";
    }
    elsif ( $sum > 1024 ) {
        my $humanSize = $sum / 1024;
        my $rounded = sprintf "%.3f", $humanSize;  # rounded to 2 decimal places
        print "$rounded KB\n";
    }
    else {
        print "$sum bytes\n";
    }
print "  Number of Datastreams: $countPid\n";