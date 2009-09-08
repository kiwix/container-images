#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use strict;
use Getopt::Long;
use List::Compare;
 
my $file1;
my $file2;
my $mode;
my $list1;
my $list2;
my @results;
 
GetOptions('file1=s' => \$file1, 'file2=s' => \$file2, 'mode=s' => \$mode);
 
unless ($file1 && $file2 && $mode) {
    print "usage: ./compareLists.pl --file1=first_list --file2=second_list --mode=[only1|inter]\n";
    exit
}
 
## read file
$list1 = read_file($file1);
$list2 = read_file($file2);
 
## create the comparator
my $lc = List::Compare->new( {
    lists    => [$list1, $list2],
    unsorted => 1,
			     } );
 
## make the comparison
if ($mode eq "only1") {
    @results = $lc->get_unique();
} elsif ($mode eq "inter") {
    @results = $lc->get_intersection();
} 
 
## affiche les résultats
for my $page (@results) {
    print $page."\n";
}
 
sub read_file() {
    my $file = shift;
    my @list;
 
    open(FILE, '<:utf8', $file);
    while (my $page = <FILE>) {
	$page =~ s/\n//;
	push(@list, $page);
    }
 
    return \@list;
}
