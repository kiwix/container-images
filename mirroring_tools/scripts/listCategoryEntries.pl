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
my $logger = Log::Log4perl->get_logger("listCategoryEntries.pl");

# get the params
my $host = "";
my $path = "";
my $category = "";
my $explorationDepth = 1;
my $namespace;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'category=s' => \$category,
	   'explorationDepth=s' => \$explorationDepth,
	   'namespace=s' => \$namespace,
	   );

if (!$host || !$category) {
    print "usage: ./listCategoryEntries.pl --host=my.wiki.org --category=mycat [--path=w] [--explorationDepth=1] [--namespace=0]\n";
    exit;
}

unless (Encode::is_utf8($category)) {
    $category = decode_utf8($category);
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);
my @entries = $site->listCategoryEntries($category, $explorationDepth, $namespace);

foreach my $entry (@entries) {
    $entry =~ s/ /_/g;
    print $entry."\n";
}

exit;
