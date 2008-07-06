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

my $ignoreTemplateDependences;
my $ignoreImageDependences;

my $checkCompletedPages;
my $checkCompletedImages;

my $noTextMirroring;

my @pages;
my $readFromStdin = 0;
my $noResume = 0;
my $noLog = 0;

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
           'checkCompletedImages' => \$checkCompletedImages,
           'checkCompletedPages' => \$checkCompletedPages,
           'noResume' => \$noResume,
           'noLog' => \$noLog,
           'ignoreTemplateDependences' => \$ignoreTemplateDependences,
           'ignoreImageDepedences' => \$ignoreImageDependences,
           'noTextMirroring' => \$noTextMirroring,
           );

if (!$sourceHost || !$destinationHost ) {
    print "Usage:\n\t";
    print "/mirrorMediawikiPages.pl --sourceHost=[host] --destinationHost=[host]\n\n";

    print "Options:\n\t";
    print "--sourceUsername=[username] (example: foobar)\n\t\tUsername for the source Mediawiki\n\t";
    print "--sourcePassword=[password] (example: foobarpass)\n\t\tPassword for the source Mediawiki\n\t";
    print "--destinationUsername=[username] (example: foobar)\n\t\tUsername for the destination Mediawiki\n\t";
    print "--destinationPassword=[password] (example: foobarpass)\n\t\tPassword for the destination Mediawiki\n\t";
    print "--sourcePath=[path] (example: w)\n\t\tPath in the URL to access to the source Mediawiki root\n\t";
    print "--destinationPath=[path] (example: w)\n\t\tPath in the URL to access to the destination Mediawiki root\n\t";
    print "--page=[page] (for example:Paris)\n\t\tPage name of the article you want to mirror. Can be used many time.\n\t";
    print "--readFromStdin\n\t\tThe page names will be read as a carriage return separated list from STDIN.\n\t\tBe careful, you have to set the necessary passowrds in the command line if you want to use this option.\n\t";
    print "--checkCompletedPages\n\t\tPages and templates which are already present in the destination Mediawiki will be mirrored.\n\t";
    print "--checkCompletedImages\n\t\tImage which are alreadz present in the destination Mediawiki will be mirrored.\n\t";
    print "--noResume\n\t\tDo not print on STDOUT a resume of the queue status.\n\t";
    print "--noLog\n\t\tDo not start a logging process.\n\t";
    print "--ignoreTemplateDependences\n\t\tDo not check for each downloaded page the text dependences (templates).\n\t";
    print "--ignoreImageDependences\n\t\tDo not check for each downloaded page the image dependences (images included in the page).\n\t";
    print "--noTextMirroring\n\t\tDo not mirror any text. Can be useful to mirror only images (for example by ginving a list of picture pages).\n";
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

my $mirror = new MediaWiki::Mirror();

# log
unless ($noLog) {
    use Log::Log4perl;
    Log::Log4perl->init("../conf/log4perl");
    my $logger = Log::Log4perl->get_logger("mirrorMediawikiPages.pl");
    $mirror->logger($logger);
}

$mirror->sourceMediawikiHost($sourceHost);
$mirror->sourceMediawikiPath($sourcePath);

$mirror->sourceMediawikiUsername(ucfirst($sourceUsername));
$mirror->sourceMediawikiPassword($sourcePassword);

$mirror->destinationMediawikiHost($destinationHost);
$mirror->destinationMediawikiPath($destinationPath);

$mirror->destinationMediawikiUsername(ucfirst($destinationUsername));
$mirror->destinationMediawikiPassword($destinationPassword);

$mirror->checkCompletedPages($checkCompletedPages);
$mirror->checkCompletedImages($checkCompletedImages);

$mirror->checkImageDependences( $ignoreImageDependences ? 0 : 1);
$mirror->checkTemplateDependences( $ignoreTemplateDependences ? 0 : 1);

$mirror->noTextMirroring($noTextMirroring);

$mirror->startMirroring();

foreach my $page (@pages) {
    $mirror->addPagesToMirror($page);
}

$mirror->wait();

unless ($noResume) {
    print $mirror->getQueueStatus();
}

exit;
