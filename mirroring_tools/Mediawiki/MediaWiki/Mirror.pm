package MediaWiki::Mirror;

use strict;
use warnings;
use Data::Dumper;
use MediaWiki;

use threads;
use threads::shared;

my $sourceMediawikiHost : shared = undef;
my $sourceMediawikiPath : shared = undef;
my $sourceMediawikiUsername : shared = undef;
my $sourceMediawikiPassword : shared = undef;
my $sourceHttpRealm : shared = undef;
my $sourceHttpUsername : shared = undef;
my $sourceHttpPassword : shared = undef;    

my $destinationMediawiki : shared = undef;
my $destinationMediawikiHost : shared = undef;
my $destinationMediawikiPath : shared = undef;
my $destinationMediawikiUsername : shared = undef;
my $destinationMediawikiPassword : shared = undef;
my $destinationHttpRealm : shared = undef;
my $destinationHttpUsername : shared = undef;
my $destinationHttpPassword : shared = undef;
    
my $followRedirects : shared = 1;
my $checkTemplateDependences : shared = 1;
my $checkImageDependences : shared = 1;
my $checkCompletedPages : shared = 0;
my $checkCompletedImages : shared = 0;
    
my @pageDownloadQueue : shared;
my @pageUploadQueue : shared;
my @imageDownloadQueue : shared;
my @imageUploadQueue : shared;
my @imageDependenceQueue : shared;
my @templateDependenceQueue : shared;

my @pageErrorQueue : shared;
my @imageErrorQueue : shared;

my @pageDoneQueue : shared;
my @imageDoneQueue : shared;

my @pageDownloadThreads;
my @pageUploadThreads;
my @imageDownloadThreads;
my @imageUploadThreads;
my @imageDependenceThreads;
my @templateDependenceThreads;

my $pageDownloadThreadCount = 1;
my $pageUploadThreadCount = 3;
my $imageDownloadThreadCount = 1;
my $imageUploadThreadCount = 3;
my $imageDependenceThreadCount = 5;
my $templateDependenceThreadCount = 3;
    
my $isRunnable : shared = 1;
my $delay : shared = 1;
my $revisionCallback : shared = "getLastNonAnonymousEdit";
my $currentTaskCount : shared = 0;

my $logger;
my $loggerMutex : shared = 1;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub startMirroring {
    my $self = shift;
    my @threads;

    $self->log("info", "================================================================");
    $self->log("info", "Mirroring start");
    $self->log("info", "================================================================");

    $self->log("info", $pageUploadThreadCount." page upload thread(s) start");
    for (my $i=0; $i<$pageUploadThreadCount; $i++) {
	$pageUploadThreads[$i] = threads->new(\&uploadPages, $self);
    }

    $self->log("info", $pageDownloadThreadCount." page download thread(s) start");
    for (my $i=0; $i<$pageDownloadThreadCount; $i++) {
	$pageDownloadThreads[$i] = threads->new(\&downloadPages, $self);
    }

    $self->log("info", $templateDependenceThreadCount." template dependences thread(s) start");
    for (my $i=0; $i<$templateDependenceThreadCount; $i++) {
	$templateDependenceThreads[$i] = threads->new(\&checkTemplates, $self);
    }

    $self->log("info", $imageDependenceThreadCount." image dependences thread(s) start");
    for (my $i=0; $i<$imageDependenceThreadCount; $i++) {
	$imageDependenceThreads[$i] = threads->new(\&checkImages, $self);
    }

    $self->log("info", $imageDownloadThreadCount." image download thread(s) start");
    for (my $i=0; $i<$imageDownloadThreadCount; $i++) {
	$imageDownloadThreads[$i] = threads->new(\&downloadImages, $self);
    }

    $self->log("info", $imageUploadThreadCount." image upload thread(s) start");
    for (my $i=0; $i<$imageUploadThreadCount; $i++) {
	$imageUploadThreads[$i] = threads->new(\&uploadImages, $self);
    }

    $self->log("info", "All threads are now started.");
}

