#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

# get the params
my @languages;
my $allLanguages;
my $path;

# Get console line arguments
GetOptions('path=s' => \$path,
	   'language=s' => \@languages, 
	   'allLanguages=s' => \$allLanguages
	   );

if (!$path) {
    print STDERR "usage: ./TW2KW.pl --path=./ [--language=fr] [--allLanguages=[kw|tw]]\n";
    exit;
} elsif (! -d $path || ! -d $path."/kiwix/") {
    print STDERR "'$path' is not a directory, does not exist or is not the Kiwix source directory 'moulinkiwix'.\n";
    exit;
}

# Get all languages if necessary
if ($allLanguages eq "tw" || $allLanguages eq "kw") {
    if ($allLanguages eq "kw") {
	opendir(DIR, "./") || die("Cannot open directory."); 
    } else {
	opendir(DIR, $path."/kiwix/chrome/locale") || die("Cannot open directory."); 
    }
    foreach my $language (readdir(DIR)) {
	if ($language =~ '^[a-z]{2}$' && !($language eq "en")) {
	    push(@languages, $language);
	}
    }
}

# Initialize master files to use as template
my $languageMainDtdSourceMaster = readFile($path."/kiwix/chrome/locale/en/main/main.dtd");
my $languageMainPropertiesSourceMaster = readFile($path."/kiwix/chrome/locale/en/main/main.properties");

# Update Kiwix locales
foreach my $language (@languages) {
    my $localePath = $path."/kiwix/chrome/locale/".$language."/main/";

    # Create directory if necessary
    unless ( -d $path."/kiwix/chrome/locale/".$language) { mkdir $path."/kiwix/chrome/locale/".$language; }
    unless ( -d $path."/kiwix/chrome/locale/".$language."/main") { mkdir $path."/kiwix/chrome/locale/".$language."/main"; }
    unless ( -f $path."/kiwix/chrome/locale/".$language."/main/help.html") { writeFile($path."/kiwix/chrome/locale/".$language."/main/help.html", "") };

    # Get translation translatewiki content
    my $content = readFile($language);

    # Update main dtd
    my $mainDtdHash = getLocaleHash($content, "ui\.|main");
    my $languageMainDtdSource = $languageMainDtdSourceMaster;
    while ($languageMainDtdSourceMaster =~ /(!ENTITY[ |\t]+)(.*?)([ |\t]+\")(.*?)(\")/g ) {
	my $prefix = $1.$2.$3;
	my $postfix = $5;
	my $name = $2;
	my $value = $4;

	if (exists($mainDtdHash->{$name})) {
	    $value = $mainDtdHash->{$name};
	}

	$languageMainDtdSource =~ s/\Q$1$2$3$4$5\E/$prefix$value$postfix/;
    }
    writeFile($localePath."main.dtd", $languageMainDtdSource);

    # Update js properties file
    my $mainPropertiesHash = getLocaleHash($content, "ui\.messages\.|");
    my $languageMainPropertiesSource = $languageMainPropertiesSourceMaster;

    while ($languageMainPropertiesSourceMaster =~ /^([^<].*?)(\=)(.*)$/mg) {
	my $name = $1;
	my $middle = $2;
	my $value = $3;
	
	if (exists($mainPropertiesHash->{$name})) {
	    $value = $mainPropertiesHash->{$name};
	}
	
	$languageMainPropertiesSource =~ s/\Q$1$2$3\E/$name$middle$value/;
    }
    writeFile($localePath."main.properties", $languageMainPropertiesSource);
}

sub getLocaleHash {
    my $content = shift;
    my ($prefixEx, $prefixInc) = split(/\|/, shift);

    my %translationHash;
    while ($content =~ /$prefixEx($prefixInc.*)=(.*)/g ) {
	$translationHash{$1} = $2;
    }

    return \%translationHash;
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
