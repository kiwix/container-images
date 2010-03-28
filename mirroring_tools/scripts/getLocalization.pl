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
use Term::Query qw(query);

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("getLocalization.pl");

# get the params
my @languages;
my $allLanguages;
my $path;
my $source;
my $rev;

## Get console line arguments
GetOptions('language=s' => \@languages, 
	   'path=s' => \$path,
	   'allLanguages' => \$allLanguages
	   );

if (!$path) {
    print "usage: ./getLocalization.pl --path=./ [--language=en-US] [--allLanguages]\n";
    exit;
} elsif (! -d $path) {
    print "'$path' is not a directory or does not exist.\n";
    exit;
}

# Check if --allLanguages is not set if the user really want to mirror all languages
if (!scalar(@languages) && !$allLanguages) {
    $allLanguages = query("getLocalization.pl will download all Kiwix locales in directory '$path'. Do you want to continue? (y/n)", "N");
    
    if ($allLanguages =~ /no/i) {
	exit;
    }
}

# Initiate the Mediawiki object
my $site = MediaWiki->new();
$site->hostname("www.kiwix.org");
$site->path("");
$site->logger($logger);

# Get all languages if necessary
if (!scalar(@languages) || $allLanguages) {
    my @embeddedIns = $site->embeddedIn("template:Language_translation", 0);
    foreach my $embeddedIn (@embeddedIns) {
	if ($embeddedIn =~ /Translation\/languages\/(.*)/ ) {
	    my $language = $1;
	    push(@languages, $language);
	}
    }
}

# Get all languages
foreach my $language (@languages) {

    $logger->info("Getting locale '$language'.");
    
    # create directory
    unless ( -d $path."/".$language) { mkdir $path."/".$language; }
    unless ( -d $path."/".$language."/main") { mkdir $path."/".$language."/main"; }
    my $localePath = $path."/".$language."/main/";
    
    # get help.html
    ($source) = $site->downloadPage("Translation/languages/".$language."/help.html");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	writeFile($localePath."help.html", $source);
    }
    
    # get main.dtd
    ($source) = $site->downloadPage("Translation/languages/".$language."/main.dtd");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	writeFile($localePath."main.dtd", $source);
    }
    
    # get main.properties
    ($source) = $site->downloadPage("Translation/languages/".$language."/main.properties");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	writeFile($localePath."main.properties", $source);
    }
}

sub writeFile {
    my $file = shift;
	my $data = shift;
    
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $path = shift;
    my $data = "";

    open FILE, "<:utf8", $path or die "Couldn't open file: $path";
    while (<FILE>) {
        $data .= $_;
    }
    close FILE;

    return $data;
}

exit;
