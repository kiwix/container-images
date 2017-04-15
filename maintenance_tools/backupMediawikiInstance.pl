#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Cwd 'abs_path';
use POSIX qw(strftime);

# get the params
my $mediawikiPath;
my $backupPath;
my $silent;
my $cmd;
my $date = strftime("%Y%m%d", localtime);

# Get console line arguments
GetOptions('mediawikiPath=s' => \$mediawikiPath,
	   'backupPath=s' => \$backupPath,
	   'silent' => \$silent,
	   );

# Print usage() if necessary
if (!$mediawikiPath || !$backupPath) {
    print "usage: ./backupMediawikiInstance --mediawikiPath=/var/www/wiki --destinationPath=/var/www/wiki --backupPath=./tmp [--silent]\n";
    exit;
}

# Check paths
if (! isMediawikiDirectory($mediawikiPath)) {
    die "'$mediawikiPath' is not a Mediawiki directory.";
}
if (! -d $backupPath && ! -w $backupPath) {
    die "'$backupPath' isn't a directory or is not writable.";
}
$mediawikiPath = abs_path($mediawikiPath);
$backupPath = abs_path($backupPath);
printLog("Successfully checked paths.");

# Extract mediawiki database information
my $mediawikiCustomLocalSettingsPath = $mediawikiPath."/LocalSettings.custom.php";
my $mediawikiCustomLocalSettings = readFile($mediawikiCustomLocalSettingsPath);
my $databaseServer;
my $databaseName;
my $databaseUsername;
my $databasePassword;

if (! -f $mediawikiCustomLocalSettingsPath && ! -r $mediawikiCustomLocalSettingsPath) {
    die "'$mediawikiCustomLocalSettingsPath' doesn't exist or is not readable.";
}

if ($mediawikiCustomLocalSettings =~ /\$wgDBserver[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseServer = $1;
} else {
    printLog("Impossible to detect database server, localhost per default");
    $databaseServer = "localhost";
}

if ($mediawikiCustomLocalSettings =~ /\$wgDBname[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseName = $1;
} else {
    die("Impossible to detect database name.");
}

if ($mediawikiCustomLocalSettings =~ /\$wgDBuser[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseUsername = $1;
} else {
    die("Impossible to detect database username.");
}

if ($mediawikiCustomLocalSettings =~ /\$wgDBpassword[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databasePassword = $1;
} else {
    die("Impossible to detect database password.");
}

# Backup files and database
my $mediawikiPathBasename = basename($mediawikiPath);
my $mediawikiPathDirname = dirname($mediawikiPath);
my $filesBackupPath = $backupPath."/".$date."_".$databaseName."_files.tar.xz";
my $dbBackupPath = $backupPath."/".$date."_".$databaseName."_db.sql.xz";
if (-f $filesBackupPath) {
    die ("Backup file '$filesBackupPath' already exists, please remove it before running this script.\n");
}
if (-f $dbBackupPath) {
    die ("Backup file '$dbBackupPath' already exists, please remove it before running this script.\n");
}
printLog("Backuping db at '$dbBackupPath'...");
doSystemCommand("mysqldump --host=\"$databaseServer\" --user=\"$databaseUsername\" --password=\"$databasePassword\" $databaseName | xz > $dbBackupPath");
printLog("Backuping files at '$filesBackupPath'...");
doSystemCommand("cd \"$mediawikiPathDirname\"; tar -cvjf \"$filesBackupPath\" \"$mediawikiPathBasename\"".($silent ? "" : " > /dev/null"));

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
