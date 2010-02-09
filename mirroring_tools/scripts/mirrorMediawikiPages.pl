#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;

use lib "../";
use lib "../Mediawiki/";

use Encode;
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

my $commonHost;
my $commonPath;
my $commonUsername;
my $commonPassword;
my $commonRegexp;

my $ignoreTemplateDependences;
my $ignoreImageDependences;
my $ignoreEmbeddedInPagesCheck;

my $checkCompletedPages;
my $checkCompletedImages;
my $useIncompletePagesAsInput;

my $checkIncomingRedirects;
my $dontFollowRedirects;
my $noTextMirroring;

my @pages;
my $readFromStdin = 0;
my $noResume = 0;
my $noLog = 0;

my $footerPath;

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
	   'commonHost=s' => \$commonHost, 
           'commonPath=s' => \$commonPath,
           'commonUsername=s' => \$commonUsername,
           'commonPassword=s' => \$commonPassword,
           'footerPath=s' => \$footerPath,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
           'checkCompletedImages' => \$checkCompletedImages,
           'checkCompletedPages' => \$checkCompletedPages,
           'noResume' => \$noResume,
           'noLog' => \$noLog,
           'useIncompletePagesAsInput' => \$useIncompletePagesAsInput,
           'ignoreTemplateDependences' => \$ignoreTemplateDependences,
           'ignoreImageDependences' => \$ignoreImageDependences,
           'noTextMirroring' => \$noTextMirroring,
           'checkIncomingRedirects' => \$checkIncomingRedirects,
           'dontFollowRedirects' => \$dontFollowRedirects,
           'ignoreEmbeddedInPagesCheck' => \$ignoreEmbeddedInPagesCheck,
           'commonRegexp=s'=> \$commonRegexp
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
    print "--readFromStdin\n\t\tThe page names will be read as a carriage return separated list from STDIN.\n\t\tBe careful, you have to set the necessary passwords in the command line if you want to use this option.\n\t";
    print "--checkCompletedPages\n\t\tPages and templates which are already present in the destination Mediawiki will be mirrored.\n\t";
    print "--checkCompletedImages\n\t\tImage which are already present in the destination Mediawiki will be mirrored.\n\t";
    print "--checkIncomingRedirects\n\t\tUpload pages which have redirects pointing on it will have their redirect mirrored.\n\t";
    print "--dontFollowRedirects\n\t\tUpload redirects but do not try to upload the targeted pages.\n\t";
    print "--noResume\n\t\tDo not print on STDOUT a resume of the queue status.\n\t";
    print "--noLog\n\t\tDo not start a logging process.\n\t";
    print "--ignoreTemplateDependences\n\t\tDo not check for each downloaded page the text dependences (templates).\n\t";
    print "--ignoreImageDependences\n\t\tDo not check for each downloaded page the image dependences (images included in the page).\n\t";
    print "--noTextMirroring\n\t\tDo not mirror any text. Can be useful to mirror only images (for example by ginving a list of picture pages).\n\t";
    print "--useIncompletePagesAsInput\n\t\tWill check dependences for all pages present in the destination wiki, and mirror lacking dependences.\n\t";
    print "--ignoreEmbeddedInPagesCheck\n\t\tWill ignore to check in an article page usind a new upload template as failing dependences.\n\t";
    print "--footerPath=[path] (example: footer.html.tmpl)\n\t\tWill append to every article mirrored this HTML code.\n\t";
    print "--commonUsername=[username] (example: foobar)\n\t\tUsername for the common Mediawiki\n\t";
    print "--commonPassword=[password] (example: foobarpass)\n\t\tPassword for the common Mediawiki\n\t";
    print "--commonPath=[path] (example: w)\n\t\tPath in the URL to access to the common Mediawiki root\n\t";
    print "--commonHost=[host] (example: localhost)\n\t\tIP or hostname of the common Mediawiki\n\t";
    print "--commonRegexp=[\/commons\/] (example: localhost)\n\t\tIP or hostname of the common Mediawiki\n";
    exit;
}

if ($commonHost && !$commonRegexp) {
    print "You have to specify --commonRegexp if you specify --commonHost.\n";
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

# add configuration parameters to the mirroring module
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
$mirror->checkIncomingRedirects($checkIncomingRedirects);
$mirror->followRedirects($dontFollowRedirects ? 0 : 1);

$mirror->checkImageDependences( $ignoreImageDependences ? 0 : 1);
$mirror->checkTemplateDependences( $ignoreTemplateDependences ? 0 : 1);
$mirror->checkEmbeddedIn( $ignoreEmbeddedInPagesCheck ? 0 : 1);

$mirror->commonMediawikiHost($commonHost);
$mirror->commonMediawikiPath($commonPath);
$mirror->commonMediawikiUsername($commonUsername);
$mirror->commonMediawikiPassword($commonPassword);
$mirror->commonRegexp($commonRegexp);

$mirror->noTextMirroring($noTextMirroring);

$mirror->footerPath($footerPath);

# start the mirroring threads
$mirror->startMirroring();

# useIncompletePagesAsInput
unless ($noLog) { $mirror->logger->info("Page which are incomplete will be searched."); }
if ($useIncompletePagesAsInput) {
    push(@pages, $mirror->getDestinationMediawikiIncompletePages());
}
unless ($noLog) { $mirror->logger->info(scalar(@pages)." incomplete pages were found."); }

# fill the queue of page to mirror
foreach my $page (@pages) {
    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }
    $mirror->addPagesToMirror($page);
}

# wait untile nothing is to do
$mirror->wait();

# print on STDOUT a small report of queue status
unless ($noResume) {
    print $mirror->getQueueStatus();
}

exit;
