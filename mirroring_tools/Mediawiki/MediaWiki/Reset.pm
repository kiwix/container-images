package MediaWiki::Reset;

use strict;
use warnings;
use Data::Dumper;
use DBI;

my $host = "localhost";
my $port = "3306";
my $username = "";
my $password = "";
my $database = "";
my $keepImages;
my $logger;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub reset {
    my $self = shift;
    
    my $dsn = "DBI:mysql:$database;host=$host:$port";
    my $dbh;
    my $req;
    my $sth;
    
    $dbh = DBI->connect($dsn, $username, $password) or die ("Unable to connect to the database.");
    
    foreach my $table ("archive", "categorylinks", "externallinks", "filearchive", "hitcounter", "imagelinks", "langlinks", "logging", "math", "objectcache", "redirect", "page", "pagelinks", "revision", "text", "recentchanges", "searchindex", "templatelinks") {
	$req = "TRUNCATE $table";
	$sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
	$sth->execute() or die ("Unable to execute request.");
    }

    # Keep images?
    unless ($self->keepImages()) {
	foreach my $table ("image", "imageold") {
	    $req = "TRUNCATE $table";
	    $sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
	    $sth->execute() or die ("Unable to execute request.");
	}
    }
}

sub drop {
    my $self = shift;
    
    my $dsn = "DBI:mysql:$database;host=$host:$port";
    my $dbh;
    my $req;
    my $sth;
    
    $dbh = DBI->connect($dsn, $username, $password) or die ("Unable to connect to the database.");

    $req = "DROP DATABASE `$database`";
    $sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
}

sub host {
    my $self = shift;
    if (@_) { $host = shift }
    return $host;
}

sub port {
    my $self = shift;
    if (@_) { $port = shift }
    return $port;
}

sub username {
    my $self = shift;
    if (@_) { $username = shift }
    return $username;
}

sub password {
    my $self = shift;
    if (@_) { $password = shift }
    return $password;
}

sub database {
    my $self = shift;
    if (@_) { $database = shift }
    return $database;
}

sub keepImages {
    my $self = shift;
    if (@_) { $keepImages = shift }
    return $keepImages;
}

# loggin
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
