#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use lib "../../dumping_tools/classes/";

use utf8;
use Encode;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use XML::Simple;
use Kiwix::PathExplorer;
use LWP::UserAgent;

my $torrentHomeUrl = 'http://bt.kiwix.org/torrents/';

# get the params
my $rtorrentPath;

## Get console line arguments
GetOptions(
    'rtorrentPath=s' => \$rtorrentPath, 
    );

if (!$rtorrentPath) {
    print "Usage: assureBittorentClientIsRunning.pl --rtorrentPath=/var/www/rtorrent\n";
    exit;
}

# compute torrent directory
my $rtorrentSession = $rtorrentPath."/session/";
my $rtorrentInbox = $rtorrentPath."/inbox/";
my $rtorrentWatch = $rtorrentPath."/watch/";

# create necessary directories
unless (-d $rtorrentPath) { mkdir($rtorrentPath) };
unless (-d $rtorrentSession) { mkdir($rtorrentSession) };
unless (-d $rtorrentInbox) { mkdir($rtorrentInbox) };
unless (-d $rtorrentWatch) { mkdir($rtorrentWatch) };

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("assureBittorentClientIsRunning.pl");

# test if rtorrent is already running
my $cmd = "pidof rtorrent";
my $rtorrentPid = `$cmd`;
exit if ($rtorrentPid);

# write config file
my $homeDirectory = $ENV{HOME}."/"; 
my $configPath = $homeDirectory.".rtorrent.rc";

my $configurationText = "session = $rtorrentSession\n";
$configurationText .= "directory = $rtorrentInbox\n";
$configurationText .= "check_hash = yes\n";
$configurationText .= "safe_sync = yes\n";
$configurationText .= "schedule = watch_directory,5,5,load_start=$rtorrentWatch/*.torrent\n";

if ( -f $configPath ) { unlink($configPath) or die ("Unable to remove $configPath"); }
writeFile($configPath, \$configurationText);

# download the torrent files
my $ua = LWP::UserAgent->new();
my $req = HTTP::Request->new(GET => $torrentHomeUrl );
my $res = $ua->request($req);

if ($res->is_success) {
    my $html = $res->content();
    while ( $html =~ /\"([^\"]*\.torrent)\"/g ) {
	my $file = $1;
	$cmd = "wget $torrentHomeUrl/$file -O $rtorrentWatch/$file";
	`$cmd`;
    }
}
else {
    die ($res->status_line);
}

# start rtorrent
$cmd = "screen -d -m -S rtorrent rtorrent";
exec($cmd);

# functions
sub writeFile {
    my $file = shift;
    my $data = shift;

    open (FILE, ">$file") or die "Couldn't open file: $file";
    print FILE $$data;
    close (FILE);
}

exit;
