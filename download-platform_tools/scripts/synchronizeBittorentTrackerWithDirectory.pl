#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use lib "../../dumping_tools/classes/";

use utf8;
use Encode;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use XML::Simple;
use Kiwix::PathExplorer;

my $mod_btHome = '/var/lib/mod_bt';
my $torrentsHome = $mod_btHome."/torrents/";

# get the params
my $contentPath;
my $trackerUrl;

## Get console line arguments
GetOptions(
	   'contentPath=s' => \$contentPath, 
	   'trackerUrl=s' => \$trackerUrl, 
           );

if (!$contentPath || !$trackerUrl) {
    print "Usage: synchronizeBittorentTrackerWithDirectory.pl --contentPath=/var/www/download --trackerUrl=http://bt.kiwix.org:80\n";
    exit;
}

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("synchronizeBittorentTrackerWithDirectory.pl");

# load curent status
my $currentXml = `btt_db2xml $mod_btHome`;
my $currentXmlHash = XMLin($currentXml, ForceArray => ['Infohash']);
my %trackerHash; map( $trackerHash{$_->{'Filename'}} = $_, @{$currentXmlHash->{Infohash}});

# load files in $contentPath
my %files;
my $explorer = new Kiwix::PathExplorer();
$explorer->path($contentPath);

while (my $filePath = $explorer->getNext()) {

    # check size
    my $fileSize = -s $filePath;
    
    # push if necessary
    if ($fileSize > 42000) {

	my @chunks = split( /\//, $filePath);
	my $fileName = $chunks[scalar(@chunks)-1];
	$files{$fileName} = $filePath;
    }
}

# generate the torrent files if necessary
foreach my $file (keys(%files)) {
    my $torrentFilePath = $torrentsHome."/".$file.".torrent";
    my $filePath = $files{$file};

    unless (-f $torrentFilePath) {
	my $cmd = "btmakemetafile $filePath ".$trackerUrl."/announce --target $torrentFilePath";
	`$cmd`;
    }
}

# announce/register if necessary
$explorer->reset();
$explorer->path($torrentsHome);

while (my $torrentFilePath = $explorer->getNext()) {

    # et filename
    my @chunks = split( /\//, $torrentFilePath);
    my $fileName = $chunks[scalar(@chunks)-1];
    $fileName =~ s/\.torrent// ;

    # next if already in the tracker
    next
	if (exists($trackerHash{$fileName}));

    # announce and register if necessary
    my $cmd = "btt_infohash $mod_btHome --create --register 1 --metainfo $torrentFilePath";
    `$cmd`;
}

# delete not registered hash
foreach my $trackerFile (keys(%trackerHash)) {
    unless ($trackerHash{$trackerFile}->{'RegisterT'}) {
	my $trackerId = $trackerHash{$trackerFile}->{'ID'};
	my $cmd = "btt_infohash $mod_btHome --delete $trackerId";
	`$cmd`;                                                                                
    }
}



exit;
