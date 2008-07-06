#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use LWP::UserAgent;
use MediaWiki::Install;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("installMediawiki.pl");

# get the params
my $site;
my $path="";
my $code;
my $directory;
my $languageCode;
my $sysopUser;
my $sysopPassword;
my $dbUser;
my $dbPassword;
my @confIncludes;

## Get console line arguments
GetOptions('site=s' => \$site,
	   'path=s' => \$path,
	   'directory=s' => \$directory,
	   'code=s' => \$code, 
	   'languageCode=s' => \$languageCode, 
	   'sysopUser=s' => \$sysopUser,
	   'sysopPassword=s' => \$sysopPassword,
	   'dbUser=s' => \$dbUser,
	   'dbPassword=s' => \$dbPassword,
	   'confInclude=s@' => \@confIncludes
	   );

if (!$site || !$code || !$directory || !$languageCode || !$sysopUser || !$sysopPassword || !$dbUser || !$dbPassword) {
    print "usage: ./installMediawiki.pl [--path=w] --directory=/var/www/mirror/fr --site=fr.kiwix.org --code=fr --languageCode=fr --sysopUser=Kelson --sysopPassword=*** --dbUser=mydbuser --dbPassword=**** [--confInclude=addconf.php]\n";
    exit;
}

if (!$sysopPassword) {
    $sysopPassword = query("sysopPassword:", "");
}

if (!$dbPassword) {
    $dbPassword = query("dbPassword:", "");
}

my $installer = MediaWiki::Install->new();
$installer->logger($logger);
$installer->site($site);
$installer->code($code);
$installer->path($path);
$installer->directory($directory);
$installer->languageCode($languageCode);
$installer->sysopUser($sysopUser);
$installer->sysopPassword($sysopPassword);
$installer->dbUser($dbUser);
$installer->dbPassword($dbPassword);
$installer->confIncludes(@confIncludes);
$installer->install();

