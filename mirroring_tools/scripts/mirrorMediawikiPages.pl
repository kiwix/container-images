#!/usr/bin/perl

#use encoding 'utf8'; 
use lib "../";
use lib "../Mediawiki/";

use strict;
use warnings;
use Getopt::Long;
use MediaWiki::Mirror;

my $title = shift;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorMediawikiPages.pl");

# mirror
my $mirror = new MediaWiki::Mirror();
$mirror->sourceMediawikiHost("source.wiki.org");
$mirror->sourceMediawikiPath("w");
$mirror->destinationMediawikiHost("dest.wiki.org");
$mirror->destinationMediawikiUsername("user");
$mirror->destinationMediawikiPassword("pass");
$mirror->logger($logger);

$mirror->addPagesToMirror($title);

$mirror->startMirroring();

$mirror->wait();

print $mirror->getQueueStatus();

exit;
