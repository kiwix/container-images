#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use HTML::Template;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("buildContributorsHtmlPages.pl");

# get the params
my $readFromStdin = 0;
my $file;
my $directory;
my $templateFile = "../data/en/contributors.html.tmpl";

# letter managment
my @letters = ("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z");
my %contributors;
foreach my $letter (@letters) {
    $contributors{$letter} = {};
}

## Get console line arguments
GetOptions('file=s' => \$file,
           'readFromStdin' => \$readFromStdin,
           'directory=s' => \$directory,
           'template=s' => \$templateFile,
    );

if (!$directory || (!$readFromStdin && !$file) ) {
    print "usage: ./buildContributorsHtmlPages.pl [--file=my_file] --directory=my_dir [--readFromStdin] [--template=mytemplate.html.tmpl]\n";
    exit;
}

$logger->info("=======================================================");
$logger->info("= Start contributors html files building ==============");
$logger->info("=======================================================");

sub addContributorToHash {
    my $contributor = shift;
    my $letter = substr($contributor, 0, 1);
    if (exists($contributors{$letter})) {
	$contributors{$letter}->{$contributor} = 1;
    } else {
	$contributors{others}->{$contributor} = 1;
    }
}

# readFromStdin
if ($readFromStdin) {
    $logger->info("Read contributors from stdin.");
    while (my $contributor = <STDIN>) {
	$contributor =~ s/\n//;
	$contributor =~ tr/_/ /;
	addContributorToHash($contributor);
    }
}

# readFromFile
if ($file) {
    $logger->info(" Read contributors from file '$file'.");
    
    open FILE, "<$file" or die $!;
    while (my $contributor = <FILE>) {
	$contributor =~ s/\n//;
	addContributorToHash($contributor);
    }
    close(FILE);
}

# open the html template
my $template = HTML::Template->new(filename => $templateFile);

# build letter hash
my @letterArray;
foreach my $letter (@letters) {

    # skip if no contributors                                                                                                   
    next unless (scalar(keys(%{$contributors{$letter}})));

    my %letterHash;
    $letterHash{"FILENAME"} = "./$letter.html";
    $letterHash{"LETTER"} = $letter;
    push(@letterArray, \%letterHash);
    
}
$template->param("LETTERS" => \@letterArray);

# create the directory
		 `rm -rf $directory`;
		 `mkdir $directory`;

foreach my $letter (@letters, 'others') {

    # skip if no contributors
    unless ($letter eq "others") {
	next unless (scalar(keys(%{$contributors{$letter}})));
    }

    $logger->info("Creating '$letter' file...");    

    my $contributorsString = "";
    foreach my $contributor (keys(%{$contributors{$letter}})) {
	if ($contributor) {
	    $contributorsString .= $contributor.", ";
	}
    }
    my $newContributorsString = substr($contributorsString, 0, length($contributorsString) - 2);
    $contributorsString = $newContributorsString;

    if ($letter eq "others") {
	$contributorsString .= "... and lots of anonymous contributors.";
    } else {
	$contributorsString .= ".";
    }

    # fill in some parameters
    $template->param("CONTRIBUTORS" => $contributorsString);

    # send the obligatory Content-Type and print the template output
    my $html = $template->output();
    
    # write file
    open FILE, ">$directory/$letter.html" or die $!;
    print FILE $html;
    close(FILE);
}

$logger->info("=======================================================");
$logger->info("= Stop contributors html files building ===============");
$logger->info("=======================================================");

exit;
