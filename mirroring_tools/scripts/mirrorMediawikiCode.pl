#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use MediaWiki::Code;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiCode.pl");

# get the params
my $host;
my $path;
my $action="info";
my $filter=".*";
my $directory="";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'action=s' => \$action,
	   'filter=s' => \$filter,
	   'directory=s' => \$directory,
	   );

if (!$host || ($action eq "svn" && !$directory) ) {
    if ($action eq "svn" && !$directory) {
	print "error: please specify a directory argument\n";
    }
    print "usage: ./mirrorMediawikiCode.pl --host=my_wiki_host [--path=w] [--action=info|svn|checkout|php] [--filter=*] [--directory=./]\n";
    exit;
}

my $code = MediaWiki::Code->new();
$code->filter($filter);

$code->logger($logger);
$code->directory($directory);

unless ($code->get($host, $path)) {
    exit;
}

if ($action eq "info") {
    print $code->informations();
} elsif ($action eq "svn") {
    print $code->getSvnCommands();
} elsif ($action eq "checkout") {
    my $svn = $code->getSvnCommands();
    foreach my $command (split("\n", $svn)) {
	`$command`;
    }

    $code->applyCustomisations();
    
    my $code = "<?php\n".$code->php()."\n?>\n";
    my $filename = "$directory/extensions.php";
    open (FILE, ">>$filename");
    print FILE $code;
    close (FILE);

} elsif ($action eq "php") {
    print $code->php();
}

