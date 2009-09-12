#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("listAllImages.pl");

# get the params
my $host = "";
my $path = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path
	   );

if (!$host) {
    print "usage: ./listAllImages.pl --host=my.wiki.org [--path=w]\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

foreach my $image ($site->allImages()) {
    print "File:".$image."\n";
}

exit;
