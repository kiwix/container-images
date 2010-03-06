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
use List::Compare;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("buildFrenchBilingualDictionary.pl");

# get the params
my $host = "fr.wiktionary.org";
my $path = "w";
my $category = "";
my $code = "";
my $allFrenchWordsFile = "";

# words
my $allFrenchWords;
my $allLangWords;
my $allEmbeddedIns;
my $frenchWords;
my $langWords;
my %frenchDictionary;
my %langDictionary;

# get console line arguments
GetOptions('code=s' => \$code, 
	   'category=s' => \$category,
	   'allFrenchWordsFile=s' => \$allFrenchWordsFile
    );

if (!$code || !$category) {
    print "usage: ./buildFrenchBilingualDictionary.pl --code=ses --category=songhaï_koyraboro_senni [--allFrenchWordsFile=file.lst]\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

sub getAllFrenchWords() {
    $allFrenchWords = [$site->listCategoryEntries("français", 1, "0")];
}

sub getAllLangWords() {
    $allLangWords = [$site->listCategoryEntries($category, 1, "0")];
}

sub getAllEmbeddedIns() {
    $allEmbeddedIns = [$site->embeddedIn("template:$code", "0")];
}

sub read_file {
    my $file = shift;
    my @list;
 
    open(FILE, '<:utf8', $file);
    while (my $page = <FILE>) {
	$page =~ s/\n//;
	push(@list, $page);
    }
 
    return \@list;
}

sub getFrenchWords() {
    my $lc = List::Compare->new(
	$allFrenchWords, 
	$allEmbeddedIns
	);
    $frenchWords = [$lc->get_intersection()];
}

sub getLangWords() {
    my $lc = List::Compare->new(
	$allLangWords, 
	$allEmbeddedIns
	);
    $langWords = [$lc->get_intersection()];
}

sub extractTranslationsFromWikiCode {
    my $code = shift;
    my $lang = shift;
    my @translations;

    while ($code =~ /\{\{trad[\+|\-|]\|$lang\|([^\}]*)\}\}/ig ) {
	push (@translations, $1);
    }

    return \@translations;
}

sub buildFrenchDictionary() {
    foreach my $frenchWord (@$frenchWords) {
	my ($content, $revision) = $site->downloadPage($frenchWord);
	
	# Get the "French" paragraph
	if ($content =~ /(.*\=\=\ \{\{\=fr\=\}\}\ \=\=)(.*?)(\=\=\ \{\{\=|$)/s ) {
	    $content = $2;
	} else {
	    next;
	}

	my %translations;
	my $langWords;

	# Go through all translations
	while ($content =~ /{{boîte[_|\ ]début\|(.*?)}}(.*?){{boîte[_|\ ]fin}}/sgi ) {
	    my $frenchWordDerivate = $1;
	    my $subContent = $2;
	    $langWords = extractTranslationsFromWikiCode($subContent, $code);
	    if (scalar(@$langWords)) {
		$translations{$frenchWordDerivate} = $langWords;
	    }
	}
	
	# If no derivates, try to find the "simple" translation
	unless (scalar(keys(%translations))) {
	    $langWords = extractTranslationsFromWikiCode($content, $code);
	    if (scalar(@$langWords)) {
		$translations{$frenchWord} = $langWords;
	    }
	}

	# Save the translations
	if (scalar(keys(%translations))) {
	    $frenchDictionary{$frenchWord} = { "translations" => \%translations };
	}

    }
}

if ($allFrenchWordsFile) {
    $allFrenchWords = read_file($allFrenchWordsFile);
} else {
    getAllFrenchWords();
}

getAllLangWords();
getAllEmbeddedIns();
getFrenchWords();
getLangWords();
#$frenchWords = [("chat")];
buildFrenchDictionary();

print Dumper(%frenchDictionary);

exit;

