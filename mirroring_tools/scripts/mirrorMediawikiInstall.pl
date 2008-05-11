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
my $action;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'action=s' => \$action
	   );

if (!$host) {
    print "usage: ./mirorMediawikiInstall.pl --host=my_wiki_host [--path=w] [--action=printAll]\n";
    exit;
}

my $install = MediaWiki::Install->new();
$install->logger($logger);
$install->get($host, $path);
$install->printAll();
