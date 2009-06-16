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

my $databaseHost = "localhost";
my $databasePort = "3306";
my $databaseName = "";
my $databaseUsername = "";
my $databasePassword = "";

## Get console line arguments
GetOptions('sourceHost=s' => \$sourceHost, 
	   'sourcePath=s' => \$sourcePath,
	   'databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databaseName=s' => \$databaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword
	   );

if (!$sourceHost || !$databaseName) {
    print "usage: ./mirrorMediawikiInterwikis.pl --sourceHost=my.wiki.org --databaseName=MYDB [--sourcePath=w] [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff]\n";
    exit;
}

if ($databaseUsername && !$databasePassword) {
    $databasePassword = query("Database password:", "");
}

my $manager = MediaWiki::InterwikiManager->new();
$manager->logger($logger);
$manager->readFromWeb($sourceHost, $sourcePath);
$manager->writeToDatabase($databaseName, $databaseUsername, $databasePassword, $databaseHost, $databasePort);

exit;
