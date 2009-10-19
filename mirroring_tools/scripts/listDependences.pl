#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;

use lib "../";
use lib "../Mediawiki/";

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
my @pages;
my $readFromStdin = 0;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'filter=s' => \$filter,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
	   );

if (!$host) {
    print "usage: ./listDependences.pl --host=my.wiki.org [--path=w] [--page=mypage] [--readFromStdin] [--filter=all|missing|present]\n";
    exit;
}

if ($readFromStdin) {
    while (my $page = <STDIN>) {
	$page =~ s/\n//;
	push(@pages, $page);
    }
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

my %templateDependences;
my %imageDependences;

unless (scalar(@pages)) {
    @pages = $site->allPages("0", "nonredirects")
}

foreach my $page (@pages) {

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    # images
    my @imageDependences = $site->imageDependences($page);
    foreach my $dep (@imageDependences) {
	my $image = $dep->{title};
	unless ($imageDependences{$image}) {
	    $image =~ tr/ /_/s;
	    $imageDependences{$image} = exists($dep->{missing});
	}
    }

    # templates
    my @templateDependences = $site->templateDependences($page);
    foreach my $dep (@templateDependences) {
	my $template = $dep->{title};
	unless ($templateDependences{$template}) {
	    $template =~ tr/ /_/s;
	    $templateDependences{$template} = exists($dep->{missing});
	}
    }

};

foreach my $image (keys(%imageDependences)) {
    if ($filter eq "all" || ($filter eq "missing" && $imageDependences{$image}) || ($filter eq "present" && !$imageDependences{$image})) {
	print $image."\n";
    }
}

foreach my $template (keys(%templateDependences)) {
    if ($filter eq "all" || ($filter eq "missing" && $templateDependences{$template}) || ($filter eq "present" && !$templateDependences{$template})) {
	print $template."\n";
    }
}

exit;
