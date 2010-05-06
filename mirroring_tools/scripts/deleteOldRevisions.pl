#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use MediaWiki::RevisionManager;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("deleteOldRevisions.pl");

# get the params
my $host = "localhost";
my $port = "3306";
my $database = "";
my $username = "";
my $password = "";
my $mediawikiDirectory="";

## Get console line arguments
GetOptions('host=s' => \$host,
	   'port=s' => \$port,
	   'database=s' => \$database,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   'mediawikiDirectory=s' => \$mediawikiDirectory,	   
	   );

if (!$database || !$mediawikiDirectory) {
    print "usage: ./deleteOldRevisions.pl --database=MYDB --mediawikiDirectory=/var/www/wiki/ [--host=localhost] [--port=3306] [--username=tom] [--password=fff]\n";
    exit;
}

if ($username && !$password) {
    $password = query("Database password:", "");
}

my $manager = MediaWiki::RevisionManager->new();
$manager->logger($logger);
$manager->database($database);
$manager->username($username);
$manager->password($password);
$manager->host($host);
$manager->port($port);
$manager->password($password);
$manager->mediawikiDirectory($mediawikiDirectory);
$manager->connectToDatabase();
$manager->deleteOldRevisions();
$manager->deleteOldImages();
$manager->deleteOrphanTexts();
$manager->deleteOrphanFiles();
$manager->deleteRemovedFiles();

exit;
