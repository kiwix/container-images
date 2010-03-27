#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../";
use lib "../Mediawiki/";

use Encode;
use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("getGeoLocation.pl");

# get the params
my $host = "";
my $path = "";
my @pages;
my $readFromStdin;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'readFromStdin' => \$readFromStdin,
	   'page=s' => \@pages,
	   );

if (!$host || ( !scalar(@pages) && !$readFromStdin) ) {
    print "usage: ./getGeoLocation.pl --host=my.wiki.org [--page=mypage] [--readFromStdin] [--path=w]\n";
    exit;
}

# readFromStdin
if ($readFromStdin) {
    $logger->info("Read pages from stdin.");
    while (my $page = <STDIN>) {
        $page =~ s/\n//;
        push(@pages, $page);
    }
}

# Site
my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

# Go over the page list
foreach my $page (@pages) {

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    my ($content, $revid) = $site->downloadPage($page);
    my $longitude = "";
    my $latitude = "";

    if ($content =~ /latitude[\ |\t]*=[\ |\t]*([\d|\/|\.|\-|w|e|n|s]+)/i ) {
	$latitude=$1;
    }

    if ($content =~ /longitude[\ |\t]*=[\ |\t]*([\d|\/|\.|\-|w|e|n|s]+)/i ) {
	$longitude=$1;
    }

    print $page.";".$longitude.";".$latitude."\n";
}

exit;
