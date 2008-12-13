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
my $logger = Log::Log4perl->get_logger("listAllPages.pl");

# get the params
my $host = "";
my $path = "";
my $namespace;
my $filter = "all";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'filter=s' => \$filter,
	   'namespace=s' => \$namespace
	   );

if (!$host || !($filter eq "all" || $filter eq "nonredirects" || $filter eq "redirects")) {
    print "usage: ./listAllPages.pl --host=my.wiki.org [--path=w] [--namespace=0] [--filter=[all|redirects|nonredirects]]\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);

foreach my $page ($site->allPages($namespace, $filter)) {
    print $page."\n";
}

exit;
