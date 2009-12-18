#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("modifyMediawikiEntry.pl");

# parameters
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my @entries;
my $readFromStdin = 0;
my $file = "";
my $action = "touch";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'file=s' => \$file,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   'action=s' => \$action,
           'readFromStdin' => \$readFromStdin,
           'entry=s' => \@entries,
    );

if (!$host || (!$readFromStdin && !$file && !scalar(@entries)) || !($action =~ /^(touch|delete|empty|restore|replace)$/)) {
    print "usage: ./buildHistoryFile.pl --host=my.wiki.org [--file=my_file] [--path=w] [--entry=my_page] [--readFromStdin] [--action=touch|delete|empty|restore|replace] [--username=foobar] [--password=mypass]\n";
    exit;
}

$logger->info("=======================================================");
$logger->info("= Start modifying entries =============================");
$logger->info("=======================================================");

# readFromStdin
if ($readFromStdin) {
    $logger->info("Read entries from stdin.");
    while (my $entry = <STDIN>) {
	$entry =~ s/\n//;
	push(@entries, $entry);
    }
}

# readfile
if ($file) {
    if (-f $file) {
	open SOURCE_FILE, "<$file" or die $!;
	while (<SOURCE_FILE>) {
	    my $entry = $_;
	    $entry =~ s/\n//;
	    push(@entries, $entry);
	}
    } else {
	$logger->info("File '$file' does not exist.");
    }
}

# connect to mediawiki
my $site = MediaWiki->new();
$site->logger($logger);
$site->hostname($host);
$site->path($path);
$site->user($username);
$site->password($password);
$site->setup();

# do action for each entry
foreach my $entry (@entries) {
    my $status;
    if ($action eq "touch") {
	$status = $site->touchPage($entry);
    } elsif ($action eq "delete") {
	$status = $site->deletePage($entry);
    } elsif ($action eq "empty") {
	$status = $site->uploadPage($entry, "");
    } elsif ($action eq "restore") {
	$status = $site->restorePage($entry, "");
    } elsif ($action eq "replace") {
	my ($title, $newContent) = split(/ /, $entry);
	$status = $site->uploadPage($title, $newContent);
    } else {
	$logger->info("This action is not valid, will exit.");
	last;
    }

    if ($status) {
	$logger->info("The '$action' action was successfuly performed on '$entry'.");
    } else {
	$logger->info("The '$action' action failed to be performed on '$entry'.");
    }
}

$logger->info("=======================================================");
$logger->info("= Stop modifying entries =============================");
$logger->info("=======================================================");

exit;
