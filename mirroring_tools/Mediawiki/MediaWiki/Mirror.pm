package MediaWiki::Mirror;

use utf8;
use strict;
use warnings;
use Encode;
use HTML::Template;
use Data::Dumper;
use MediaWiki;
use POSIX qw(strftime);
use URI::Escape;

use threads;
use threads::shared;

my $commonMediawikiHost : shared = undef;
my $commonMediawikiPath : shared = undef;
my $commonMediawikiUsername : shared = undef;
my $commonMediawikiPassword : shared = undef;
my $commonRegexp : shared = undef;    

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
my $checkIncomingRedirects : shared = 0;
my $noTextMirroring : shared = 0;
my $checkEmbeddedIn : shared = 1;

my %pageDownloadQueue : shared;
my @pageUploadQueue : shared;
my %imageDownloadQueue : shared;
my @imageUploadQueue : shared;
my %imageDependenceQueue : shared;
my %templateDependenceQueue : shared;
my %embeddedInQueue : shared;
my %redirectQueue : shared;

my %pageErrorQueue : shared;
my %imageErrorQueue : shared;

my @pageDownloadThreads;
my @pageUploadThreads;
my @imageDownloadThreads;
my @imageUploadThreads;
my @imageDependenceThreads;
my @templateDependenceThreads;
my @redirectThreads;
my @embeddedInThreads;

my $pageDownloadThreadCount = 1;
my $pageUploadThreadCount = 3;
my $imageDownloadThreadCount = 1;
my $imageUploadThreadCount = 3;
my $imageDependenceThreadCount = 3;
my $templateDependenceThreadCount = 3;
my $redirectThreadCount = 3;
my $embeddedInThreadCount = 1;

my $isRunnable : shared = 1;
my $delay : shared = 1;
my $embeddedInDelay : shared = 60;
my $revisionCallback : shared = "getLastNonAnonymousEdit";
my $currentTaskCount : shared = 0;
my $uploadFilesFromUrl : shared = 1;

my $logger;
my $loggerMutex : shared = 1;

my $imageDownloadMutex : shared = 1;
my $pageDownloadMutex : shared = 1;
my $imageUploadMutex : shared = 1;
my $pageUploadMutex : shared = 1;
my $redirectMutex : shared = 1;
my $templateDependenceMutex : shared = 1;
my $imageDependenceMutex : shared = 1;
my $imageErrorMutex : shared = 1;
my $pageErrorMutex : shared = 1;
my $embeddedInMutex : shared = 1;

my $footerPath : shared = 1;

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

    $self->log("info", $embeddedInThreadCount." embedded in page check thread(s) start");
    for (my $i=0; $i<$embeddedInThreadCount; $i++) {
	$embeddedInThreads[$i] = threads->new(\&checkEmbeddedInPages, $self);
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

    for (my $i=0; $i<$redirectThreadCount; $i++) {
	$redirectThreads[$i]->join();
    }

    for (my $i=0; $i<$embeddedInThreadCount; $i++) {
	$embeddedInThreads[$i]->join();
    }

    $self->log("info", "================================================================");
    $self->log("info", "Mirroring stop");
    $self->log("info", "================================================================");
}

sub wait {
    my $self = shift;

    while ($self->isRunnable()) {
	sleep($self->delay() * 5);

	next if ($self->getPageDownloadQueueSize());
	next if ($self->getPageUploadQueueSize());
	next if ($self->getImageDownloadQueueSize());
	next if ($self->getImageUploadQueueSize());
	next if ($self->getTemplateDependenceQueueSize());
	next if ($self->getImageDependenceQueueSize());
	next if ($self->getRedirectQueueSize());
	next if ($self->getEmbeddedInQueueSize());

	unless ($self->currentTaskCount()) {
	    last;
	}
    }

    $self->stopMirroring();
}

