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
my $logger = Log::Log4perl->get_logger("backupMediawikiInstall.pl");

# get the params
my $database = "";
my $directory = "";
my $databaseUsername = "";
my $databasePassword = "";
my $outputFile = "";

## Get console line arguments
GetOptions('database=s' => \$database, 
	   'directory=s' => \$directory,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
	   'outputFile=s' => \$outputFile,
	   );

if (!$database || !$databaseUsername || !$databasePassword || !$directory || !$outputFile) {
    print "usage: ./backupMediawikiInstall.pl --directory=/var/www/mediawiki --database=mediawiki --databaseUsername=root --databasePassword=foobar --outputFile=mybackup.tar.bz2\n";
    exit;
}

## make tmp directory
my $tmpDirectory = "/tmp/backup_mediawiki_".time()."/";
`mkdir $tmpDirectory`;

## copy the mediawiki directory
`cp -r $directory $tmpDirectory`;

## make the mysql dump
`mysqldump --add-drop-database -u $databaseUsername -p$databasePassword --databases $database > $tmpDirectory$database.sql`;

## make a tar.bz
`tar -cvjf $outputFile $tmpDirectory`;

## remove the tmp directory
`rm -rf $tmpDirectory`;

exit;
