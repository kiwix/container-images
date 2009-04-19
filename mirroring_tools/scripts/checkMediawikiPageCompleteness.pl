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
use Encode;

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
my $printDependences = 0;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
           'readFromStdin' => \$readFromStdin,
           'checkAllPages' => \$checkAllPages,
           'printDependences' => \$printDependences,
           'page=s' => \@pages,
	   );

if (!$host) {
    print "usage: ./getIncompletePages.pl --host=my.wiki.org [--path=w] [--page=mypage] [--readFromStdin] [--checkAllPages] [--printDependences]\n";
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

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    if ($printDependences) {
	foreach my $page ($site->getFailingDependences($page)) {
	    $logger->info("Page '$page' is incomplete by '".$host."'.");
	    print $page."\n";
	}
    } else {
	if ($site->isIncompletePage($page)) {
	} else {
	    $logger->info("Page '$page' is complete by '".$host."'.");
	}
    }
}

exit;
