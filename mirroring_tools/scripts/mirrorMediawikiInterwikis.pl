#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use MediaWiki::InterwikiManager;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiInterwikis.pl");

# get the params
my $sourceHost = "";
my $sourcePath = "";

my $destinationHost = "localhost";
my $destinationPort = "3306";
my $destinationDatabase = "";
my $destinationUsername = "";
my $destinationPassword = "";

## Get console line arguments
GetOptions('sourceHost=s' => \$sourceHost, 
	   'sourcePath=s' => \$sourcePath,
	   'destinationHost=s' => \$destinationHost,
	   'destinationPort=s' => \$destinationPort,
	   'destinationDatabase=s' => \$destinationDatabase,
	   'destinationUsername=s' => \$destinationUsername,
	   'destinationPassword=s' => \$destinationPassword
	   );

print "usage: ./mirrorMediawikiInterwikis.pl --sourceHost=my.wiki.org --destinationDatabase [--sourcePath=w] [--destinationHost=localhost] [--destinationPort=3306] [--destinationUsername=tom] [--destinationPassword=fff]\n";

if (!$sourceHost || !$destinationDatabase) {
    exit;
}

while ($destinationUsername && !$destinationPassword) {
    $destinationPassword = query("Destination password:", "");
}

my $manager = MediaWiki::InterwikiManager->new();
$manager->logger($logger);
$manager->readFromWeb($sourceHost, $sourcePath);
$manager->writeToDatabase($destinationDatabase, $destinationUsername, $destinationPassword, $destinationHost, $destinationPort);

exit;
