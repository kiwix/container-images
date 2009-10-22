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
my $logger = Log::Log4perl->get_logger("checkPageExistence.pl");

# get the params
my $host = "";
my $path = "";
my $readFromStdin;
my @pages;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
	   );

if (!$host) {
    print "usage: ./checkPageExistence --host=my.wiki.org --page=[my_page] [--path=w] [--readFromStdin]\n";
    exit;
}

if ($readFromStdin) {
    while (my $page = <STDIN>) {
	$page =~ s/\n//;
	push(@pages, $page);
    }
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);


my %pages = $site->exists(@pages);

foreach my $page (keys(%pages)) {
    if ($pages{$page}) {
	$page =~ tr/ /_/;
	print $page."\n";
    }
}

exit;
