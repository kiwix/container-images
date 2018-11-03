#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../classes/";
use lib "$FindBin::Bin/../../dumping_tools/classes/";

use utf8;
use strict;
use warnings;
use XML::DOM;

use Getopt::Long;

my $showHelp;
my $source;

sub usage() {
    print "manageLibraryKiwixOrg.pl\n";
    print "\t--source=XML_PATH\n";
    print "\t--help\n";
}

GetOptions(
    'help'     => \$showHelp,
    'source=s' => \$source,
);

if ($showHelp) {
    usage();
    exit 0;
}

if (!$source) {
    usage();
    exit 0;
}

# Read original XML file
my $parser = new XML::DOM::Parser;
my $doc = $parser->parsefile($source);

# Modify the DOM
my $nodes = $doc->getElementsByTagName("book");
for (my $i = 0; $i < $nodes->getLength; $i++) {
    my $node = $nodes->item($i);

    # Set path
    my $path = $node->getAttributeNode("url")->getValue
	=~ s/http:\/\/download.kiwix.org\///r =~ s/\.meta4//r;
    $node->setAttribute("path", $path);

    # Remove tag
    $node->removeAttribute("tags");
}

# Print to string
my $xml = $doc->toString;
utf8::encode($xml);
print $xml;

exit 0;
