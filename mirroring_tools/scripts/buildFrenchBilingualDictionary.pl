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
my $logger = Log::Log4perl->get_logger("buildFrenchBilingualDictionary.pl");

# get the params
my $host = "fr.wiktionary.org";
my $path = "w";
my $category = "";
my $code = "";

# words
my @allFrenchWords;
my @allLangWords;
my @allEmbeddedIns;

# get console line arguments
GetOptions('code=s' => \$code, 
	   'category=s' => \$category);

if (!$code || !$category) {
    print "usage: ./buildFrenchBilingualDictionary.pl --code=ses --category=songhaï_koyraboro_senni\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

sub getAllFrenchWords() {
    @allFrenchWords = $site->listCategoryEntries("français", 1, "0");
}

sub getAllLangWords() {
    @allLangWords = $site->listCategoryEntries($category, 1, "0");
}

sub getAllEmbeddedIns() {
    @allEmbeddedIns = $site->embeddedIn("template:$code", "0");
}

#getAllFrenchWords();
getAllLangWords();
getAllEmbeddedIns();

foreach my $word (@allEmbeddedIns) {
    print $word."\n";
}

exit;
