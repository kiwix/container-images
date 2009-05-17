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
my $logger = Log::Log4perl->get_logger("checkRedirects.pl");

# get the params
my $host = "";
my $path = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   );

if (!$host) {
    print "usage: ./checkRedirects.pl --host=my.wiki.org [--path=w]\n";
    exit;
}

my $site = MediaWiki->new();
$site->logger($logger);
$site->hostname($host);
$site->path($path);
$site->setup();

my @redirects = $site->allPages('0', "redirects"); 

my @targets;
my %redirects;
foreach my $redirect (@redirects) {
    # load content
    my $content = $site->downloadPage($redirect);

    # is redirect
    my $target = $site->isRedirectContent($content);

    if ($target) {
	push(@targets, $target);
	$redirects{$target} = $redirect;
    } else {
	$logger->error("Unable to find target in redirect content : '".$content."'");
    }
}

# check target existence
my %existences = $site->exists(@targets);

foreach my $existence (keys(%existences)) {
    unless ($existences{$existence}) {
	my $title = lcfirst($existence);
	$title =~ tr/ /_/;
	print $redirects{$title}."\n";
    }
}

exit;
