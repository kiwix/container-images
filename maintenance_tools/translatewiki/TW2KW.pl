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

# Duplicates, are responsible to find one tranlsation in differents
# files. The key, is the target
my $duplicates = {
    "ui.messages.browseLibrary" => "ui.main.browseLibrary",
    "ui.messages.hideLibrary" => "ui.main.hideLibrary",
    "ui.messages.fullscreen" => "ui.main.fullscreen",
    "android.ui.menu_openfile" => "ui.main.openFile",
    "android.ui.menu_back" => "ui.main.back",
    "android.ui.menu_fullscreen" => "ui.main.fullscreen",
    "android.ui.menu_exitfullscreen" => "ui.messages.quitFullscreen",
    "android.ui.menu_forward" => "ui.main.forward",
    "android.ui.menu_home" => "ui.main.home",
    "android.ui.menu_randomarticle" => "ui.main.randomArticle",
    "android.ui.menu_help" => "ui.main.help",
    "android.ui.save_media" => "ui.main.saveMediaAs",
    "android.ui.menu_search" => "ui.main.search",
    "android.ui.search_label" => "ui.main.search",
    "android.ui.menu_searchintext" => "ui.main.findInText",
    "android.ui.menu_settings" => "ui.preferences.preferences",
    "android.ui.pref_display_title" => "ui.main.display",
    "android.ui.pref_language_title" => "ui.main.language",
    "android.ui.pref_info_title" => "ui.messages.information",
    "android.ui.pref_zoom_dialog" => "android.ui.pref_zoom_title",
    "android.ui.menu_exit" => "ui.main.quit",
    "android.ui.menu_bookmarks" => "ui.main.bookmarks",
    "android.ui.add_bookmark" => "ui.main.mark",
    "android.ui.remove_bookmark" => "ui.main.unmark"
};

# Get console line arguments
GetOptions('path=s' => \$path,
	   'language=s' => \@languages, 
	   'allLanguages=s' => \$allLanguages,
	   'threshold=s' => \$threshold
	   );

if (!$path) {
    print STDERR "usage: ./TW2KW.pl --path=./ [--language=fr] [--allLanguages=[kw|tw]] [--threshold=$threshold]\n";
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

    # Create/Update Kiwix for desktop localisation
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

    # Create/Update Android xml file
    $localePath = $path."/android/res/values-".$language;
    if (length($language) <= 2 && ($languageTranslationCompletion > $threshold || -d $localePath)) {
	print STDERR "Creating locale file in $language for Kiwix for Android\n";

	my $androidHash = getLocaleHash($content, "android\.ui\.|");
	my $tmpLanguageAndroidSource = $languageAndroidSourceMaster;
	my $languageAndroidSource = $languageAndroidSourceMaster;
	
	while ($tmpLanguageAndroidSource =~ /<(string|item)([^\-]*?name=['|"])([^'|^"]+)(['|"][^>]*?>)(.*?)(<\/)(string|item)>/sg) {
	    my $tag = $1;
	    my $middle1 = $2;
	    my $name = $3;
	    my $middle2 = $4;
	    my $value = $5;
	    my $last = $6.$7;

	    if (exists($androidHash->{$name})) {
		$value = $androidHash->{$name};
		$value =~ s/'/\\'/gm;
	    } elsif (exists($duplicates->{"android.ui.".$name}) && 
		     exists($globalHash->{$duplicates->{"android.ui.".$name}})) {
		$value = $globalHash->{$duplicates->{"android.ui.".$name}};
		$value =~ s/'/\\'/gm;
	    }
	    
	    $languageAndroidSource =~ s/\Q$1$2$3$4$5$6$7\E/$tag$middle1$name$middle2$value$last/mg;
	}
	
	if (! -d $localePath) {
	    mkdir($localePath);
	}
	writeFile($localePath."/strings.xml", $languageAndroidSource);

	# Copy master branding file
	writeFile($localePath."/branding.xml", $languageBrandingAndroidSourceMaster);
    } else {
	print STDERR "Skipping locale file in $language for Kiwix for Android\n";
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
        $count += 1;
    }
    close FILE;

    return $count;

}

exit;
