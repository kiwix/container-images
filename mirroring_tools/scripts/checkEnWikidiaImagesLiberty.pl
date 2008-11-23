#!/usr/bin/perl
binmode(STDOUT, ":utf8");

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
my $logger = Log::Log4perl->get_logger("checkEnWikidiaImagesLiberty.pl");

# get the params
my $readFromStdin;
my @images;

## Get console line arguments
GetOptions(
           'readFromStdin' => \$readFromStdin,
           'image=s' => \@images,
	   );

if (!scalar(@images) && !$readFromStdin) {
    print "usage: ./checkEnWikidiaImagesLiberty.pl [--image=my_image.png] [--readFromStdin]\n";
    exit;
}

if ($readFromStdin) {
    while (my $image = <STDIN>) {
	$image =~ s/\n//;
	push(@images, $image);
    }
}

my $site = MediaWiki->new();
$site->hostname("en.wikipedia.org");
$site->path("w");

# get all free under-category from the "free images root category"
my $freeImagesRootCategory = "";
my $maxExplorationDepth = 5;
my @categories = $site->getUnderCategories($freeImages, $maxExplorationDepth);

# load all images in theses categories
my @freeImages; 
foreach my $category (@categories) {
    
}

foreach my $image (@images) {
    print $image."\n";
}

exit;
