#!/usr/bin/perl

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
my $logger = Log::Log4perl->get_logger("checkMediawikiPageCompleteness.pl");

# get the params
my $host = "";
my $path = "";
my @pages;
my $readFromStdin = 0;
my $checkAllPages = 0;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
           'readFromStdin' => \$readFromStdin,
           'checkAllPages' => \$checkAllPages,
           'page=s' => \@pages,
	   );

if (!$host) {
    print "usage: ./getIncompletePages.pl --host=my.wiki.org [--path=w] [--page=mypage] [--readFromStdin] [--checkAllPages]\n";
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

if ($checkAllPages || !scalar(@pages)) {
    $logger->info("Getting all pages for '$host'.");
    push(@pages, $site->allPages());
}

foreach my $page (@pages) {
    if ($site->isIncompletePage($page)) {
	$logger->info("Page '$page' is incomplete by '".$host."'.");
	print $page."\n";
    } else {
	$logger->info("Page '$page' is complete by '".$host."'.");
    }
}

exit;
