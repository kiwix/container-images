#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use MediaWiki::Reset;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("resetMediawikiDatabase.pl");

# get the params
my $host = "127.0.0.1";
my $port = "3306";
my $database = "";
my $username = "";
my $password = "";
my $keepImages;
my $dropDatabase;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'port=s' => \$port,
	   'database=s' => \$database,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   'dropDatabase' => \$dropDatabase,
	   'keepImages' => \$keepImages
	   );

if (!$database || !$username ) {
    print "usage: ./resetMediawikiDatabase.pl --database=my_wiki_db [--username=my_user] [--password=my_password] [--host=localhost] [--port=3306] [--dropDatabase] [--keepImages]\n";
}

if (!$username) {
    $username = query("Username:", "");
}

if (!$password) {
    $password = query("Password:", "");
}

my $reset = MediaWiki::Reset->new();
$reset->logger($logger);
$reset->host($host);
$reset->port($port);
$reset->database($database);
$reset->username($username);
$reset->password($password);
$reset->keepImages($keepImages);

if ($dropDatabase) {
    $reset->drop();
} else {
    $reset->reset();
}
