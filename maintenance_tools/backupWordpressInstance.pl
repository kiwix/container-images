#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use File::Basename;
use Cwd 'abs_path';
use POSIX qw(strftime);

# get the params
my $tmpPath = "/tmp/";
my $sourcePath;
my $backupPath;
my $silent;
my $cmd;
my $date = strftime("%Y%m%d", localtime);

# Get console line arguments
GetOptions('sourcePath=s' => \$sourcePath,
	   'backupPath=s' => \$backupPath,
	   'silent' => \$silent,
	   );

# Print usage() if necessary
if (!$sourcePath || !$backupPath) {
    print "usage: backupWordpressInstance --sourcePath=./master --backupPath=./tmp [--silent]\n";
    exit;
}

# Check paths
if (! isWordpressDirectory($sourcePath)) {
    die "'$sourcePath' is not a Wordpress directory.";
}
if (! -d $backupPath && ! -w $backupPath) {
    die "'$backupPath' isn't a directory or is not writable.";
}
$sourcePath = abs_path($sourcePath);
$backupPath = abs_path($backupPath);
printLog("Successfully checked paths.");

# Extract destination database information
my $configPath = $sourcePath."/wp-config.php";
my $config = readFile($configPath);
my $databaseName;
my $databaseUsername;
my $databasePassword;

if (! -f $configPath && ! -r $configPath) {
    die "'$configPath' doesn't exist or is not readable.";
}
if ($config =~ /define[\t ]*\([\t ]*[\'\"]DB_NAME[\'\"][\t ]*,[\t ]*[\'\"](.*)[\'\"][\t ]*\)/) {
    $databaseName = $1;
} else {
    die("Impossible to detect database name.");
}

if ($config =~ /define[\t ]*\([\t ]*[\'\"]DB_USER[\'\"][\t ]*,[\t ]*[\'\"](.*)[\'\"][\t ]*\)/) {
    $databaseUsername = $1;
} else {
    die("Impossible to detect database username.");
}

if ($config =~ /define[\t ]*\([\t ]*[\'\"]DB_PASSWORD[\'\"][\t ]*,[\t ]*[\'\"](.*)[\'\"][\t ]*\)/) {
    $databasePassword = $1;
} else {
    die("Impossible to detect database password.");
}

# Backup files and database
my $filesBackupPath = $backupPath."/".$date."_".$databaseName."_files.tar.xz";
my $dbBackupPath = $backupPath."/".$date."_".$databaseName."_db.sql.xz";
if (-f $filesBackupPath) {
    die ("Backup file '$filesBackupPath' already exists, please remove it before running this script.\n");
}
if (-f $dbBackupPath) {
    die ("Backup file '$dbBackupPath' already exists, please remove it before running this script.\n");
}
printLog("Backuping db at '$dbBackupPath'...");
doSystemCommand("mysqldump --user=\"$databaseUsername\" --password=\"$databasePassword\" $databaseName | xz > $dbBackupPath");
printLog("Backuping files at '$filesBackupPath'...");
doSystemCommand("cd \"$backupPath\"; tar -cvjf \"$filesBackupPath\" \"$sourcePath\" > /dev/null");

printLog("The Wordpress instance at \"$sourcePath\" was successfuly backuped.");

# Multiple usefull functions
sub doSystemCommand {
    my $systemCommand = shift;
    my $returnCode = system( $systemCommand );
    if ( $returnCode != 0 ) { 
        die "Failed executing [$systemCommand]\n"; 
    }
}

sub isWordpressDirectory {
    my $path = shift;
    return (-d "$path" && -f "$path/wp-config.php") ? 1 : 0;
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
