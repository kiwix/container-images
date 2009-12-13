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
my $wiki;
my $username;
my $password;
my $dbUsername;
my $dbPassword;

## Get console line arguments
GetOptions(
	   'wiki=s' => \$wiki, 
           'username=s' => \$username,
	   'password=s' => \$password, 
           'dbUsername=s' => \$dbUsername,
	   'dbPassword=s' => \$dbPassword, 
           );

if (!$wiki || !$username || !$password || !$dbUsername || !$dbPassword) {
    print "Usage: tryToMigrateImagesToCommons.pl --wiki=es --username=myname --password=foobar --dbUsername --dbPassword\n";
    exit;
}

my $host = $wiki.".mirror.kiwix.org";

# compare images
`./compareMediawikiImages.pl --firstHost=$host --secondHost=commons.wikimedia.org --secondPath=w > /tmp/$host.commons_files`;

# check if pictures are already in commons
`cat /tmp/$host.commons_files | ./compareMediawikiImages.pl --readFromStdin --firstHost=$host --secondHost=commons.mirror.kiwix.org > /tmp/$host.kiwix_commons_files`;

# Build the list to upload
`./compareLists.pl --file1=/tmp/$host.commons_files --file2=/tmp/$host.kiwix_commons_files --mode=only1 > /tmp/$host.commons_files_to_upload`;

# upload pictures to commons
`cat /tmp/$host.commons_files_to_upload | ./mirrorMediawikiPages.pl --sourceHost=$host --destinationHost=commons.mirror.kiwix.org --destinationPassword="$password" --destinationUsername="$username" --readFromStdin --ignoreEmbeddedInPagesCheck --noTextMirroring --ignoreImageDependences --ignoreTemplateDependences`;

# remove pictures
`cat /tmp/$host.commons_files | ./modifyMediawikiEntry.pl --host=$host --readFromStdin --action=delete --username=Kelson --password=KelsonKelson`;

# clean
`./deleteOldRevisions.pl --database=mirror_$wiki --mediawikiDirectory=/var/www/mirror/$wiki --username=$dbUsername --password=$dbPassword`;

exit;
