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
my $source;

# Get console line arguments
GetOptions(
    'path=s' => \$path,
    'language=s' => \@languages,
    'allLanguages' => \$allLanguages
    );

if (!$path) {
    print STDERR "usage: ./KW2TW_android.pl --path=./ [--language=fr] [--allLanguages]\n";
    exit;
} elsif (! -d $path || ! -d $path."/app/src/main/res") {
    print STDERR "'$path' does not exists or is not a kiwix-android directory.\n";
    exit;
}

# Get all languages if necessary
if ($allLanguages) {
    opendir(DIR, $path."/app/src/main/res") || die("Cannot open directory.");
    foreach my $language (readdir(DIR)) {
        if ($language =~ '^values-([a-z]{2,3})$') {
            push(@languages, $1);
        }
    }
}

# Generate TW file for each language
foreach my $language (@languages) {
    my $txt = "";
    my $mainPath = $path."/app/src/main/res/values/strings.xml";

    # Put everything which is not android in
    my $old = readFile($language) || "";
    for (split(/^/, $old)) {
        if ($_ !~ /^android\.ui/sg) {
            my $line = $_;
            $txt .= $line =~ /\n$/ ? $line : $line . "\n";
        }
    }

    $source = readFile($mainPath);
    while ($source =~ /<(string|item)([^\-]*?name=['|"])([^'|^"]+)(['|"][^>]*?>)(.*?)(<\/)(string|item)>/sg) {
        my $tag = $1;
        my $middle1 = $2;
        my $name = $3;
        my $middle2 = $4;
        my $value = $5;
        my $last = $6.$7;

        $txt .= "android.ui.$name=$value\n";
    }

    # Sort entries
    $txt = join("\n", sort(split( /\n/, $txt)));

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