sub stopMirroring {
    my $self = shift;
    $self->isRunnable(0);

    $self->log("info", "Mirroring will be stopped.");

    for (my $i=0; $i<$pageDownloadThreadCount; $i++) {
	$pageDownloadThreads[$i]->join();
    }

    for (my $i=0; $i<$pageUploadThreadCount; $i++) {
	$pageUploadThreads[$i]->join();
    }

    for (my $i=0; $i<$templateDependenceThreadCount; $i++) {
	$templateDependenceThreads[$i]->join();
    }

    for (my $i=0; $i<$imageDependenceThreadCount; $i++) {
	$imageDependenceThreads[$i]->join();
    }

    for (my $i=0; $i<$imageDownloadThreadCount; $i++) {
	$imageDownloadThreads[$i]->join();
    }

    for (my $i=0; $i<$imageUploadThreadCount; $i++) {
	$imageUploadThreads[$i]->join();
    }

    $self->log("info", "================================================================");
    $self->log("info", "Mirroring stop");
    $self->log("info", "================================================================");
}

sub wait {
    my $self = shift;
    my $lastImageDependenceCheck = 1;

    while ($self->isRunnable()) {
	sleep($self->delay() * 5);

	lock(@pageDownloadQueue);
	next if (@pageDownloadQueue);

	lock(@pageUploadQueue);
	next if (@pageUploadQueue);

	lock(@imageDownloadQueue);
	next if (@imageDownloadQueue);

	lock(@imageUploadQueue);
	next if (@imageUploadQueue);

	lock(@imageDependenceQueue);
	next if (@imageDependenceQueue);

	lock(@templateDependenceQueue);
	next if (@templateDependenceQueue);

	unless ($self->currentTaskCount()) {
	    if ($lastImageDependenceCheck && $self->checkImageDependences()) {
		lock(@pageDoneQueue);
		foreach my $page (@pageDoneQueue) {
		    $self->addPageToCheckImageDependence($page);
		}
		$lastImageDependenceCheck = 0;
	    } else {
		last;
	    }
	}
    }
    
    $self->stopMirroring();
}

