#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use strict;
use warnings;
use Getopt::Long;

# get the params
my @languages;
my $allLanguages;
my $path;
my $source;

# Get console line arguments
GetOptions('path=s' => \$path,
	   'language=s' => \@languages,
	   'allLanguages' => \$allLanguages
	   );

if (!$path) {
    print STDERR "usage: ./KW2TW.pl --path=./ [--language=fr] [--allLanguages]\n";
    exit;
} elsif (! -d $path || ! -d $path."/kiwix/") {
    print STDERR "'$path' is not a directory, does not exist or is not the Kiwix source directory 'moulinkiwix'.\n";
    exit;
}

# Get all languages if necessary
if ($allLanguages) {
    opendir(DIR, $path."/kiwix/chrome/locale/") || die("Cannot open directory $path"); 
    foreach my $language (readdir(DIR)) {
	if ($language =~ '^[a-z]{2,3}(-[a-z]{2,10}|)$') {
	    push(@languages, $language);
	}
    }
}

# Generate TW file for each language
foreach my $language (@languages) {
    my $txt = "";
    my $mainDtdPath = $path."/kiwix/chrome/locale/".$language."/main/main.dtd";
    my $mainPropertiesPath = $path."/kiwix/chrome/locale/".$language."/main/main.properties";

    # Get main.dtd
    if (-f $mainDtdPath) {
	$source = readFile($mainDtdPath);
	while ($source =~ /\<\!ENTITY ([^ ]+)[ |\t]+"([^"]+)">/g) {
	    my $name = $1;
	    my $value = $2;
	    unless ($name eq "main.title") {
		$txt .= "ui.".$name."=".$value."\n";
	    }
	}
    }
    
    # Get main.properties
    if (-f $mainPropertiesPath) {
	$source = readFile($mainPropertiesPath);
	while ($source =~ /^([^=]+)=(.*)$/mg) {
	    my $name = $1;
	    my $value = $2;
	    $txt .= "ui.messages.".$name."=".$value."\n";
	}
    }

    # Write TW file
    writeFile($language, $txt);
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
