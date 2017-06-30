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
my $allLanguages="";
my $threshold=90;
my $path;

# Duplicates, are responsible to find one translation in differents
# files. The key, is the target
my $duplicates = {
    "ui.messages.browseLibrary" => "ui.main.browseLibrary",
    "ui.messages.hideLibrary" => "ui.main.hideLibrary",
    "ui.messages.fullscreen" => "ui.main.fullscreen",
};

# Get console line arguments
GetOptions('path=s' => \$path,
	   'language=s' => \@languages, 
	   'allLanguages=s' => \$allLanguages,
	   'threshold=s' => \$threshold
	   );

if (!$path) {
    print STDERR "usage: ./TW2KW_xulrunner.pl --path=./ [--language=fr] [--allLanguages=[kw|tw]] [--threshold=$threshold]\n";
    exit;
} elsif (! -d $path || ! -d $path."/kiwix/") {
    print STDERR "'$path' is not a directory, does not exist or is not the Kiwix source directory 'moulinkiwix'.\n";
    exit;
}

# lowercase $allLanguages
$allLanguages = lc($allLanguages);

# Get all languages if necessary
if ($allLanguages eq "tw" || $allLanguages eq "kw") {
    if ($allLanguages eq "tw") {
	opendir(DIR, "./") || die("Cannot open directory."); 
    } else {
	opendir(DIR, $path."/kiwix/chrome/locale") || die("Cannot open directory."); 
    }
    foreach my $language (readdir(DIR)) {
	if ($language =~ '^[a-z]{2,3}(-[a-z]{2,10}|)$' && !($language eq "en")) {
	    push(@languages, $language);
	}
    }
}

# Initialize master files to use as template
my $languageMainDtdSourceMaster = readFile($path."/kiwix/chrome/locale/en/main/main.dtd");
my $languageMainPropertiesSourceMaster = readFile($path."/kiwix/chrome/locale/en/main/main.properties");
my $languageAndroidSourceMaster = readFile($path."/android/res/values/strings.xml");
my $languageBrandingAndroidSourceMaster = readFile($path."/android/res/values/branding.xml");
my $masterTranslationsCount = countLinesInFile("en");

# Update Kiwix locales
foreach my $language (@languages) {
    print STDERR "Doing $language...\n";

    # Check if this language should be done at all
    my $languageTranslationsCount = countLinesInFile($language);
    my $languageTranslationCompletion = int($languageTranslationsCount / $masterTranslationsCount * 100);
    print STDERR "Translation completion for $language is $languageTranslationCompletion% (threshold is $threshold)\n";

    # Get translation translatewiki content
    my $content = readFile($language);
    my $globalHash = getLocaleHash($content, "|");
    my $localePath = $path."/kiwix/chrome/locale/".$language."/main/";

    if ($languageTranslationCompletion > $threshold || -d $localePath) {
	print STDERR "Creating locale file in $language for Kiwix for desktop\n";

	# Create directory if necessary
	unless ( -d $path."/kiwix/chrome/locale/".$language) { mkdir $path."/kiwix/chrome/locale/".$language; }
	unless ( -d $path."/kiwix/chrome/locale/".$language."/main") { mkdir $path."/kiwix/chrome/locale/".$language."/main"; }
	unless ( -f $path."/kiwix/chrome/locale/".$language."/main/help.html") { writeFile($path."/kiwix/chrome/locale/".$language."/main/help.html", "") };
	
	# Update main dtd
	my $mainDtdHash = getLocaleHash($content, "ui\.|[^\.]+");
	
	my $languageMainDtdSource = $languageMainDtdSourceMaster;
	while ($languageMainDtdSourceMaster =~ /(!ENTITY[ |\t]+)(.*?)([ |\t]+\")(.*?)(\")/g ) {
	    my $prefix = $1.$2.$3;
	    my $postfix = $5;
	    my $name = $2;
	    my $value = $4;
	    
	    if (exists($mainDtdHash->{$name})) {
		$value = $mainDtdHash->{$name};
	    } elsif (exists($duplicates->{"ui.".$name}) && 
		     exists($globalHash->{$duplicates->{"ui.".$name}})) {
		$value = $globalHash->{$duplicates->{"ui.".$name}};
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
	    } elsif (exists($duplicates->{"ui.messages.".$name}) && 
		     exists($globalHash->{$duplicates->{"ui.messages.".$name}})) {
		$value = $globalHash->{$duplicates->{"ui.messages.".$name}};
	    }
	    
	    $languageMainPropertiesSource =~ s/\Q$1$2$3\E/$name$middle$value/;
	}
	writeFile($localePath."main.properties", $languageMainPropertiesSource);
    } else {
	print STDERR "Skipping locale file in $language for Kiwix for desktop\n";
    }
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

sub countLinesInFile {
    my $path = shift;
    my $count = 0;
    
    open FILE, "<:utf8", $path or die "Couldn't open file: $path";
    while (<FILE>) {
	if ($_ !~ ".accesskey" && $_ !~ "android.ui") {
	    $count += 1;
	}
    }
    close FILE;

    return $count;

}

exit;
