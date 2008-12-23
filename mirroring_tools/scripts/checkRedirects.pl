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
$site->hostname($host);
$site->path($path);
$site->setup();

my @redirects = $site->allPages('0', "redirects"); 

sub isRedirectContent {
    my $content = shift;

    if ( $content =~ /\#REDIRECT[ ]*\[\[[ ]*(.*)[ ]*\]\]/i ) {
	my $title = $1;
	$title =~ tr/ /_/;
	$title = lcfirst($title);
	return $title;
    }
    return "";
}

my @targets;
foreach my $redirect (@redirects) {

    # load content
    my $content = $site->downloadPage($redirect);

    # is redirect
    my $target = isRedirectContent($content);

    if ($target) {
	push(@targets, $target);
    }
}

# check target existence
my %existences = $site->exists(@targets);

foreach my $existence (keys(%existences)) {
    unless ($existences{$existence}) {
	print $existence."\n";
    }
}

exit;
