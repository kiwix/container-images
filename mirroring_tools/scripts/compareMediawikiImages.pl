#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;

use lib "../";
use lib "../Mediawiki/";

use Encode;
use strict;
use warnings;
use Getopt::Long;
use MediaWiki::Mirror;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# get the params
my $firstHost;
my $firstPath;
my $secondHost;
my $secondPath;

my @images;
my $readFromStdin = 0;
my $noLog = 0;

## Get console line arguments
GetOptions(
	   'firstHost=s' => \$firstHost, 
           'firstPath=s' => \$firstPath,
	   'secondHost=s' => \$secondHost, 
           'secondPath=s' => \$secondPath,
           'readFromStdin' => \$readFromStdin,
           'image=s' => \@images,
           'noLog' => \$noLog,
           );

if (!$firstHost || !$secondHost ) {
    print "Usage: compareMediawikiImages.pl --firstHost=[host] --secondHost=[host] [--image=myimg.png] [--readFromStdin] [--firstPath=w] [--secondPath=w]\n\n";
    exit;
}

if ($readFromStdin) {
    while (my $image = <STDIN>) {
	$image =~ s/\n//;
	push(@images, $image);
    }
}

# log
my $logger;
unless ($noLog) {
    use Log::Log4perl;
    Log::Log4perl->init("../conf/log4perl");
    $logger = Log::Log4perl->get_logger("mirrorMediawikiImages.pl");
}

# mediawiki instances
my $firstSite = MediaWiki->new();
$firstSite->hostname($firstHost);
$firstSite->path($firstPath);

my $secondSite = MediaWiki->new();
$secondSite->hostname($secondHost);
$secondSite->path($secondPath);

# if no image is given get all of the first Mediawiki images
unless (scalar(@images)) {
    unless ($noLog) {
	$logger->info("Getting all images from $firstHost.");
    }
    @images = $firstSite->allImages();
}

# compare images
unless ($noLog) {
    $logger->info("Compare images.");
}
foreach my $image (@images) {
    my $firstSize = $firstSite->getImageSize($image);
    my $secondSize = $secondSite->getImageSize($image);

    if (defined($firstSize) && defined($secondSize) && $firstSize == $secondSize) {
	unless ($noLog) {
	    $logger->info("image '$image' in both Mediawikis.");
	}

	unless ($image =~ /^file:/i) {
	    $image = "File:".$image;
	}
	print $image."\n";
    } else {
	unless ($noLog) {
	    $logger->info("image '$image' differences: '".($firstSize || "undefined")."' in first and '".($secondSize || "undefined")."' in second Mediawiki.");
	}
    }
}

exit;
