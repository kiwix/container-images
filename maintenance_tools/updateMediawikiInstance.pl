#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Cwd 'abs_path';
use POSIX qw(strftime);

# get the params
my $tmpPath = "/tmp/mw_updated/";
my $sourcePath;
my $destinationPath;
my $backupPath;
my $silent;
my $cmd;
my $date = strftime("%Y%m%d", localtime);
my $scriptPath = abs_path($0);
my $backupScriptPath = dirname($scriptPath)."/backupMediawikiInstance.pl";

# Get console line arguments
GetOptions('sourcePath=s' => \$sourcePath,
	   'destinationPath=s' => \$destinationPath,
	   'backupPath=s' => \$backupPath,
	   'silent' => \$silent,
	   );

# Print usage() if necessary
if (!$sourcePath || !$destinationPath || !$backupPath) {
    print "usage: ./updateMediawikiInstance.pl --sourcePath=./master --destinationPath=/var/www/wiki --backupPath=./tmp [--silent]\n";
    exit;
}

# Check paths
if (! isMediawikiDirectory($sourcePath)) {
    die "'$sourcePath' is not a Mediawiki directory.";
}
if (! isMediawikiDirectory($destinationPath)) {
    die "'$destinationPath' is not a Mediawiki directory.";
}
if (! -d $backupPath && ! -w $backupPath) {
    die "'$backupPath' isn't a directory or is not writable.";
}
$sourcePath = abs_path($sourcePath);
$destinationPath = abs_path($destinationPath);
$backupPath = abs_path($backupPath);
printLog("Successfully checked paths.");

# Extract destination database information
my $destinationCustomLocalSettingsPath = $destinationPath."/LocalSettings.custom.php";
my $destinationCustomLocalSettings = readFile($destinationCustomLocalSettingsPath);
my $databaseServer;
my $databaseName;
my $databaseUsername;
my $databasePassword;

if (! -f $destinationCustomLocalSettingsPath && ! -r $destinationCustomLocalSettingsPath) {
    die "'$destinationCustomLocalSettingsPath' doesn't exist or is not readable.";
}

if ($destinationCustomLocalSettings =~ /\$wgDBserver[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseServer = $1;
} else {
    printLog("Impossible to detect database server, localhost per default");
    $databaseServer = "localhost";
}

if ($destinationCustomLocalSettings =~ /\$wgDBname[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseName = $1;
} else {
    die("Impossible to detect database name.");
}

if ($destinationCustomLocalSettings =~ /\$wgDBuser[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseUsername = $1;
} else {
    die("Impossible to detect database username.");
}

if ($destinationCustomLocalSettings =~ /\$wgDBpassword[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databasePassword = $1;
} else {
    die("Impossible to detect database password.");
}

# Backup files and database
doSystemCommand("$backupScriptPath --mediawikiPath=$destinationPath --backupPath=$backupPath");

# Copy the files
printLog("Copying files...");
doSystemCommand("rm -rf \"$tmpPath\"");
doSystemCommand("cp -rf \"$sourcePath\" \"$tmpPath\"");
doSystemCommand("rm -rf \"$tmpPath/images\"");
doSystemCommand("cp -rf \"$destinationPath/images\" \"$tmpPath\"");
doSystemCommand("cp \"$destinationCustomLocalSettingsPath\" \"$tmpPath\"");

# Do the final move
printLog("Do the final move...");
doSystemCommand("rm -rf \"$destinationPath\"");
doSystemCommand("mv \"$tmpPath\" \"$destinationPath\"");
doSystemCommand("chown -R www-data:www-data \"$destinationPath\"");
doSystemCommand("php \"$destinationPath/maintenance/update.php\" /tmp");
printLog("The Mediawiki instance at \"$destinationPath\" was successfuly updated.");

# Multiple usefull functions
sub doSystemCommand {
    my $systemCommand = shift;
    my $returnCode = system( $systemCommand );
    if ( $returnCode != 0 ) { 
        die "Failed executing [$systemCommand]\n"; 
    }
}

sub isMediawikiDirectory {
    my $path = shift;
    return (-d "$path" && -f "$path/LocalSettings.php") ? 1 : 0;
}

sub writeFile {
    my $file = shift;
    my $data = shift;
    open (FILE, ">", "$file") or die "Impossible to open file: '$file'";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    my $content = "";

    open(FILE, '<', $file);
    while (my $line = <FILE>) {
	$content .= $line;
    }
 
    return $content;
}

# Logging function
sub printLog {
    my $message = shift;
    unless ($silent) {
	print "$message\n";
    }
}

exit;
