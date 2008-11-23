#!/usr/bin/perl
binmode(STDOUT, ":utf8");
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
my $logger = Log::Log4perl->get_logger("listRedirects.pl");

# get the params
my $host = "";
my $path = "";
my $page;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'page=s' => \$page
	   );

if (!$host || !$page) {
    print "usage: ./listRedirects.pl --host=my.wiki.org --page=Rouen [--path=w]\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->setup();

foreach my $page ($site->redirects($page)) {
    print $page."\n";
}

exit;
