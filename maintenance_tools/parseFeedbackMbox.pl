#!/usr/bin/perl

use strict;
use warnings;
use Mail::Box::Mbox;
use Getopt::Long;
use Data::Dumper;

 
sub format_time {
    my ($sec, $min, $hour, $day, $month, $year) = localtime(shift);
    $year = 1900 + $year;
    $month++;
    return sprintf("%02d/%02d/%02d %02d:%02d:%02d", $year, $month, $day, $hour, $min, $sec);
}

# get the params
my $path = "";

## Get console line arguments                                                                                   
GetOptions(
    'path=s' => \$path
    );

if (!$path) {
    print "usage: ./parseFeedbackMbox.pl --path=feedbacks\n";
    exit;
}

my $folder = Mail::Box::Mbox->new(folder => $path);
my $csv = "DATE\tIP\tCOUNTRY\tMESSAGE\tLANGUAGE\tINPUT\tVERSION\tBROWSER\n";
foreach my $msg (@$folder) {
    my $body = $msg->body();
    if ($body =~ /MESSAGE\n==================================================\n(.*)\n\nADDITIONAL INFORMATIONS\n==================================================\nInput:         (.*)\nVersion:       (.*)\nIP:            (.*)\nLocation:      (.*)\nBrowser - OS:  (.*)\nBrowser lang.: (.*?)\n/s ) {
	my $input = $2 || "";
	my $version = $3 || "";
	my $ip = $4 || "";
	my $country = $5 || "";
	my $browser = $6 || "";
	my $language = $7 || "";
	my $message = $1 || "";
	$message =~ s/\r\n/ /mg;
	$message =~ s/\n/ /mg;
	$message =~ s/\t/ /mg;
	my $date = format_time($msg->guessTimestamp()) || "";
	
	$csv .= "$date\t$ip\t$country\t$message\t$language\t$input\t$version\t$browser\n";
    } else {
    }
}

print $csv;
