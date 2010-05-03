#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );
use DBI;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiWmfDumps.pl");

# get the params
my $databaseHost = "localhost";
my $databasePort = "3306";
my $databaseName = "";
my $databaseUsername = "";
my $databasePassword = "";
my $projectCode = "";
my $tmpDir = "/tmp";
my $cmd;

## Get console line arguments
GetOptions('databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databaseName=s' => \$databaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
	   'projectCode=s' => \$projectCode,
	   'tmpDir=s' => \$tmpDir,
	   );

if (!$databaseName || !$projectCode) {
    print "usage: ./mirrorWmfDumps.pl --projectCode=enwiki --databaseName=MYDB [--tmpDir=/tmp] [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff]\n";
    exit;
}

if ($databaseUsername && !$databasePassword) {
    $databasePassword = query("Database password:", "");
}

# Create temporary directory
$tmpDir = $tmpDir."/wmfDumps";
`mkdir $tmpDir`;

# Download the XML & SQL files
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-pages-articles.xml.bz2"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-interwiki.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-imagelinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-image.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-pagelinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-redirect.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-templatelinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-externallinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-categorylinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/latest/$projectCode-latest-category.sql.gz"; `$cmd`;

# Install and compile the mwdumper
my $mwDumperDir = $tmpDir."/mwdumper/";
unless (-d $mwDumperDir) {
    $cmd = "cd $tmpDir; svn co http://svn.wikimedia.org/svnroot/mediawiki/trunk/mwdumper/"; `$cmd`;
    $cmd = "cd $mwDumperDir/src; javac org/mediawiki/dumper/Dumper.java"; `$cmd`; 
}

# Prepare DB connection
my $dsn = "DBI:mysql:$databaseName;host=$databaseHost:$databasePort";
my $dbh;
my $req;
my $sth;
$dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");

# Truncate necessary tables
foreach my $table ("revision", "page", "text", "imagelinks", "templatelinks", "interwiki", "redirect", "externallinks", "image") {
    $req = "TRUNCATE $table";
    $sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
}

# Upload the SQL
my $mysqlCmd = "mysql --user=$databaseUsername --password=$databasePassword $databaseName";
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-interwiki.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-interwiki.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-imagelinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-image.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-pagelinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-redirect.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-templatelinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-externallinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-categorylinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-latest-category.sql.gz | $mysqlCmd"; `$cmd`;
# Upload the XML
$cmd = "cd $mwDumperDir; java -classpath ./src org.mediawiki.dumper.Dumper --format=sql:1.5 ../$projectCode-latest-pages-articles.xml.bz2 | $mysqlCmd"; `$cmd`;

exit;
