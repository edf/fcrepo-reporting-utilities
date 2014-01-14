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

#TODO report nested collection space used
#TODO 

my $collectionPid = $ARGV[0];
chomp $collectionPid;

## local settings to configure
#       variables of fedora server, port, username, and password
my $ServerName    = "http://fedora.coalliance.org";
my $ServerPort    = "8080";
my $fedoraContext = "fedora";
my $fedoraURI     = $ServerName . ":" . $ServerPort . "/" . $fedoraContext . "/objects";

my $UserName = "fedoraAdmin";
my $PassWord = 'PASSWORD';

## calculate space used by collection PID
my $collectionFoxml = qx(curl -s -u ${UserName}:$PassWord -X GET "$fedoraURI/$collectionPid/objectXML");      #print $collectionFoxml;

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
print "$outputCollection\n";
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
 `curl -s 'http://fedora.coalliance.org:8080/fedora/risearch?type=tuples&lang=itql&format=CSV&dt=on&query=$pidNumberCollectionSearchStringEncode'`;
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
    my $foxml = qx(curl -s -u ${UserName}:$PassWord -X GET "$fedoraURI/$pid/objectXML");
    my $xml_parser  = XML::LibXML->new;
    my $xslt_parser = XML::LibXSLT->new;

    my $xml        = $xml_parser->parse_string($foxml);
    my $xsl        = $xml_parser->parse_string($sizeCalc);
    my $stylesheet = $xslt_parser->parse_stylesheet($xsl);
    my $results    = $stylesheet->transform($xml);
    my $output     = $stylesheet->output_string($results);

    chomp $output;
    print "$output\n";
    push( @runningTotal, $output );
}
my ( $pidCounter, $sum, $countPid );
foreach my $line (@runningTotal) {
    my ( $pid, $size, $count ) = split( /,/, $line );
    $pidCounter++;
    $sum      = $sum + $size;
    $countPid = $countPid + $count;
}
print "\nTotal in Collection: $pidCounter";
print "\nTotal Collection Size: $sum";
print "\nTotal Collection Datastreams: $countPid\n";
