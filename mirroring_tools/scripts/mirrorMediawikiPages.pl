#!/usr/bin/perl

#use encoding 'utf8'; 
use lib "../";
use lib "../Mediawiki/";

use strict;
use warnings;
use Getopt::Long;
use MediaWiki::Mirror;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# get the params
my $sourceHost;
my $sourcePath;
my $sourceUsername;
my $sourcePassword;

my $destinationHost;
my $destinationPath;
my $destinationUsername;
my $destinationPassword;

my @pages;
my $readFromStdin = 0;

## Get console line arguments
GetOptions(
	   'sourceHost=s' => \$sourceHost, 
           'sourcePath=s' => \$sourcePath,
           'sourceUsername=s' => \$sourceUsername,
           'sourcePassword=s' => \$sourcePassword,
	   'destinationHost=s' => \$destinationHost, 
           'destinationPath=s' => \$destinationPath,
           'destinationUsername=s' => \$destinationUsername,
           'destinationPassword=s' => \$destinationPassword,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
           );

if (!$sourceHost || !$destinationHost ) {
    print "usage: ./mirrorMediawikiPages.pl --sourceHost=my.source.host --destinationHost=my.dest.host [--sourceUsername=my_user] [--sourcePassword=my_password] [--destinationUsername=my_user] [--destinationPassword=my_password] [--sourcePath=w]  [--destinationPath=w] [--page=my_page] [--readFromStdin]\n";
    exit;
}

if ($readFromStdin) {
    while (my $page = <STDIN>) {
	$page =~ s/\n//;
	push(@pages, $page);
    }
} else  {
    if ($sourceUsername && !$sourcePassword) {
	$sourcePassword = query("Source password:", "");
    }
    
    if ($destinationUsername && !$destinationPassword) {
	$destinationPassword = query("Destination password:", "");
    }
}

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiPages.pl");

# mirror
my $mirror = new MediaWiki::Mirror();
$mirror->logger($logger);

$mirror->sourceMediawikiHost($sourceHost);
$mirror->sourceMediawikiPath($sourcePath);

$mirror->destinationMediawikiHost($destinationHost);
$mirror->destinationMediawikiPath($destinationPath);

$mirror->destinationMediawikiUsername($destinationUsername);
$mirror->destinationMediawikiPassword($destinationPassword);

foreach my $page (@pages) {
    $mirror->addPagesToMirror($page);
}

$mirror->startMirroring();
$mirror->wait();

print $mirror->getQueueStatus();

exit;
