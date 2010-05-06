package MediaWiki::RevisionManager;

use strict;
use warnings;
use Data::Dumper;
use DBI;

my $logger;

sub new {
    my $class = shift;
    my $self = {
	host => "127.0.0.1",
	username => undef,
	password => undef,
	database => undef,
	port => undef,
	dbh => undef,
    };

    bless($self, $class);

    return $self;
}

sub connectToDatabase() {
    my $self = shift;
    my $database = $self->database();
    my $host = $self->host();
    my $port = $self->port();

    my $dsn = "DBI:mysql:$database;host=$host:$port";
    my $dbh = DBI->connect($dsn, $self->username(), $self->password()) or die ("Unable to connect to the database.");
    $self->dbh($dbh);
}

sub deleteOldRevisions {
    my $self = shift;

    # Get all pages
    my $req = "SELECT page_latest, page_id, page_title FROM page WHERE page_id IS NOT NULL";
    my $sth = $self->dbh()->prepare($req) or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");    

    # For each page
    while (my $page = $sth->fetchrow_hashref()) {
	# Get revisions
	my $req2 = "SELECT rev_id FROM revision WHERE rev_page = ".$page->{page_id}." AND rev_id != ".$page->{page_latest};
	my $sth2 = $self->dbh()->prepare($req2) or die ("Unable to prepare request.");
	$sth2->execute() or die ("Unable to execute request.");

	# Build the WHERE clause for the DELETE request
	my $revisions;
	my $revCount = 0;
	while (my $revisionId = $sth2->fetchrow()) {
	    $revisions .= $revisionId.", ";
	    $revCount += 1;
	}
	
	# Remove the last coma
	if ($revisions) {
	    $revisions = substr($revisions, 0, length($revisions)-2);

	    # Delete the revisions
	    my $req3 = "DELETE FROM revision WHERE rev_id IN ( $revisions )";
	    my $sth3 = $self->dbh()->prepare($req3) or die ("Unable to prepare request.");
	    $sth3->execute() or die ("Unable to execute request.");
	}

	# Logging
	$self->log("info", "Deleting '".$page->{page_title}."' (".$page->{page_id}.")... ". $revCount." revision(s)");
    }

    $self->log("info", "Deleting old revisions done");
}

sub deleteOrphanTexts {
    my $self = shift;
    my %revisionTextIds;

    # Select all (active) revision in the table revision
    $self->log("info", "Getting all text revision ids from 'revision'.");
    my $req = "SELECT DISTINCT rev_text_id FROM revision WHERE rev_text_id IS NOT NULL";
    my $sth = $self->dbh()->prepare($req) or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
    while (my $revisionTextId = $sth->fetchrow()) {
	$revisionTextIds{$revisionTextId} = 1;
    }

    # Select all (active) revision in the table backup
    $self->log("info", "Getting all text revision ids from 'archive'.");
    my $req2 = "SELECT DISTINCT ar_text_id FROM archive WHERE ar_text_id IS NOT NULL";
    my $sth2 = $self->dbh()->prepare($req2) or die ("Unable to prepare request.");
    $sth2->execute() or die ("Unable to execute request.");
    while (my $revisionTextId = $sth2->fetchrow()) {
	$revisionTextIds{$revisionTextId} = 1;
    }

    # Select all text and check if it's used or not
    $self->log("info", "Getting all text revision ids from 'text'.");
    my $req3 = "SELECT old_id FROM text WHERE old_id IS NOT NULL";
    my $sth3 = $self->dbh()->prepare($req3) or die ("Unable to prepare request.");
    $sth3->execute() or die ("Unable to execute request.");
    while (my $revisionTextId = $sth3->fetchrow()) {
	unless (exists($revisionTextIds{$revisionTextId})) {
	    $self->log("info", "Deleting old text revision '$revisionTextId'.");
	    my $req4 = "DELETE FROM text WHERE old_id IN ( $revisionTextId )";
	    my $sth4 = $self->dbh()->prepare($req4) or die ("Unable to prepare request.");
	    $sth4->execute() or die ("Unable to execute request.");
	} else {
	    $self->log("info", "Keeping old text revision '$revisionTextId'.");
	}
    }
}

sub deleteOrphanFiles {
    my $self = shift;

    my $dir = $self->mediawikiDirectory()."/images/archive/*";
    `rm -rf $dir`
}

sub deleteOldImages {
    my $self = shift;
    
    my $req = "TRUNCATE TABLE oldimage";
    my $sth = $self->dbh()->prepare($req) or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
}

sub deleteRemovedFiles {
    my $self = shift;
    
    my $req = "TRUNCATE TABLE filearchive";
    my $sth = $self->dbh()->prepare($req) or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");

    my $dir = $self->mediawikiDirectory()."/images/deleted/*";
    `rm -rf $dir`
}

# logging
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

# parameters
sub database {
    my $self = shift;
    if (@_) { $self->{database} = shift }
    return $self->{database};
}

sub username {
    my $self = shift;
    if (@_) { $self->{username} = shift }
    return $self->{username};
}

sub password {
    my $self = shift;
    if (@_) { $self->{password} = shift }
    return $self->{password};
}

sub host {
    my $self = shift;
    if (@_) { $self->{host} = shift }
    return $self->{host};
}

sub port {
    my $self = shift;
    if (@_) { $self->{port} = shift }
    return $self->{port};
}

sub dbh {
    my $self = shift;
    if (@_) { $self->{dbh} = shift }
    return $self->{dbh};
}

sub mediawikiDirectory {
    my $self = shift;
    if (@_) { $self->{mediawikiDirectory} = shift }
    return $self->{mediawikiDirectory};
}
1;
