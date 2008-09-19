package MediaWiki::Mirror;

use strict;
use warnings;
use LWP::UserAgent;
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
my $noTextMirroring : shared = 0;
    
my %pageDownloadQueue : shared;
my @pageUploadQueue : shared;
my %imageDownloadQueue : shared;
my @imageUploadQueue : shared;
my %imageDependenceQueue : shared;
my %templateDependenceQueue : shared;
my %redirectQueue : shared;

my %pageErrorQueue : shared;
my %imageErrorQueue : shared;

my %pageDoneQueue : shared;
my %imageDoneQueue : shared;

my @pageDownloadThreads;
my @pageUploadThreads;
my @imageDownloadThreads;
my @imageUploadThreads;
my @imageDependenceThreads;
my @templateDependenceThreads;
my @redirectThreads;

my $pageDownloadThreadCount = 1;
my $pageUploadThreadCount = 2;
my $imageDownloadThreadCount = 1;
my $imageUploadThreadCount = 2;
my $imageDependenceThreadCount = 2;
my $templateDependenceThreadCount = 2;
my $redirectThreadCount = 2;

my $isRunnable : shared = 1;
my $delay : shared = 1;
my $revisionCallback : shared = "getLastNonAnonymousEdit";
my $currentTaskCount : shared = 0;
my $uploadQueueMaxSize : shared = 42;

my $logger;
my $loggerMutex : shared = 1;

my $imageDownloadMutex : shared = 1;
my $pageDownloadMutex : shared = 1;
my $redirectMutex : shared = 1;
my $templateDependenceMutex : shared = 1;
my $imageDependenceMutex : shared = 1;

