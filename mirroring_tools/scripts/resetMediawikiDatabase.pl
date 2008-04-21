#!/usr/bin/perl

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use DBI;
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

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'port=s' => \$port,
	   'database=s' => \$database,
	   'username=s' => \$username,
	   'password=s' => \$password
	   );

if (!$database || !$username || !$password ) {
    print "usage: ./resetMediawikiDatabase.pl --database=my_wiki_db [--username=my_user] [--password=my_password] [--host=localhost] [--port=3306]\n";
}

while (!$database) {
    $database = query("Database:", "");
}

while (!$username) {
    $username = query("Username:", "");
}

while (!$password) {
    $password = query("Password:", "");
}

# connection
my $dsn = "DBI:mysql:$database;host=$host:$port";
my $dbh;
my $req;
my $sth;

$dbh = DBI->connect($dsn, $username, $password) or die ("Unable to connect to the database.");

foreach my $table ("archive", "categorylinks", "externallinks", "filearchive", "hitcounter", "image", "imagelinks", "interwiki", "langlinks", "logging", "math", "objectcache", "oldimage", "oldimage", "redirect", "page", "pagelinks", "revision", "text", "recentchanges", "searchindex", "templatelinks") {
    $req = "TRUNCATE $table";
    $sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
}