sub getDestinationMediawikiIncompletePages {
   my $self = shift;
   my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					$self->destinationMediawikiPassword(), 
					$self->destinationMediawikiHost(),
					$self->destinationMediawikiPath(),
					$self->destinationHttpUsername(),
					$self->destinationHttpPassword(),
					$self->destinationHttpRealm());
   
   my @pages;
   foreach my $page ($site->allPages('0', 'nonredirects')) {
       if ($site->isIncompletePage($page)) {
	   $self->log("info", "'".$page."' is incomplete.");
	   push(@pages, $page);
       } else {
	   $self->log("info", "'".$page."' is already complete.");
       }
   }

   return @pages;
}

# check embedded in pages
sub checkEmbeddedInPages {
    my $self = shift;
    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					 $self->destinationMediawikiPassword(), 
					 $self->destinationMediawikiHost(),
					 $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
					 $self->destinationHttpPassword(),
					 $self->destinationHttpRealm());

    my $templateNamespace = "template";
    if ($site) {
	my %namespaces = $site->namespaces();
        $templateNamespace = $namespaces{10};
    }

    while ( $self->isRunnable() && $site) {
	my %pagesToCheckDependences;

	while ( !$self->getEmbeddedInQueueSize() && $self->isRunnable() ) {
	    sleep($self->delay());
	}

	$self->incrementCurrentTaskCount();

	# get all pages (templates) to get embeddedin pages
	my @titles = $self->getAllPageToCheckEmbeddedInPages();

	# build the list of embeddedin pages
	# this is essential to avoid n-uplet of embeddedin pages
	foreach my $title (@titles) {
	    my @pages = $site->embeddedIn($title);
	    foreach my $page (@pages) {
		next if ($self->isTemplate($page, $templateNamespace));
		$pagesToCheckDependences{$page} = 1;
	    }
	}

	# the number of embeddedin pages
	my $count = scalar(keys(%pagesToCheckDependences));

	$self->log("info", "========================================================================");
	$self->log("info", $count." 'embedded in' pages to check again template & image dependences.");

	$self->log("info", "pageDownloadQueue size: ".$self->getPageDownloadQueueSize());
	$self->log("info", "pageUploadQueue size: ".$self->getPageUploadQueueSize());
	$self->log("info", "imageDownloadQueue size: ".$self->getImageDownloadQueueSize());
	$self->log("info", "imageUploadQueue size: ".$self->getImageUploadQueueSize());
	$self->log("info", "imageDependenceQueue size: ".$self->getImageDependenceQueueSize());
	$self->log("info", "templateDependenceQueue size: ".$self->getTemplateDependenceQueueSize());
	$self->log("info", "embeddedInQueue size: ".$self->getEmbeddedInQueueSize());
	$self->log("info", "redirectQueue size: ".$self->getRedirectQueueSize());

	$self->log("info", "========================================================================");

	if ($count) {
	    
	    # foreach of this page recheck the dependences
	    foreach my $pageToCheckDependences (keys(%pagesToCheckDependences)) {

		# make a null-edit to refresh the dependences, otherwise the result does not change
		$site->touchPage($pageToCheckDependences);

		# add page to check dependences
		$self->addPageToCheckTemplateDependence($pageToCheckDependences);
		$self->addPageToCheckImageDependence($pageToCheckDependences);
	    }
	}

	$self->decrementCurrentTaskCount();
    }
}

sub getEmbeddedInQueueSize {
    my$self = shift;

    lock($embeddedInMutex);
    return scalar(keys(%embeddedInQueue));
}

sub addPageToCheckEmbeddedInPages {
    my $self = shift;
    my $page = shift;

    return unless $page;

    lock($embeddedInMutex);
    $embeddedInQueue{$page} = 1;
}

sub getAllPageToCheckEmbeddedInPages {
    my $self = shift;

    lock($embeddedInMutex);
    my @pages = keys(%embeddedInQueue);
    %embeddedInQueue = ();

    return @pages;
}

