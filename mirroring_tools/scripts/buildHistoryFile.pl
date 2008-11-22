#!/usr/bin/perl
binmode STDOUT, ":utf8";

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use XML::Simple;
use MediaWiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("builHistoryFile.pl");

# parameters
my $host = "";
my $path = "";
my @pages;
my $readFromStdin = 0;
my $file = "";
my $bzip2 = "";
my $throttle;
my $limit;
my $username;
my $password;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'file=s' => \$file,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   'throttle=s' => \$throttle,
	   'limit=s' => \$limit,
           'readFromStdin' => \$readFromStdin,
           'bzip2' => \$bzip2,
           'page=s' => \@pages,
    );

if (!$host || (!$readFromStdin && !scalar(@pages)) ) {
    print "usage: ./buildHistoryFile.pl --host=my.wiki.org [--bzip2] [--username=foobar] [--password=pass] [--file=my_file] [--path=w] [--page=my_page] [--readFromStdin] [--throttle=0] [--limit=500]\n";
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);
$site->user($username);
$site->password($password);

$logger->info("=======================================================");
$logger->info("= Start history file building =========================");
$logger->info("=======================================================");

sub formatTitle {
    my $title = shift;
    $title =~ tr/ /_/;
    $title = ucfirst($title);
    return $title;
}

# readFromStdin
if ($readFromStdin) {
    $logger->info(" Read pages from stdin.");
    while (my $page = <STDIN>) {
	$page =~ s/\n//;
	$page = formatTitle($page);
	push(@pages, $page);
    }
}

# build page hash
my %pagesHash;
foreach my $page (@pages) {
    $pagesHash{$page} = 1;
}
@pages = ();

if ($file) {
    # open file for write
    open DESTINATION_FILE, ">$file.tmp" or die $!;
    binmode DESTINATION_FILE, ":utf8";

    print DESTINATION_FILE "<history>\n"; 

    # open file for read
    $logger->info(" Read pages from $file for further update.");

    if (-f $file) {
	open SOURCE_FILE, "<$file" or die $!;
	binmode SOURCE_FILE, ":utf8";

	# skip the first line
	while (<SOURCE_FILE>) {
	    last;
	}

	my $sourceXml = "";
	while (<SOURCE_FILE>) {
	    my $line = $_;

	    if ($line =~ /missing\=\"\"/ || $line =~ /invalid\=\"\"/  ) {
		next;
	    }

	    $sourceXml .= $line;

	    if ($line =~ /^\<\/opt\>$/ ) {
	
		# make hash from xml
		my $sourceHash = XMLin( $sourceXml, ForceArray => [('rev')] );

		# get source title
		my $title = formatTitle( $sourceHash->{title} );

		if (exists($pagesHash{$title})) {
		    $logger->info("'$title' page has already an history and need to be updated.");
		    
		    # determine the most recent versionid in $sourceHash
		    my $sourceRecenterVersionId = $sourceHash->{revisions}->{rev}->[0]->{revid};
		    $logger->info("'$title' sourceXml recenter version id is $sourceRecenterVersionId.");		
		    
		    # get the online history
		    $logger->info("'$title' history will be updated will last revisions.");		
		    my $onlineHash = $site->history($title, $sourceRecenterVersionId, $throttle, $limit);

		    # merge
		    push(@{$onlineHash->{revisions}->{rev}}, @{$sourceHash->{revisions}->{rev}});

		    # write
		    my $xml = XMLout($onlineHash);
		    if ($file) {
			print(DESTINATION_FILE $xml);
		    }  else {
			print($xml);
		    }
		    
		} else {
		    $logger->info("'$title' page has already an history but is not in the list -> deletion.");		
		}

		# reset sourceXml
		$sourceXml = "";
		delete($pagesHash{$title});
	    }
	}
    }
}

# get history
foreach my $page (keys(%pagesHash)) {
    $logger->info("'$page' history will be new downloaded.");		
    my $history = $site->history($page, undef, $throttle);
    my $xml = XMLout($history);
    if ($file) {
	print(DESTINATION_FILE $xml);
    }  else {
	print($xml);
    }
}


if ($file) {
    close(SOURCE_FILE);
    print DESTINATION_FILE "</history>\n"; 
    close(DESTINATION_FILE);
    `mv $file.tmp $file`
}

$logger->info("=======================================================");
$logger->info("= Stop history file building ==========================");
$logger->info("=======================================================");

exit;
