#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;
use Term::Query qw(query);

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("applyCustomisations.pl");

# get the params
my $projectCode;
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my $entries;

## Get console line arguments
GetOptions('projectCode=s' => \$projectCode,
	   'host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   );

if (!$projectCode || !$host) {
    print "usage: ./applyCustomisations --projectCode=fr --host=fr.mirror.kiwix.org [--path=w] [--username=foo] [--password=bar]\n";
    exit;
}

# connect to mediawiki
my $site = MediaWiki->new();
$site->logger($logger);
$site->hostname($host);
$site->path($path);
if ($username) {
    $site->user($username);
    $site->password($password);
}
$site->setup();

# Initiate www.kiwix.org
my $www = MediaWiki->new();
$www->hostname("www.kiwix.org");
$www->path("");
$www->logger($logger);

# Get the list image to delete
sub getList {
    my $pageTitle = shift;

    # Get the code of the page
    my ($list) = $www->downloadPage($pageTitle);

    # Set empty string if undefined
    unless ($list) {
	$list = "";
    }
    
    # Remove the geshi xml code
    $list =~ s/^<[\/]*source[^>]*>[\n]*//mg;
    
    return $list;
}

# Remove the images in the image black list
$entries = getList("Mirrors/$projectCode/image_black_list.txt");
foreach my $entry (split(/\n/, $entries)) {
    $site->deletePage($entry);
}

exit;
