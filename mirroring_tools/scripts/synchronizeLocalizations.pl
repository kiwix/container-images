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
my $logger = Log::Log4perl->get_logger("synchronizeLocalization.pl");

# get the params
my $masterLanguage;
my @languages;
my $allLanguages;
my $source;
my $rev;
my $username;
my $password;

## Get console line arguments
GetOptions(
    'masterLanguage=s' => \$masterLanguage,
    'language=s' => \@languages, 
    'allLanguages' => \$allLanguages,
    'username=s' => \$username,
    'password=s' => \$password,
    );

if (!$masterLanguage || !$username || !$password) {
    print "usage: ./synchronizeLocalizations.pl --masterLanguage=en-US --username=foo --password=bar [--language=en-US] [--allLanguages]\n";
    exit;
}

# Check if --allLanguages is not set if the user really want to synchronize all languages
if (!scalar(@languages) && !$allLanguages) {
    $allLanguages = query("getLocalization.pl will synchronize all Kiwix locales with '$masterLanguage'. Do you want to continue? (y/n)", "N");
    
    if ($allLanguages =~ /no/i) {
	exit;
    }
}

# Initiate the Mediawiki object
my $site = MediaWiki->new();
$site->logger($logger);
$site->hostname("www.kiwix.org");
$site->path("");
$site->user($username);
$site->password($password);
$site->setup();

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

# Get the masters
my ($masterDtdSource) = $site->downloadPage("Translation/languages/".$masterLanguage."/main.dtd");
my ($masterPropertiesSource) = $site->downloadPage("Translation/languages/".$masterLanguage."/main.properties");

# Update each language
foreach my $language (@languages) {

    # Update js properties
    my $languagePropertiesHash = getPropertiesHash($language);
    my $languagePropertiesSource = $masterPropertiesSource;
    while ($masterPropertiesSource =~ /^([^<].*?)(\=)(.*)$/mg ) {
	my $name = $1;
	my $middle = $2;
	my $value = $3;

	if (exists($languagePropertiesHash->{$name})) {
	    $value = $languagePropertiesHash->{$name};
	}

	$languagePropertiesSource =~ s/\Q$1$2$3\E/$name$middle$value/;
    }

    # Upload dtd
    $site->uploadPage("Translation/languages/".$language."/main.properties", $languagePropertiesSource, 
		      "synchronizeLocalization.pl update...");
    $logger->info("'Translation/languages/".$language."/main.properties' updated.");

    # Update dtd
    my $languageDtdHash = getDtdHash($language);
    my $languageDtdSource = $masterDtdSource;
    while ($masterDtdSource =~ /(!ENTITY[ |\t]+)(.*?)([ |\t]+\")(.*?)(\")/g ) {
	my $prefix = $1.$2.$3;
	my $postfix = $5;
	my $name = $2;
	my $value = $4;

	if (exists($languageDtdHash->{$name})) {
	    $value = $languageDtdHash->{$name};
	}

	$languageDtdSource =~ s/\Q$1$2$3$4$5\E/$prefix$value$postfix/;
    }

    # Upload dtd
    $site->uploadPage("Translation/languages/".$language."/main.dtd", $languageDtdSource, "synchronizeLocalization.pl update...");
    $logger->info("'Translation/languages/".$language."/main.dtd' updated.");
}

sub getDtdHash {
    my $language = shift;

    my ($source) = $site->downloadPage("Translation/languages/".$language."/main.dtd");
    my %languageHash;
    while ($source =~ /!ENTITY[ |\t]+(.*?)[ |\t]+\"(.*?)\"/g ) {
	$languageHash{$1} = $2;
    }

    return \%languageHash;
}

sub getPropertiesHash {
    my $language = shift;

    my ($source) = $site->downloadPage("Translation/languages/".$language."/main.properties");
    my %languageHash;
    while ($source =~ /^([^<].*?)\=(.*)$/mg ) {
	$languageHash{$1} = $2;
    }

    return \%languageHash;
}

exit;
