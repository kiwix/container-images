package MediaWiki::Install;

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use LWP::UserAgent;
use XML::DOM;
use HTML::Entities qw(decode_entities);

my $mediawikiDirectory;
my $extensionDirectory;
my $logger;
my $doc;
my $mediawikiRevision = "";
my @extensions;
my $filter=".*";

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

    while ($html =~ /<td>.*(http.*mediawiki.*xtension:[^\"]+)[^>]+>([^>]+)<\/a>.* (\d{4}-\d{2}-\d{2}|\d+\.*\d*\.*\d*|r\d+|).*<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>/mg ) {
	my %extension;

	$extension{url} = $1;
	$extension{title} = $2;

	$extension{version} = $3 || "head ";

	$extension{description} = $4;
	$extension{author} = $5;

	$extension{description} =~ s/\<[^>]+\>//g;
	$extension{description} = decode_entities($extension{description});

	$extension{version} =~ s/r// ;
	
	push(@extensions, \%extension);
    }
}

sub getRequireOnce {
    my $self = shift;
    my $url = shift;

    my $ua = LWP::UserAgent->new();
    my $parser = new XML::DOM::Parser (LWP_UserAgent => $ua);

    $doc = $parser->parsefile($url);

    my $html = $doc->toString();
    utf8::encode($html);

    if ($html =~ /(require_once|include).*extensions(\S*\.php).*/ ) {
        my $require_once = $2;
	$require_once =~ s/\<[^>]+\>//g;
	return $require_once;
    } 

    unless ($url =~ /installation/ ) {
	my $require_once = $self->getRequireOnce($url."/installation");
	if ($require_once) { return $require_once }
    }

    return "";

}

sub go {
    my $self = shift;
    my $action = shift;

    return unless ($doc);

    if ("Mediawiki" =~ /$filter/i ) {
	if ($action eq "print") {
	    print "[Mediawiki]\n";
	    print "revision: $mediawikiRevision\n\n";
	} elsif ($action eq "svn" ) {
	    print "svn co -r ".$mediawikiRevision." http://svn.wikimedia.org/svnroot/mediawiki/trunk/phase3 ".$self->mediawikiDirectory()."\n";
	}
    }

    foreach my $extension (@extensions) {

	next unless ($extension->{title} =~ /$filter/i );

	my $require_once = $self->getRequireOnce($extension->{url});

	if ($action eq "print") {
	    print "[Extension]\n";
	    print "title: ".$extension->{title}."\n";
	    print "description: ".$extension->{description}."\n";
	    print "url: ".$extension->{url}."\n";
	    print "version: ".$extension->{version}."\n";
	    print "author: ".$extension->{author}."\n";
	    print "require:".$require_once."\n";
	    print "\n";
	} elsif ($action eq "svn" ) {

	    if ($require_once) {
		if ( $extension->{version} =~ /\./) {
		    my $revision = $extension->{version};
		    $revision =~ s/\./\_/gm;

		    if (length($revision) == 3) {
			$revision .= "_0";
		    }

		    $revision = "REL".$revision;
		    my $command = "svn info --xml http://svn.wikimedia.org/svnroot/mediawiki/tags/".$revision." | grep \"revision\" | sed -n \"2p\" | sed -e \"s/.*=\\\"//\" | sed -e \"s/\\\".*//\"";
		    $revision  = `$command`;
		    $revision =~ s/\n//g; 
		    $extension->{version} = $revision;
		}
		print "svn co -r ".$extension->{version}." http://svn.wikimedia.org/svnroot/mediawiki/trunk/extensions".$require_once." ".$self->extensionDirectory()."\n";
	    } else {
		$self->log("error", "Unable to find a path for the extension '".$extension->{title}."'");
	    }

	}
    }
}

sub logger {
    my $self = shift;
    if (@_) { $logger = shift }
    return $logger;
}

sub filter {
    my $self = shift;
    if (@_) { $filter = shift }
    return $filter;
}

sub mediawikiDirectory {
    my $self = shift;
    if (@_) { $mediawikiDirectory = shift }
    return $mediawikiDirectory;
}

sub extensionDirectory {
    my $self = shift;
    if (@_) { $extensionDirectory = shift }
    return $extensionDirectory;
}

sub log {
    my $self = shift;
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
