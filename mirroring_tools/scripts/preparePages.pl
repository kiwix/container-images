#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../";
use lib "../Mediawiki/";

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("preparePages.pl");

# get the params
my $host = "";
my $path = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path
	   );

if (!$host) {
    print "usage: ./preparePages.pl --host=my.wiki.org [--path=w]\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

foreach my $page ($site->allPages("0", "nonredirects")) {
    $site->preparePage($page);
}

exit;
