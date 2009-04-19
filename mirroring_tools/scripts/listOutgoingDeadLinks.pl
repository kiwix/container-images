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
my $logger = Log::Log4perl->get_logger("listOutgoingDeadLinks.pl");

# get the params
my $host = "";
my $path = "";
my @pages;
my $readFromStdin = 0;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
	   );

if (!$host) {
    print "usage: ./listOutgoingDeadLinks.pl --host=my.wiki.org [--path=w] [--page=mypage] [--readFromStdin]\n";
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

foreach my $page (@pages) {

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    my %links = $site->exists($site->getOutgoingLinks($page));

    foreach my $link (keys(%links)) {
	unless ($links{$link}) {
	    $link =~ tr/ /_/s;
	    print $link."\n";
	}
    }
};

exit;
