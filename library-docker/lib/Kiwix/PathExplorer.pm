package Kiwix::PathExplorer;

use strict;
use warnings;
use Data::Dumper;
use File::Find;
use threads;
use threads::shared;

# path to explore
my $path : shared = "";

# Should follow symlinks
my $followSymlinks : shared = 0;

# files
my $filesMutex : shared = 1;
my @files : shared;

# max file in @files
my $bufferSize : shared = 10000;

# exploring thread
my $exploring : shared = 0;
my $thread;

# logger
my $loggerMutex : shared = 1;
my $logger;

# filter on file names
my $filterRegexp : shared;

# do not serve directories
my $ignoreDirectories : shared = 1;

# ready to start again
my $resetFlag : shared = 1;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub getNext {
    my $self = shift;

    # check path
    unless ($self->path()) {
	$self->log("error", "Please specify a path before exploring it.");
	return;
    }

    # explore thread management
    if (!exploring()) {
	if (fileCount()) { # file to serve, the explore thread should be finished
	    eval { $thread->join() };
	} elsif (resetFlag()) { # no file to serve the explore thread should be started
	    $self->log("info", "Start find on ".$self->path().".");
	    exploring(1);
	    $thread = threads->new(\&explore, $self);

	    # wait that find() delivers the first files
	    do {
		sleep(0.1);
	    } while (!fileCount() && exploring());
	}
    }

    # check if we have to wait
    while (!fileCount() && exploring()) {
	sleep(0.1);
    }

    # return a file path
    do {
	my $filename = "";
	$filename = shiftFile();

	# check if the file is a directory
	unless (!$filename || ($self->ignoreDirectories() && -d $filename)) {
	    if ($self->filterRegexp()) {
		return $filename
		    if ($filename =~ m/$filterRegexp/ig );
	    } else {
		return $filename;
	    }
	}
    } while (exploring() || fileCount());
    
    eval { $thread->join() };

    return;
}

sub explore {
    my $self = shift;

    # call find()
    find({ wanted => \&exploreCallback, follow =>  1}, $self->path());

    # set the exploring flag
    exploring(0);

    # set the reset
    resetFlag(0);
}

sub exploreCallback {
    # sleep is the buffer is full

    while (fileCount() > bufferSize() ) {
	sleep(0.1);
    }

    lock($filesMutex);
    push(@files, ($followSymlinks && $File::Find::fullname) ? $File::Find::fullname : $File::Find::name);
}

sub reset {
    my $self = shift;

    # set flag to 0
    exploring(0);

    # set file to empty list
    lock($filesMutex);
    @files = ();

    # remove thread
    eval { $thread->join() };

    # resetFlag
    resetFlag(1);
}

sub DESTROY { 
    eval { $thread->join() };
}  

sub resetFlag {
    lock($resetFlag);
    if (@_) { $resetFlag = shift }
    return $resetFlag;
}

sub path {
    my $self = shift;
    lock($path);
    if (@_) { $path = shift }
    return $path;
}

sub followSymlinks {
    my $self = shift;
    lock($followSymlinks);
    if (@_) { $followSymlinks = shift }
    return $followSymlinks;
}

sub shiftFile() {
    lock($filesMutex);
    return shift(@files);    
}

sub fileCount {
    lock($filesMutex);
    return scalar(@files);
}

sub exploring {
    lock($exploring);
    if (@_) { $exploring = shift }
    return $exploring;
}

sub bufferSize {
    lock($bufferSize);
    if (@_) { $bufferSize = shift }
    return $bufferSize;
}

sub filterRegexp {
    my $self = shift;
    lock($filterRegexp);
    if (@_) { $filterRegexp = shift }
    return $filterRegexp;
}

sub ignoreDirectories {
    my $self = shift;
    lock($ignoreDirectories);
    if (@_) { $ignoreDirectories = shift }
    return $ignoreDirectories;
}

# loggin
sub logger {
    my $self = shift;
    lock($loggerMutex);
    if (@_) { $logger = shift }
    return $logger;
}

sub log {
    my $self = shift;
    lock($loggerMutex);
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
