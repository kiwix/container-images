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
my $logger = Log::Log4perl->get_logger("getLocalization.pl");

# get the params
my $code = "";
my $path = "./";
my $source;
my $rev;

## Get console line arguments
GetOptions('code=s' => \$code, 
	   'path=s' => \$path
	   );

if (!$code) {
    print "usage: ./getLocalization.pl --code=en-US --path=./\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname("www.kiwix.org");
$site->path("");
$site->logger($logger);

# create directory
unless ( -d $path."/".$code) { mkdir $path."/".$code; }
unless ( -d $path."/".$code."/main") { mkdir $path."/".$code."/main"; }
$path = $path."/".$code."/main/";

# get help.html
($source, $rev) = $site->downloadPage("Translation/languages/en-US/help.html");
$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
writeFile($path."help.html", $source);

# get main.dtd
($source, $rev) = $site->downloadPage("Translation/languages/en-US/main.dtd");
$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
writeFile($path."main.dtd", $source);

# get main.properties
($source, $rev) = $site->downloadPage("Translation/languages/en-US/main.properties");
$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
writeFile($path."main.properties", $source);

sub writeFile {
    my $file = shift;
    my $data = shift;

    open (FILE, ">$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $path = shift;
    my $data = "";

    open FILE, $path or die "Couldn't open file: $path";
    while (<FILE>) {
        $data .= $_;
    }
    close FILE;

    return $data;
}

exit;