# download images
sub downloadImages {
    my $self = shift;
    my $timeOffset;
    my $content;
    my $image;
    my$site = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					$self->sourceMediawikiPassword(),
					$self->sourceMediawikiHost(),
					$self->sourceMediawikiPath(),
					$self->sourceHttpUsername(),
					$self->sourceHttpPassword(),
					$self->sourceHttpRealm());

    while ($self->isRunnable() && $site) {
	$timeOffset = time();
	$image = $self->getImageToDownload();

	if ($image) {
	    $self->incrementCurrentTaskCount();

	    if ($self->uploadFilesFromUrl()) {
		$content = $site->getImageUrl($image);
	    } else {
		$content = $site->downloadImage($image);
	    }

	    if ($content) {
		$self->addImageToUpload($image, $content, "");
		$self->log("info", "Image ".($self->uploadFilesFromUrl() ? "URL": "")." '$image' successfuly downloaded in ".(time() - $timeOffset)."s.");
	    } else {
		$self->log("info", "The image ".($self->uploadFilesFromUrl() ? "URL": "")." '$image' does not exist.");
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
	unless ( exists($imageDownloadQueue{$image}) ) {
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
	    delete($imageDownloadQueue{$image});
	} else {
	    $self->log("error", "empty image title found in getImageToDownload()");
	}
    }

    unless (Encode::is_utf8($image)) {
	$image = decode_utf8($image);
    }

    return $image;
}

sub getImageDownloadQueueSize {
    my$self = shift;

    lock($imageDownloadMutex);
    return scalar(keys(%imageDownloadQueue));
}

sub addImageError {
    my $self = shift;
    my $image = shift;

    lock($imageErrorMutex);
    $imageErrorQueue{$image} = 1;
}

sub existsImageError {
    my $self = shift;
    my $image = shift;
    
    lock($imageErrorMutex);
    return exists($imageErrorQueue{$image});
}

# upload images
sub uploadImages {
    my $self = shift;
    my $timeOffset;
    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					  $self->destinationMediawikiPassword(),
					  $self->destinationMediawikiHost(),
					  $self->destinationMediawikiPath(),
					  $self->destinationHttpUsername(),
					  $self->destinationHttpPassword(),
					  $self->destinationHttpRealm());

    my $commonSite;
    if ($self->commonMediawikiHost()) {
	$commonSite= $self->connectToMediawiki($self->commonMediawikiUsername(),
					       $self->commonMediawikiPassword(),
					       $self->commonMediawikiHost(),
					       $self->commonMediawikiPath(),
					       ,
					       ,);
    }
	
    while ($self->isRunnable() && $site) {
	$timeOffset = time();
	my ($image, $content, $summary) = $self->getImageToUpload();

	if ($image) {
	    $self->incrementCurrentTaskCount();

	    my $status;
	    if ($self->uploadFilesFromUrl()) {
		if ($self->isCommonUrl($content)) {
		    $status = $commonSite->uploadImageFromUrl($image, $content, $summary);
		} else {
		    $status = $site->uploadImageFromUrl($image, $content, $summary);
		}

	    } else {
		$status = $site->uploadImage($image, $content, $summary);
	    }

	    if ($status) {
		$self->log("info", "Image ".($self->uploadFilesFromUrl() ? "URL": "")." '$image' successfuly uploaded in ".(time() - $timeOffset)."s.");
	    } else {
		$self->addImageError($image);
		$self->log("error", "Unable to write the image ".($self->uploadFilesFromUrl() ? "URL": "")." '$image'.");
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

    if ($image) {
	lock($imageUploadMutex);
	push(@imageUploadQueue, $image, $content, $summary) ;
    }
}

sub getImageToUpload {
    my $self = shift;

    lock($imageUploadMutex);

    if ($self->getImageUploadQueueSize()) {
	my $summary = pop(@imageUploadQueue) || "";
	my $content = pop(@imageUploadQueue) || "";
	my $image = pop(@imageUploadQueue) || "";
	return ($image, $content, $summary);
    }
}

sub getImageUploadQueueSize {
    my$self = shift;

    lock($imageUploadMutex);
    return (scalar(@imageUploadQueue) / 3);
}

sub checkCompletedImages {
    my $self = shift;

    lock($checkCompletedImages);
    if (@_) { $checkCompletedImages = shift };
    return $checkCompletedImages;
}

sub checkEmbeddedIn {
    my $self = shift;

    lock($checkEmbeddedIn);
    if (@_) { $checkEmbeddedIn = shift };
    return $checkEmbeddedIn;
}

sub uploadFilesFromUrl {
    my $self = shift;
    lock($uploadFilesFromUrl);
    return $uploadFilesFromUrl;
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
	    my @deps = $site->templateDependences($title);
	    my $toMirrorCount = 0;
	    
	    foreach my $dep (@deps) {
		if (exists($dep->{"missing"}) || $self->checkCompletedPages()) {
		    $toMirrorCount++;
		    my $template = $dep->{"title"};
		    $template =~ tr/ /_/;

		    # case of under page
		    if ($template =~ /(^[^\:]+\:)(\/.*$)/ ) {
			$template = $title.$2;
		    }

		    unless ($self->existsPageError($template)) {
			$self->addPageToDownload($template);
		    }
		}
	    }

	    $self->log("info", "$toMirrorCount/".scalar(@deps)." template dependence(s) todo for '$title'");

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

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    return $page;
}

sub checkTemplateDependences {
    my $self = shift;
    lock($checkTemplateDependences);
    if (scalar(@_)) { $checkTemplateDependences = shift }
    return $checkTemplateDependences;
}

sub getTemplateDependenceQueueSize {
    my $self = shift;
    lock($templateDependenceMutex);
    return scalar(keys(%templateDependenceQueue));
}

# check redirects
sub checkRedirects {
    my $self = shift;
    my $sourceSite = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					       $self->sourceMediawikiPassword(), 
					       $self->sourceMediawikiHost(),
					       $self->sourceMediawikiPath(),
					       $self->sourceHttpUsername(),
					       $self->sourceHttpPassword(),
					       $self->sourceHttpRealm());
    my $destinationSite = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					       $self->destinationMediawikiPassword(), 
					       $self->destinationMediawikiHost(),
					       $self->destinationMediawikiPath(),
					       $self->destinationHttpUsername(),
					       $self->destinationHttpPassword(),
					       $self->destinationHttpRealm());
    
    while ($self->isRunnable() && $sourceSite && $destinationSite) {
	my $title = $self->getPageToCheckRedirects();

	if ($title) {
	    $self->incrementCurrentTaskCount();
	    
	    my @redirects = $sourceSite->redirects($title);
	    my $toMirrorCount = 0;
	    my $count = 0;

	    # check if the pages already exists
	    my %redirects = $destinationSite->exists(@redirects);

	    foreach my $redirect (@redirects) {
		$count++;
		# nothing to do, the page already exists
		next if ($redirects{$redirect});

		$toMirrorCount++;
		$self->addPageToUpload($redirect, "#REDIRECT[[$title]]", "redirect to $title", 1);
	    }
	    $self->log("info", "$toMirrorCount/$count redirects found for '$title'");

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

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    return $page;
}

sub getRedirectQueueSize {
    my $self = shift;
    lock($redirectMutex);
    return scalar(keys(%redirectQueue));
}

sub checkIncomingRedirects {
    my $self = shift;
    lock($checkIncomingRedirects);
    if (@_) { $checkIncomingRedirects = shift; }
    return $checkIncomingRedirects;
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

    my $commonSite;
    if ($self->commonMediawikiHost()) {
	$commonSite= $self->connectToMediawiki($self->commonMediawikiUsername(),
					       $self->commonMediawikiPassword(),
					       $self->commonMediawikiHost(),
					       $self->commonMediawikiPath(),
					       ,
					       ,
	    );
    }

    my $imageNamespace = "file";
    if ($site) {
	my %namespaces = $site->namespaces();
	$imageNamespace = $namespaces{6};
    }
    
    while ($self->isRunnable() && $site) {
	my $title = $self->getPageToCheckImageDependence();

	if ($title) {
	    $self->incrementCurrentTaskCount();

	    my @deps = $site->imageDependences($title);
	    my $toMirrorCount = 0;

	    foreach my $dep (@deps) {
		if (exists($dep->{"missing"}) || $self->checkCompletedImages()) {
		    my $image = $dep->{"title"};
		    $image =~ s/$imageNamespace://i;

		    # Check if necessary if the image is not on the common Mediawiki instance
		    if ($commonSite) {
			my $commonSize = $commonSite->getImageSize($image);
			if ($commonSize) {
			    unless ($commonSize eq $site->getImageSize($image)) {
				$toMirrorCount++;
				$self->addImageToDownload($image);
			    }
			    next;
			}
		    } 

		    # Seems not to be a common image
		    unless ($self->existsImageError($image)) {
			$toMirrorCount++;
			$self->addImageToDownload($image);
		    }
		}
	    }
	    $self->log("info", "$toMirrorCount/".scalar(@deps)." image dependence(s) todo for '$title'");

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

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    return $page;
}

sub checkImageDependences {
    my $self = shift;
    lock($checkImageDependences);
    if (scalar(@_)) { $checkImageDependences = shift }
    return $checkImageDependences;
}

sub getImageDependenceQueueSize {
    my $self = shift;
    lock($imageDependenceMutex);
    return scalar(keys(%imageDependenceQueue));
}

# download pages
sub downloadPages {
    my $self = shift;
    my $title;
    my $revision;
    my $page;
    my $id;
    my $summary;
    my $history;
    my $content;
    my $timeOffset;
    my $site = $self->connectToMediawiki($self->sourceMediawikiUsername(),
					 $self->sourceMediawikiPassword(),
					 $self->sourceMediawikiHost(),
					 $self->sourceMediawikiPath(),
					 $self->sourceHttpUsername(),
					 $self->sourceHttpPassword(),
					 $self->sourceHttpRealm());

    my $revisionCallback = $self->revisionCallback();

    while ($self->isRunnable() && $site) {
	$id = "";
	$timeOffset = time();
	($title, $revision) = $self->getPageToDownload();
	
	if ($title) {
	    $self->incrementCurrentTaskCount();

	    ($content, $revision) = $site->downloadPage($title, $revision);
	    $summary = defined($revision) ? $revision : "head";

	    if ($content) {
		$self->addPageToUpload($title, $content, $summary, 0);
		$self->log("info", "Page '$title' ".((defined($revision) && !($revision eq "")) ? "rev. $revision " : "") ."successfuly downloaded in ".(time() - $timeOffset)."s.");
	    } else {
		$self->log("info", "The page '$title' ".((defined($revision) && !($revision eq "")) ? "rev. $revision " : "") ."does not exist.");
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
    my ($page, $revisionId) = split(/ /, shift);

    unless (defined($revisionId)) {
	$revisionId = "";
    }

    if ($page) {
	$page = lcfirst($page);
	$page =~ tr/ /_/;

	lock($pageDownloadMutex);
	unless ( exists($pageDownloadQueue{$page})) {
	    $pageDownloadQueue{$page} = $revisionId;
	}
    } else {
	$self->log("error", "empty page title given to addPageToDownload()");
    }
}

sub getPageToDownload {
    my $self = shift;
    my $page;
    my $revision;

    if ($self->getPageDownloadQueueSize()) {

	lock($pageDownloadMutex);
	($page) = keys(%pageDownloadQueue);
	$revision = $pageDownloadQueue{$page};

	delete($pageDownloadQueue{$page});
    }

    unless (Encode::is_utf8($page)) {
	$page = decode_utf8($page);
    }

    return ($page, $revision);
}

sub getPageDownloadQueueSize {
    my $self = shift;
    lock($pageDownloadMutex);
    return scalar(keys(%pageDownloadQueue));
}

sub addPageError {
    my $self = shift;
    my $page = shift;

    lock($pageErrorMutex);
    $pageErrorQueue{$page} = 1;
}

sub existsPageError {
    my $self = shift;
    my $page = shift;
    
    lock($pageErrorMutex);
    return exists($pageErrorQueue{$page});
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
    my $timeOffset;
    my $redirectTarget;
    my $status;
    my $site = $self->connectToMediawiki($self->destinationMediawikiUsername(),
					 $self->destinationMediawikiPassword(),
					 $self->destinationMediawikiHost(),
					 $self->destinationMediawikiPath(),
					 $self->destinationHttpUsername(),
					 $self->destinationHttpPassword(),
					 $self->destinationHttpRealm());

    my $footer;
    my $date;

    if ($self->footerPath()) {
	open(my $fh, '<:utf8', $self->footerPath());
	$footer = HTML::Template->new(filehandle => $fh);
	$date = strftime("%d-%m-%Y", localtime);
    }

    my $templateNamespace = "template";
    if ($site) {
	my %namespaces = $site->namespaces();
        $templateNamespace = $namespaces{10};
    }

    while ($self->isRunnable() && $site) {
	$timeOffset = time();
	my ($title, $content, $summary, $ignoreRedirect) = $self->getPageToUpload();

	if ($title) {
	    $self->incrementCurrentTaskCount();
	    
	    # is the page a redirection page?
	    $redirectTarget = $site->isRedirectContent($content);

	    # append the footer if not a redirect
	    if ($footer && !$redirectTarget && !$self->isTemplate($title, $templateNamespace)) {
		$footer->param(TITLE => uri_escape_utf8($title));
		$footer->param(REVISION => $summary);
		$footer->param(DATE => $date);
		$content = $content."<noinclude>".$footer->output()."</noinclude>";
	    }
	    
	    # upload the page
	    #	   $status = $site->uploadPage($title, $content, $summary, $redirectTarget );
	    $status = $site->uploadPage($title, $content, $summary );

	    # display the correct log message, depending of $status and $redirectTarget
	    if ($status eq "1") {
		$self->log("info", "Page '$title' successfuly uploaded in ".(time() - $timeOffset)."s.");
	    } elsif ($status eq "2") {
		$self->log("info", "Page '$title' already up to date. Uploaded in ".(time() - $timeOffset)."s.");
	    } elsif (!$redirectTarget) {
		$self->addPageError($title);
		$self->log("error", "Unable to write the page '$title'.");
	    }

	    if ($status) {
		if ($redirectTarget) {
		    if ($self->followRedirects() && !$ignoreRedirect && $status eq "1") {
			if ($redirectTarget =~ /\Q$title\E/i) {
			    $self->log("info", "Page '$title' is a redirect to '$title' : will be ignored.");			    
			} else {
			    $self->log("info", "Page '$title' is a redirect to '$redirectTarget'.");
			    $self->addPageToDownload($redirectTarget, 1);
			}
		    }
		} else {
		    if ($self->checkTemplateDependences()) {
			$self->addPageToCheckTemplateDependence($title);
		    }
		    
		    if ($self->checkImageDependences()) {
			$self->addPageToCheckImageDependence($title);
		    }

		    if ($self->checkEmbeddedIn() && $self->isTemplate($title, $templateNamespace) && $status eq "1") {
			$self->addPageToCheckEmbeddedInPages($title);
		    }

		    if ($self->checkIncomingRedirects()) {
			$self->addPageToCheckRedirects($title);
		    }
		}
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
    my $ignoreRedirect = shift || "";

    if ($self->noTextMirroring()) {
	return;
    }

    if ($title) { 
	lock($pageUploadMutex);
	push(@pageUploadQueue, $title, $content, $summary, $ignoreRedirect);
    }
}

sub getPageToUpload {
    my $self = shift;

    lock($pageUploadMutex);
    if (scalar(@pageUploadQueue)>=3) {
	my $ignoreRedirect = pop(@pageUploadQueue) || "";
	my $summary = pop(@pageUploadQueue) || "";
	my $content = pop(@pageUploadQueue) || "";
	my $title = pop(@pageUploadQueue) || "";
	return ($title, $content, $summary, $ignoreRedirect);
    }
}

sub getPageUploadQueueSize {
    my $self = shift;
    lock($pageUploadMutex);
    return (scalar(@pageUploadQueue) / 4);
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
    $site->logger($self->logger);

    $site->user($user);
    $site->password($pass);
    $site->hostname($host);
    $site->path($path);
    $site->httpUser($httpUser);
    $site->httpPassword($httpPass);
    $site->httpRealm($httpRealm);

    $site->setup();

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


sub commonMediawikiHost { 
    my $self = shift; 
    lock($commonMediawikiHost);
    if (@_) { $commonMediawikiHost = shift }
    return $commonMediawikiHost;
}

sub commonMediawikiPath { 
    my $self = shift; 
    lock($commonMediawikiPath);
    if (@_) { $commonMediawikiPath = shift }
    return $commonMediawikiPath;
}

sub commonMediawikiUsername {
    my $self = shift;
    lock($commonMediawikiUsername);
    if (@_) { $commonMediawikiUsername = shift }
    return $commonMediawikiUsername;
}

sub commonMediawikiPassword {
    my $self = shift;
    lock($commonMediawikiPassword);
    if (@_) { $commonMediawikiPassword = shift }
    return $commonMediawikiPassword;
}

sub commonRegexp {
    my $self = shift;
    lock($commonRegexp);
    if (@_) { $commonRegexp = shift }
    return $commonRegexp;
}

sub isCommonUrl {
    my $self = shift;
    my $url = shift;
    lock($commonRegexp);
    return (($commonRegexp && $url =~ /$commonRegexp/) ? 1 : 0);
}

sub isTemplate {
    my $self = shift;
    my $title = shift;
    my $templateNamespace = shift;

    if ($title) {
	if ($title =~ /^$templateNamespace\:.*/i ) {
	    return 1;
	}
    }

    return 0;
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

sub embeddedInDelay {
    my $self = shift;
    lock($embeddedInDelay);
    if (@_) { $embeddedInDelay = shift }
    return $embeddedInDelay;
}

sub noTextMirroring {
    my $self = shift;
    lock($noTextMirroring);
    if (@_) { $noTextMirroring = shift }
    return $noTextMirroring;
}

sub addPagesToMirror {
    my $self = shift;

    foreach my $page (@_) { 
	while ($self->getPageDownloadQueueSize() > 2 || 
	       $self->getImageDownloadQueueSize() > 2 ||
	       $self->getTemplateDependenceQueueSize() > 2 ||
	       $self->getImageDependenceQueueSize() > 2 ||
	       $self->getPageUploadQueueSize() > 2 ||
	       $self->getImageUploadQueueSize() > 2
	    ) {
	    sleep($self->delay());
	}

	if (my $fileName = $self->extractFileNameFromPageName($page)) {
	    $self->addImageToDownload($fileName);
	} elsif (!$self->checkCompletedPages()) {
	    $self->addPageToDownload($page);
	}
    }
}

sub extractFileNameFromPageName {
   my $self = shift;
   my $page = shift;

   if ($page =~ /(file\:)(.*)/i ) {
       return $2;
   }
}

# Footer stuff
sub footerPath {
    my $self = shift;
    lock($footerPath);
    if (@_) { $footerPath = shift; }
    return $footerPath;
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

# logging
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
	foreach my $key (keys(%$queue)) {
	    $string .= $key."\n";
	}
	$string .= "\n";
	return $string;
    }

    lock($pageDownloadMutex);
    $statusString .= "[pageDownloadQueue]\n";
    $statusString .= queueHashToString(\%pageDownloadQueue, 1);

    lock($pageUploadMutex);
    $statusString .= "[pageUploadQueue]\n";
    $statusString .= queueListToString(\@pageUploadQueue, 3);

    lock($imageDownloadMutex);
    $statusString .= "[imageDownloadQueue]\n";
    $statusString .= queueHashToString(\%imageDownloadQueue, 1);

    lock($imageUploadMutex);
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

    lock($pageErrorMutex);
    $statusString .= "[pageErrorQueue]\n";
    $statusString .= queueHashToString(\%pageErrorQueue, 1);

    lock($imageErrorMutex);
    $statusString .= "[imageErrorQueue]\n";
    $statusString .= queueHashToString(\%imageErrorQueue, 1);

    $statusString .= "[currentTaskCount]\n";
    $statusString .= $self->currentTaskCount()."\n";

    return $statusString;
}

1;
