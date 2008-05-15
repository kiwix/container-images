#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use MediaWiki::Install;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiInstall.pl");

# get the params
my $host;
my $path;
my $action="print";
my $filter=".*";
my $mediawikiDirectory="";
my $extensionDirectory="";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'action=s' => \$action,
	   'filter=s' => \$filter,
	   'extensionDirectory=s' => \$extensionDirectory,
	   'mediawikiDirectory=s' => \$mediawikiDirectory,
	   );

if (!$host || ($action eq "svn" && (!$mediawikiDirectory || !$extensionDirectory) )) {
    print "usage: ./mirrorMediawikiInstall.pl --host=my_wiki_host [--path=w] [--action=print|svn] [--filter=*] [--mediawikiDirectory=./] [--extensionDirectory=./]\n";
    exit;
}

my $install = MediaWiki::Install->new();
$install->logger($logger);
$install->mediawikiDirectory($mediawikiDirectory);
$install->extensionDirectory($extensionDirectory);
$install->get($host, $path);
$install->filter($filter);
$install->go($action);