# download images
sub downloadImages {
    my $self = shift;

    my $site = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					 $self->sourceMediawikiPassword(),
					 $self->sourceMediawikiHost(),
					 $self->sourceMediawikiPath(),
					 $self->sourceHttpUsername(),
                                         $self->sourceHttpPassword(),
                                         $self->sourceHttpRealm(),
					 );

    while ($self->isRunnable() && $site) {
	my $image = $self->getImageToDownload();
	
	if ($image) {
	    $self->incrementCurrentTaskCount();
	    my $content = $site->download($image);

	    if ( $content ) {
		my $summary = "mirror image";
		$self->addImageToUpload($image, $content, $summary);
		$self->log("info", "Image '$image' successfuly downloaded.");
	    } else {
		$self->log("info", "The image '$image' does not exist.");
		$self->addImageError($image);
	    }
	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addImageToDownload {
    my $self = shift;
    lock(@imageDownloadQueue);
    lock(@imageDoneQueue);
    if (@_) {
	my $image = ucfirst(shift);
	unless ( grep(/^$image$/, @imageDoneQueue) || grep(/^$image$/, @imageDownloadQueue) ) {
	    push(@imageDownloadQueue, $image);
	}
    }
}

sub getImageToDownload {
    my $self = shift;
    lock(@imageDownloadQueue);
    if (scalar(@imageDownloadQueue)>0) { 
	my $image = pop(@imageDownloadQueue);
	$self->addImageDone($image);
	return $image;
    }
    return undef;
}

sub addImageDone {
    my $self = shift;
    lock(@imageDoneQueue);
    if (@_) { push(@imageDoneQueue, shift) };
}

sub addImageError {
    my $self = shift;
    lock(@imageErrorQueue);
    if (@_) { push(@imageErrorQueue, shift) };
}

# upload images
sub uploadImages {
    my $self = shift;

    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					 $self->destinationMediawikiPassword(),
					 $self->destinationMediawikiHost(),
					 $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
                                         $self->destinationHttpPassword(),
                                         $self->destinationHttpRealm());

    while ($self->isRunnable() && $site) {
	my ($image, $content, $summary) = $self->getImageToUpload();

	if ($image) {
	    $self->incrementCurrentTaskCount();
	    my $currentContent = $site->download($image);

	    if ($currentContent && $currentContent eq $content) {
		$self->log("info", "Image '$image' has already an uptodate content.");
	    } else {
		if ($site->upload($image, $content, $summary, 1)) {
		    $self->log("info", "Image '$image' successfuly uploaded.");
		} else {
		    $self->addImageError($image);
		    $self->log("error", "Unable to write the image '$image'.");
		}
	    }
	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addImageToUpload {
    my $self = shift;
    my $image = shift || "";
    my $content = shift || "";
    my $summary = shift || "";
    lock(@imageUploadQueue);
    if ($image) { push(@imageUploadQueue, $image, $content, $summary) }
}

sub getImageToUpload {
    my $self = shift;
    lock(@imageUploadQueue);
    if (scalar(@imageUploadQueue)>=3) {
	my $summary = pop(@imageUploadQueue) || "";
	my $content = pop(@imageUploadQueue) || "";
	my $image = pop(@imageUploadQueue) || "";
	return ($image, $content, $summary);
    }
    return undef;
}

sub checkCompletedImages {
    my $self = shift;
    lock($checkCompletedImages);
    if (@_) { $checkCompletedImages = shift };
    return $checkCompletedImages;
}

# check template dependences
sub checkTemplates {
    my $self = shift;

    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					 $self->destinationMediawikiPassword(), 
					 $self->destinationMediawikiHost(),
					 $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
                                         $self->destinationHttpPassword(),
					 $self->destinationHttpRealm());
    
    while ($self->isRunnable() && $site) {
	my $title = $self->getPageToCheckTemplateDependence();
	
	if ($title) {
	    $self->incrementCurrentTaskCount();
	    my $deps = $site->templateDependences($title);
	    my $toMirrorCount = 0;
	    
	    foreach my $dep (@$deps) {
		if (exists($dep->{"missing"}) || $self->checkCompletedPages()) {
		    $toMirrorCount++;
		    my $template = $dep->{"title"};
		    utf8::encode($template);
		    
		    # case of under page
		    if ($template =~ /(^[^\:]+\:)(\/.*$)/ ) {
			$template = $title.$2;
		    }

		    $self->addPageToDownload($template);
		}
	    }
	    $self->log("info", "$toMirrorCount/".scalar(@$deps)." template dependence(s) found for '$title'");

	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addPageToCheckTemplateDependence {
    my $self = shift;
    lock(@templateDependenceQueue);
    if (@_) { push(@templateDependenceQueue, shift) };
}

sub getPageToCheckTemplateDependence {
    my $self = shift;
    lock(@templateDependenceQueue);
    if (scalar(@templateDependenceQueue)>0) { return pop(@templateDependenceQueue) }
    return undef;
}

sub checkTemplateDependences {
    my $self = shift;
    lock($checkTemplateDependences);
    if (scalar(@_)) { $checkTemplateDependences = shift }
    return $checkTemplateDependences;
}

# check image dependences
sub checkImages {
    my $self = shift;
    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					 $self->destinationMediawikiPassword(), 
					 $self->destinationMediawikiHost(),
					 $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
                                         $self->destinationHttpPassword(),
					 $self->destinationHttpRealm());
    
    while ($self->isRunnable() && $site) {
	my $title = $self->getPageToCheckImageDependence();

	if ($title) {
	    $self->incrementCurrentTaskCount();

	    my $deps = $site->imageDependences($title);
	    my $toMirrorCount = 0;

	    foreach my $dep (@$deps) {
		if (exists($dep->{"missing"}) || $self->checkCompletedImages()) {
		    $toMirrorCount++;
		    my $image = $dep->{"title"};
		    $image =~ s/Image://;
		    utf8::encode($image);
		    $self->addImageToDownload($image);
		}
	    }
	    $self->log("info", "$toMirrorCount/".scalar(@$deps)." image dependence(s) found for '$title'");

	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addPageToCheckImageDependence {
    my $self = shift;
    lock(@imageDependenceQueue);
    if (@_) { push(@imageDependenceQueue, shift) };
}

sub getPageToCheckImageDependence {
    my $self = shift;
    lock(@imageDependenceQueue);
    if (scalar(@imageDependenceQueue)>0) { return pop(@imageDependenceQueue) }
    return undef;
}

sub checkImageDependences {
    my $self = shift;
    lock($checkImageDependences);
    if (scalar(@_)) { $checkImageDependences = shift }
    return $checkImageDependences;
}

# download pages
sub downloadPages {
    my $self = shift;

    my $site = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					 $self->sourceMediawikiPassword(),
					 $self->sourceMediawikiHost(),
					 $self->sourceMediawikiPath(),
					 $self->sourceHttpUsername(),
                                         $self->sourceHttpPassword(),
					 $self->sourceHttpRealm());

    my $revisionCallback = $self->revisionCallback();

    while ($self->isRunnable() && $site) {
	my $title = $self->getPageToDownload();
	
	if ($title) {
	    $self->incrementCurrentTaskCount();
	    my $page = $site->get($title, "r");

	    if ($page->{exists}) {
		my ($id, $summary) = @{$page->history(\&$revisionCallback)};
		my $content = $id ? $page->oldid($id) : $page->content();
		$self->addPageToUpload($title, $content, $summary);
		$self->log("info", "'$title' successfuly downloaded.");
		
		if ($self->followRedirects() && $content =~ /\#REDIRECT[ ]*\[\[[ ]*(.*)[ ]*\]\]/ ) {
		    $self->log("info", "'$title' is a redirect to '$1'.");
		    $self->addPageToDownload($1);
		}
	    } else {
		$self->log("info", "The page '$title' does not exist.");
		$self->addPageError($title);
	    }
	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addPageToDownload {
    my $self = shift;
    lock(@pageDownloadQueue);
    lock(@pageDoneQueue);
    if (@_) {
	my $page = ucfirst(shift);
	unless ( grep(/^$page$/, @pageDoneQueue) || grep(/^$page$/, @pageDownloadQueue) ) {
	    push(@pageDownloadQueue, $page);
	}
    }
}

sub getPageToDownload {
    my $self = shift;
    lock(@pageDownloadQueue);
    if (scalar(@pageDownloadQueue)>0) { 
	my $page = pop(@pageDownloadQueue);
	$self->addPageDone($page);
	return $page;
    }
    return undef;
}

sub addPageDone {
    my $self = shift;
    lock(@pageDoneQueue);
    if (@_) { push(@pageDoneQueue, shift) };
}

sub addPageError {
    my $self = shift;
    lock(@pageErrorQueue);
    if (@_) { push(@pageErrorQueue, shift) };
}

sub getLastNonAnonymousEdit {
    my $hash = shift;

    if ($hash->{anon}) {
        return undef;
    } else {
        return [($hash->{oldid}, "last non anonymous edit copy")];
    }
}

sub revisionCallback {
    my $self = shift;
    lock($revisionCallback);
    if (@_) { $revisionCallback = shift }
    return $revisionCallback;
}

sub followRedirects {
    my $self = shift;
    lock($followRedirects);
    if (@_) { $followRedirects = shift }
    return $followRedirects;
}

# upload pages
sub uploadPages {
    my $self = shift;

    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					 $self->destinationMediawikiPassword(),
					 $self->destinationMediawikiHost(),
					 $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
                                         $self->destinationHttpPassword(),
					 $self->destinationHttpRealm());

    while ($self->isRunnable() && $site) {
	my ($title, $content, $summary) = $self->getPageToUpload();

	if ($title) {
	    $self->incrementCurrentTaskCount();
	    my $page = $site->get($title, "rw");

	    if ($page->content() && $page->content() eq $content."\n") {
		$self->log("info", "'$title' has already an uptodate content.");
	    } else {
		$page->{content} = $content;
		$page->{summary} = $summary;

		if ($page->save()) {
		    $self->log("info", "'$title' successfuly uploaded");
		} else {
		    $self->addPageError($title);
		    $self->log("error", "Unable to write the page '$title'.");
		}
	    }

	    if ($self->checkTemplateDependences()) {
		$self->addPageToCheckTemplateDependence($title);
	    }

	    if ($self->checkImageDependences()) {
		$self->addPageToCheckImageDependence($title);
	    }

	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addPageToUpload {
    my $self = shift;
    my $title = shift || "";
    my $content = shift || "";
    my $summary = shift || "";
    lock(@pageUploadQueue);
    if ($title) { push(@pageUploadQueue, $title, $content, $summary) }
}

sub getPageToUpload {
    my $self = shift;
    lock(@pageUploadQueue);
    if (scalar(@pageUploadQueue)>=3) {
	my $summary = pop(@pageUploadQueue) || "";
	my $content = pop(@pageUploadQueue) || "";
	my $title = pop(@pageUploadQueue) || "";
	return ($title, $content, $summary);
    }
    return undef;
}

sub checkCompletedPages {
    my $self = shift;
    lock($checkCompletedPages);
    if (@_) { $checkCompletedPages = shift };
    return $checkCompletedPages;
}

# mediawiki site
sub connectToMediawiki {
    my $self = shift;
    my $user = shift;
    my $pass = shift;
    my $host = shift;
    my $path = shift;
    my $httpUser = shift;
    my $httpPass = shift || ''; 
    my $httpRealm = shift || ''; 

    my $site = MediaWiki->new();
    $site->setup({  'bot' => { 'user' => $user, 'pass' => $pass },
		    'http' => { 'user' => $httpUser, 'pass' => $httpPass, 'realm' => $httpRealm },
		    'wiki' => { 'host' => $host, 'path' => $path, 'has_query' => 1, 'has_filepath' => 1 } } );

    if ($site->{error}) {
	$self->isRunnable(0);
	$self->log("error", "connection to the $host mediawiki failed.");
	$site = undef;
    }

    return $site;
}

sub sourceMediawikiHost { 
    my $self = shift; 
    lock($sourceMediawikiHost);
    if (@_) { $sourceMediawikiHost = shift }
    return $sourceMediawikiHost;
}

sub sourceMediawikiPath { 
    my $self = shift; 
    lock($sourceMediawikiPath);
    if (@_) { $sourceMediawikiPath = shift }
    return $sourceMediawikiPath;
}

sub sourceMediawikiUsername {
    my $self = shift;
    lock($sourceMediawikiUsername);
    if (@_) { $sourceMediawikiUsername = shift }
    return $sourceMediawikiUsername;
}

sub sourceMediawikiPassword {
    my $self = shift;
    lock($sourceMediawikiPassword);
    if (@_) { $sourceMediawikiPassword = shift }
    return $sourceMediawikiPassword;
}

sub sourceHttpRealm {
    my $self = shift;
    lock($sourceHttpRealm);
    if (@_) { $sourceHttpRealm = shift }
    return $sourceHttpRealm;
}

sub sourceHttpUsername {
    my $self = shift;
    lock($sourceHttpUsername);
    if (@_) { $sourceHttpUsername = shift }
    return $sourceHttpUsername;
}

sub sourceHttpPassword {
    my $self = shift;
    lock($sourceHttpPassword);
    if (@_) { $sourceHttpPassword = shift }
    return $sourceHttpPassword;
}

sub destinationMediawikiHost { 
    my $self = shift; 
    lock($destinationMediawikiHost);
    if (@_) { $destinationMediawikiHost = shift }
    return $destinationMediawikiHost;
}

sub destinationMediawikiPath { 
    my $self = shift; 
    lock($destinationMediawikiPath);
    if (@_) { $destinationMediawikiPath = shift }
    return $destinationMediawikiPath;
}

sub destinationMediawikiUsername {
    my $self = shift;
    lock($destinationMediawikiUsername);
    if (@_) { $destinationMediawikiUsername = shift }
    return $destinationMediawikiUsername;
}

sub destinationMediawikiPassword {
    my $self = shift;
    lock($destinationMediawikiPassword);
    if (@_) { $destinationMediawikiPassword = shift }
    return $destinationMediawikiPassword;
}

sub destinationHttpRealm {
    my $self = shift;
    lock($destinationHttpRealm);
    if (@_) { $destinationHttpRealm = shift }
    return $destinationHttpRealm;
}

sub destinationHttpUsername {
    my $self = shift;
    lock($destinationHttpUsername);
    if (@_) { $destinationHttpUsername = shift }
    return $destinationHttpUsername;
}

sub destinationHttpPassword {
    my $self = shift;
    lock($destinationHttpPassword);
    if (@_) { $destinationHttpPassword = shift }
    return $destinationHttpPassword;
}

# mirroring stuff
sub isRunnable {
    my $self = shift;
    lock($isRunnable);
    if (@_) { $isRunnable = shift }
    return $isRunnable;
}

sub delay {
    my $self = shift;
    lock($delay);
    if (@_) { $delay = shift }
    return $delay;
}

sub addPagesToMirror {
    my $self = shift;
    foreach my $page (@_) { $self->addPageToDownload($page) }
}

# current task
sub currentTaskCount {
    my $self = shift;
    lock($currentTaskCount);
    return $currentTaskCount;
}

sub incrementCurrentTaskCount {
   my $self = shift;
   lock($currentTaskCount);
   $currentTaskCount += 1;
   return $currentTaskCount;
}

sub decrementCurrentTaskCount {
   my $self = shift;
   lock($currentTaskCount);
   $currentTaskCount -= 1;
   return $currentTaskCount;
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

sub getQueueStatus {
    my $self = shift;
    my $statusString = "";

    sub queueToString {
	my $queue = shift;
	my $step = shift;
	my $string = "";
	for (my $i=0; $i<scalar(@$queue); $i++) {
	    unless ($i % $step) {
		$string .= $queue->[$i]."\n";
	    }
	}
	$string .= "\n";
	return $string;
    }

    lock(@pageDownloadQueue);
    $statusString .= "[pageDownloadQueue]\n";
    $statusString .= queueToString(\@pageDownloadQueue, 1);

    lock(@pageUploadQueue);
    $statusString .= "[pageUploadQueue]\n";
    $statusString .= queueToString(\@pageUploadQueue, 3);

    lock(@imageDownloadQueue);
    $statusString .= "[imageDownloadQueue]\n";
    $statusString .= queueToString(\@imageDownloadQueue, 1);

    lock(@imageUploadQueue);
    $statusString .= "[imageUploadQueue]\n";
    $statusString .= queueToString(\@imageUploadQueue, 3);

    lock(@imageDependenceQueue);
    $statusString .= "[imageDependenceQueue]\n";
    $statusString .= queueToString(\@imageDependenceQueue, 1);

    lock(@templateDependenceQueue);
    $statusString .= "[templateDependenceQueue]\n";
    $statusString .= queueToString(\@templateDependenceQueue, 1);

    lock(@pageErrorQueue);
    $statusString .= "[pageErrorQueue]\n";
    $statusString .= queueToString(\@pageErrorQueue, 1);

    lock(@imageErrorQueue);
    $statusString .= "[imageErrorQueue]\n";
    $statusString .= queueToString(\@imageErrorQueue, 1);

    lock(@pageDoneQueue);
    $statusString .= "[pageDoneQueue]\n";
    $statusString .= queueToString(\@pageDoneQueue, 1);

    lock(@imageDoneQueue);
    $statusString .= "[imageDoneQueue]\n";
    $statusString .= queueToString(\@imageDoneQueue, 1);

    $statusString .= "[currentTaskCount]\n";
    $statusString .= $self->currentTaskCount()."\n";

    return $statusString;
}

1;