my %hasFilePathCache : shared;

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

    $self->log("info", $redirectThreadCount." redirect check thread(s) start");
    for (my $i=0; $i<$redirectThreadCount; $i++) {
	$redirectThreads[$i] = threads->new(\&checkRedirects, $self);
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
    my $imageDoneCount = -1;
    my $pageDoneCount = -1;

    while ($self->isRunnable()) {
	sleep($self->delay() * 5);

	lock($pageDownloadMutex);
	next if (%pageDownloadQueue);

	lock(@pageUploadQueue);
	next if (@pageUploadQueue);

	lock($imageDownloadMutex);
	next if (%imageDownloadQueue);

	lock(@imageUploadQueue);
	next if (@imageUploadQueue);

	lock($imageDependenceMutex);
	next if (%imageDependenceQueue);

	lock($templateDependenceMutex);
	next if (%templateDependenceQueue);

	lock($redirectMutex);
	next if (%redirectQueue);

	unless ($self->currentTaskCount()) {
	    lock($pageDownloadMutex);
	    lock($imageDownloadMutex);

	    if ($imageDoneCount == keys(%imageDoneQueue) && $pageDoneCount == keys(%pageDoneQueue)) {
		last;
	    } else {
		$imageDoneCount = keys(%imageDoneQueue);
		$pageDoneCount = keys(%pageDoneQueue);
	    }

	    if ($self->checkImageDependences()) {
		foreach my $page (keys(%pageDoneQueue)) {
		    $self->addPageToCheckImageDependence($page);
		}
	    }

	    if ($self->checkTemplateDependences()) {
		foreach my $page (keys(%pageDoneQueue)) {
		    $self->addPageToCheckTemplateDependence($page);
		}
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

    if (@_) {
	my $image = ucfirst(shift);
	$image =~ tr/ /_/;

	lock($imageDownloadMutex);
	unless ( exists($imageDoneQueue{$image}) || exists($imageDownloadQueue{$image}) ) {
	    $imageDownloadQueue{$image} = 1;
	}
    }
}

sub getImageToDownload {
    my $self = shift;
    my $image;
    
    lock($imageDownloadMutex);

    if (keys(%imageDownloadQueue)) {
	($image) = keys(%imageDownloadQueue);

	if ($image) { 
	    $self->addImageDone($image);
	    delete($imageDownloadQueue{$image});
	} else {
	    $self->log("error", "empty image title found in getImageToDownload()");
	}
    }

    return $image;
}

sub addImageDone {
    my $self = shift;
    my $image = shift;

    lock($imageDownloadMutex);
    $imageDoneQueue{$image} = 1;
}

sub addImageError {
    my $self = shift;
    my $image = shift;

    lock(%imageErrorQueue);
    $imageErrorQueue{$image} = 1;
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
		$self->log("info", "Image '$image' is already an uptodate content.");
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

    while ($self->getImageUploadQueueSize() > $self->uploadQueueMaxSize()) {
	sleep($self->delay());
#	$self->log("info", "Full image upload queue, waiting ".$self->delay()." s. before adding a image.");
    }

    lock(@imageUploadQueue);
    if ($image) { 
	push(@imageUploadQueue, $image, $content, $summary) ;
    }
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
}

sub getImageUploadQueueSize {
    my$self = shift;

    lock(@imageUploadQueue);
    return scalar(@imageUploadQueue);
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
    my $page = shift;

    return unless $page;

    lock($templateDependenceMutex);
    $templateDependenceQueue{$page} = 1;
}

sub getPageToCheckTemplateDependence {
    my $self = shift;
    my $page;

    lock($templateDependenceMutex);
    if (%templateDependenceQueue)
    { 
	($page) = keys(%templateDependenceQueue);
	if ($page) {
	    delete($templateDependenceQueue{$page});
	}
    }

    return $page;
}

sub checkTemplateDependences {
    my $self = shift;
    lock($checkTemplateDependences);
    if (scalar(@_)) { $checkTemplateDependences = shift }
    return $checkTemplateDependences;
}

# check redirects
sub checkRedirects {
    my $self = shift;
    my $site = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					 $self->sourceMediawikiPassword(), 
					 $self->sourceMediawikiHost(),
					 $self->sourceMediawikiPath(),
					 $self->sourceHttpUsername(),
                                         $self->sourceHttpPassword(),
					 $self->sourceHttpRealm());
    
    while ($self->isRunnable() && $site) {
	my $title = $self->getPageToCheckRedirects();

	if ($title) {
	    $self->incrementCurrentTaskCount();

	    my $redirects = $site->redirects($title);
	    my $toMirrorCount = 0;

	    foreach my $redirect (@$redirects) {
		$toMirrorCount++;
		utf8::encode($redirect);
		$self->addPageToDownload($redirect);
	    }
	    $self->log("info", "$toMirrorCount redirects found for '$title'");

	    $self->decrementCurrentTaskCount();
	} else {
	    sleep($self->delay());
	}
    }
}

sub addPageToCheckRedirects {
    my $self = shift;
    my $page = shift;

    return unless ($page);

    lock($redirectMutex);
    $redirectQueue{$page} = 1;
}

sub getPageToCheckRedirects {
    my $self = shift;
    my $page;

    lock($redirectMutex);

    if (%redirectQueue) { 
	($page) = keys(%redirectQueue);
	if ($page) {
	    delete($redirectQueue{$page});
	}
    }

    return $page;
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
    my $page = shift;

    return unless ($page);

    lock($imageDependenceMutex);
    $imageDependenceQueue{$page} = 1;
}

sub getPageToCheckImageDependence {
    my $self = shift;
    my $page;

    lock($imageDependenceMutex);
    if (%imageDependenceQueue)
    { 
	($page) = keys(%imageDependenceQueue);
	if ($page) {
	    delete($imageDependenceQueue{$page});
	}
    }

    return $page;
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
    my $title;
    my $page;
    my $id;
    my $summary;
    my $history;
    my $content;
    my $redirectTarget;

    my $site = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					 $self->sourceMediawikiPassword(),
					 $self->sourceMediawikiHost(),
					 $self->sourceMediawikiPath(),
					 $self->sourceHttpUsername(),
                                         $self->sourceHttpPassword(),
					 $self->sourceHttpRealm());

    my $revisionCallback = $self->revisionCallback();

    while ($self->isRunnable() && $site) {
	$title = $self->getPageToDownload();
	
	if ($title) {
	    $self->incrementCurrentTaskCount();
	    $page = $site->get($title, "r");

	    if ($page->{exists}) {
		$history = $page->history(\&$revisionCallback);
		
		if (ref($history) eq 'ARRAY') {
		    ($id, $summary) = @{$history};
		}
		
		$content = $id ? $page->oldid($id) : $page->content();
		$self->addPageToUpload($title, $content, $summary);
		$self->log("info", "Page '$title' successfuly downloaded.");
		
		if ($self->followRedirects()) {
		    $redirectTarget = $self->isRedirectContent(\$content);
		    if ($redirectTarget) {
			$self->log("info", "Page '$title' is a redirect to '$redirectTarget'.");
			$self->addPageToDownload($redirectTarget);
		    }
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
    my $page = shift;

    if ($page) {
	$page = ucfirst($page);
	$page =~ tr/ /_/;

	lock($pageDownloadMutex);
	unless ( exists($pageDoneQueue{$page}) || exists($pageDownloadQueue{$page})) {
	    $pageDownloadQueue{$page} = 1;
	}
    } else {
	$self->log("error", "empty page title given to addPageToDownload()");
    }
}

sub getPageToDownload {
    my $self = shift;
    my $page;

    lock($pageDownloadMutex);

    if (scalar(%pageDownloadQueue)) {
	($page) = keys(%pageDownloadQueue);

	if ($page) { 
	    $self->addPageDone($page);
	    delete($pageDownloadQueue{$page});
	} else {
	    $self->log("error", "empty page title found in getPageToDownload()");
	}
    }

    return $page;
}

sub addPageDone {
    my $self = shift;
    my $page = shift;

    lock($pageDownloadMutex);
    $pageDoneQueue{$page} = 1;
}

sub addPageError {
    my $self = shift;
    my $page = shift;

    lock(%pageErrorQueue);
    $pageErrorQueue{$page} = 1;
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
		$self->log("info", "Page '$title' has already an uptodate content.");
	    } else {
		$page->{content} = $content;
		$page->{summary} = $summary;

		if ($page->save()) {
		    $self->log("info", "Page '$title' successfuly uploaded");
		} else {
		    $self->addPageError($title);
		    $self->log("error", "Unable to write the page '$title'.");
		}
	    }

	    unless ($self->isRedirectContent(\$content)) {
		if ($self->checkTemplateDependences()) {
		    $self->addPageToCheckTemplateDependence($title);
		}
		
		if ($self->checkImageDependences()) {
		    $self->addPageToCheckImageDependence($title);
		}
	    }

	    $self->addPageToCheckRedirects($title);

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

    while ($self->getPageUploadQueueSize() > $self->uploadQueueMaxSize()) {
	sleep($self->delay());
    }

    lock(@pageUploadQueue);
    if ($title && !$self->noTextMirroring()) { push(@pageUploadQueue, $title, $content, $summary) }
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
}

sub getPageUploadQueueSize {
    my $self = shift;
    lock(@pageUploadQueue);
    return scalar(@pageUploadQueue);
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
		    'wiki' => { 'host' => $host, 'path' => $path, 'has_query' => 1, 'has_filepath' => $self->hasFilePath($host, $path) } } );

    if ($site->{error}) {
	$self->isRunnable(0);
	$self->log("error", "connection to the $host mediawiki failed.");
	$site = undef;
    }

    return $site;
}

sub hasFilePath {
    my $self = shift;
    my ($host, $path) = @_;
    my $hasFilePath = 0;

    lock(%hasFilePathCache);
    if (exists($hasFilePathCache{$host})) {
	return $hasFilePathCache{$host};
    }

    my $url = "http://".$host."/".($path ? $path."/" : "")."index.php?title=Special:Version";
    my $html = $self->downloadTextFromUrl($url);

    if ($html =~ /filepath/i ) {
	$self->log("info", "Site $host has the FilePath extension\n");
	$hasFilePath = 1;
    } else {
	$self->log("info", "Site $host does not have the FilePath extension\n");
    }

    $hasFilePathCache{$host} = $hasFilePath;

    return $hasFilePath;
}

sub downloadTextFromUrl {
    my $self = shift;
    my $url = shift;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($url);

    my $data = $response->content;
    my $encoding = $response->header('Content-Encoding');

    if ($encoding && $encoding =~ /gzip/i) {
	$data = Compress::Zlib::memGunzip($data);
    }

    return $data;
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
sub isRedirectContent {
    my $self = shift;
    my $content = shift;
    if ( $$content =~ /\#REDIRECT[ ]*\[\[[ ]*(.*)[ ]*\]\]/ ) {
	return $1;
    }
    return "";
}

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

sub uploadQueueMaxSize {
    my $self = shift;
    lock($uploadQueueMaxSize);
    if (@_) { $uploadQueueMaxSize = shift }
    return $uploadQueueMaxSize;
}

sub noTextMirroring {
    my $self = shift;
    lock($noTextMirroring);
    if (@_) { $noTextMirroring = shift }
    return $noTextMirroring;
}

sub addPagesToMirror {
    my $self = shift;
    
    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
                                         $self->destinationMediawikiPassword(),
                                         $self->destinationMediawikiHost(),
                                         $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
                                         $self->destinationHttpPassword(),
					 $self->destinationHttpRealm());

    foreach my $page (@_) { 
	if (!$self->checkCompletedPages() || $site->exists()) {
	    $self->addPageToDownload($page);
	}

	if (my $imageName = $self->extractImageNameFromPageName($page)) {
	    $self->addImageToDownload($imageName);
	}
    }
}

sub extractImageNameFromPageName {
   my $self = shift;
   my $page = shift;

   if ($page =~ /(image\:)(.*)/i ) {
       return $2;
   }
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

    return;

    sub queueListToString {
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

    sub queueHashToString {
	my $queue = shift;
	my $step = shift;
	my $string = "";
	for (my $i=0; $i<scalar(@$queue); $i++) {
	    unless ($i % $step) {
		$string .= $queue->[$i*2]."\n";
	    }
	}
	$string .= "\n";
	return $string;
    }

    lock($pageDownloadMutex);
    $statusString .= "[pageDownloadQueue]\n";
    $statusString .= queueHashToString(\%pageDownloadQueue, 1);

    lock(@pageUploadQueue);
    $statusString .= "[pageUploadQueue]\n";
    $statusString .= queueListToString(\@pageUploadQueue, 3);

    lock(%imageDownloadQueue);
    $statusString .= "[imageDownloadQueue]\n";
    $statusString .= queueHashToString(\%imageDownloadQueue, 1);

    lock(@imageUploadQueue);
    $statusString .= "[imageUploadQueue]\n";
    $statusString .= queueListToString(\@imageUploadQueue, 3);

    lock($imageDependenceMutex);
    $statusString .= "[imageDependenceQueue]\n";
    $statusString .= queueHashToString(\%imageDependenceQueue, 1);

    lock($templateDependenceMutex);
    $statusString .= "[templateDependenceQueue]\n";
    $statusString .= queueHashToString(\%templateDependenceQueue, 1);

    lock($redirectMutex);
    $statusString .= "[redirectQueue]\n";
    $statusString .= queueHashToString(\%redirectQueue, 1);

    lock(%pageErrorQueue);
    $statusString .= "[pageErrorQueue]\n";
    $statusString .= queueHashToString(\%pageErrorQueue, 1);

    lock(%imageErrorQueue);
    $statusString .= "[imageErrorQueue]\n";
    $statusString .= queueHashToString(\%imageErrorQueue, 1);

    lock($pageDownloadMutex);
    $statusString .= "[pageDoneQueue]\n";
    $statusString .= queueHashToString(\%pageDoneQueue, 1);

    lock(%imageDoneQueue);
    $statusString .= "[imageDoneQueue]\n";
    $statusString .= queueHashToString(\%imageDoneQueue, 1);

    $statusString .= "[currentTaskCount]\n";
    $statusString .= $self->currentTaskCount()."\n";

    return $statusString;
}

1;
