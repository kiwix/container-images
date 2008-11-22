#!/usr/bin/perl
binmode STDOUT, ":utf8";

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use XML::Parser;
#use Search::Tools::XML;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("extractContributorsFromHistoryFile.pl");


# get the params
my $file = "";
my $bzip2 = "";
my $ignoreIps;
#my $xmlTool = Search::Tools::XML->new();

## Get console line arguments
GetOptions('file=s' => \$file,
           'bzip2' => \$bzip2,
	   'ignoreIps' => \$ignoreIps
    );


if (!$file) {
    print "usage: ./extractContributorsFromHistoryFile.pl [--bzip2] [--ignoreIps] --file=my_file\n";
    exit;
}

$logger->info("=======================================================");
$logger->info("= Start contributors extracting =======================");
$logger->info("=======================================================");

my %contributors;

sub handleStart {
    my ($parser, $tag, %attributes) = @_;
    if ($tag eq "rev") {
	$contributors{$attributes{user}} = 1;
    }
}

my $parser = new XML::Parser(Handlers => {Start => \&handleStart});
$parser->parsefile($file, ProtocolEncoding => "UTF-8");

delete($contributors{"MediaWiki default"});

foreach my $contributor (keys(%contributors)) {

    if ($ignoreIps) {
	next if ($contributor =~ /^[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}\.[\d]{1,3}$/);
    }

#    print $xmlTool->unescape($contributor)."\n";
    print $contributor."\n";
}

$logger->info("=======================================================");
$logger->info("= Stop Contributor extracting =========================");
$logger->info("=======================================================");

exit;
