package MediaWiki::Install;

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use LWP::UserAgent;
use XML::DOM;
use HTML::Entities qw(decode_entities);

my $logger;
my $doc;
my $mediawikiRevision;
my @extensions;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub get {
    my $self = shift;
    my $host = shift || "";
    my $path = shift || "";

    my $ua = LWP::UserAgent->new();
    my $parser = new XML::DOM::Parser (LWP_UserAgent => $ua);
    my $url = "http://".$host."/".($path ? $path."/" : "")."index.php?title=Special:Version";
    $doc = $parser->parsefile($url);

    my $html = $doc->toString();
    utf8::encode($html);

    if ($html =~ /<td>.*www\.mediawiki\.org.*<\/td>.*[\n]*[\t]*.*<td>.*r([\d]+).*<\/td>/m ) {
	$mediawikiRevision = $1;
    }

    while ($html =~ /<td>.*(http.*mediawiki.*xtension:[^\"]+)[^>]+>([^>]+)<\/a>.* (\d{4}-\d{2}-\d{2}|\d+\.*\d*\.*\d*|).*<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>/mg ) {
	my %extension;

	$extension{url} = $1;
	$extension{title} = $2;
	$extension{version} = $3;
	$extension{description} = $4;
	$extension{author} = $5;

	$extension{description} =~ s/\<[^>]+\>//g;
	$extension{description} = decode_entities($extension{description});
	
	push(@extensions, \%extension);
    }
}

sub printAll {
    my $self = shift;

    return unless ($doc);

    print "[Mediawiki]\n";
    print "$mediawikiRevision\n\n";

    foreach my $extension (@extensions) {
	print "[Extension]\n";
	print "title: ".$extension->{title}."\n";
	print "description: ".$extension->{description}."\n";
	print "url: ".$extension->{url}."\n";
	print "version: ".$extension->{version}."\n";
	print "author: ".$extension->{author}."\n";
	print "\n";
    }
}

sub logger {
    my $self = shift;
    if (@_) { $logger = shift }
    return $logger;
}

sub log {
    my $self = shift;
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
