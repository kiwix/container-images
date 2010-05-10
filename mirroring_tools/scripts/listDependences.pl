#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;

use lib "../";
use lib "../Mediawiki/";

use DBI;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;
use Encode;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("listDependences.pl");

# get the params
my $host = "";
my $path = "";
my $filter = "all";
my $type = "all";
my @pages;
my $readFromStdin = 0;

my $databaseHost = "localhost";
my $databasePort = "3306";
my $databaseName = "";
my $databaseUsername = "";
my $databasePassword = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'filter=s' => \$filter,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
	   'type=s' => \$type,
	   'databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databaseName=s' => \$databaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword
	   );

if (!$host || !($type =~ /(all|image|template)/i) || !($filter =~ /(all|missing|present)/i)) {
    print "usage: ./listDependences.pl --host=my.wiki.org [--path=w] [--page=mypage] [--readFromStdin] [--filter=all|missing|present] --type=[all|image|template] [--databaseName=mirror_foo] [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff]\n";
    exit;
}

if ($readFromStdin) {
    while (my $page = <STDIN>) {
	$page =~ s/\n//;
	push(@pages, $page);
    }
}

# Build a db connection if $databaseName is specified
if ($databaseName) {
    my $dsn = "DBI:mysql:$databaseName;host=$databaseHost:$databasePort";
    my $dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");
    my $sql;

    # images
    if ($type =~ /(all|image)/i ) {
	if ($filter eq "all") {
	    $sql = "SELECT DISTINCT imagelinks.il_to FROM imagelinks, page WHERE page.page_id = imagelinks.il_from";
	} elsif ($filter eq "present") {
	    $sql = "SELECT DISTINCT imagelinks.il_to FROM imagelinks, page, image WHERE page.page_id = imagelinks.il_from AND image.img_name = imagelinks.il_to";
	} elsif ($filter eq "missing") {
	    $sql = "SELECT DISTINCT imagelinks.il_to FROM imagelinks, page WHERE page.page_id = imagelinks.il_from AND il_to NOT IN (SELECT img_name FROM image)";
	}
	
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	
	while (my @data = $sth->fetchrow_array()) {
	    my $page = $data[0];
	    unless (Encode::is_utf8($page)) {
		$page = decode_utf8($page);
	    }
	    print "File:".$page."\n";
	}
    }

} else {
    my $site = MediaWiki->new();
    $site->hostname($host);
    $site->path($path);
    $site->logger($logger);
    
    my %templateDependences;
    my %imageDependences;
    
    unless (scalar(@pages)) {
	$logger->info("Get all nonredirect articles (namespace=0) of $host.");
	@pages = $site->allPages("0", "nonredirects")
    }
    
    foreach my $page (@pages) {
	
	unless (Encode::is_utf8($page)) {
	    $page = decode_utf8($page);
	}
	
	# images
	if ($type =~ /(all|image)/i ) {
	    my $imageNamespaceName = $site->getFileNamespaceName();
	    $logger->info("Getting image dependences of the page '$page'...");
	    my @imageDependences = $site->imageDependences($page);
	    $logger->info(scalar(@imageDependences)." image dependences found.");
	    foreach my $dep (@imageDependences) {
		my $image = $dep->{title};
		unless ($imageDependences{$image}) {
		    $image =~ tr/ /_/s;
		    $image =~ s/^$imageNamespaceName:/File:/i;
		    $imageDependences{$image} = exists($dep->{missing});
		}
	    }
	}
	
	# templates
	if ($type =~ /(all|template)/i ) {
	    my $templateNamespaceName = $site->getTemplateNamespaceName();
	    $logger->info("Get template dependences of the page '$page'.");
	    my @templateDependences = $site->templateDependences($page);
	    $logger->info(scalar(@templateDependences)." template dependences found.");
	    foreach my $dep (@templateDependences) {
		my $template = $dep->{title};
		unless ($templateDependences{$template}) {
		    $template =~ tr/ /_/s;
		    $template =~ s/^$templateNamespaceName:/Template:/i;
		    $templateDependences{$template} = exists($dep->{missing});
		}
	    }
	}
    }

    $logger->info("Printing to stdout image dependences...");
    foreach my $image (keys(%imageDependences)) {
	if ($filter eq "all" || ($filter eq "missing" && $imageDependences{$image}) || ($filter eq "present" && !$imageDependences{$image})) {
	    print $image."\n";
	}
    }
    
    $logger->info("Printing to stdout template dependences...");
    foreach my $template (keys(%templateDependences)) {
	if ($filter eq "all" || ($filter eq "missing" && $templateDependences{$template}) || ($filter eq "present" && !$templateDependences{$template})) {
	    print $template."\n";
	}
    }
};

exit;
