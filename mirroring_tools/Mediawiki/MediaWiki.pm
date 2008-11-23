package MediaWiki;

use utf8;
use strict;
use XML::Simple;
use Data::Dumper;
use LWP::UserAgent;
use URI;

my $indexUrl;
my $apiUrl;
my $path;
my $hostname;
my $user;
my $password;
my $userAgent;
my $protocol;

my $httpUser;
my $httpPassword;
my $httpRealm;

my $logger;
my $loggerMutex : shared = 1;

my $hasFilePath;
my $hasWriteApi;
my $editToken;

my $lastRequestTimestamp = 0;

sub new
{
    my $class = shift;
    my $self = {};

    bless($self, $class);

    # create third parth tools
    $self->userAgent(LWP::UserAgent->new());
    $self->userAgent()->cookie_jar( {} );

    # set default protocol
    unless ($self->protocol()) {
	$self->protocol('http');
    }

    # set default hostname
    unless ($self->hostname()) {
	$self->hostname('127.0.0.1');
    }

    return $self;
}

sub computeUrls {
    my $self = shift;
    $self->indexUrl($self->protocol().'://'.$self->hostname().($self->path() ? '/'.$self->path() : '')."/index.php?");
    $self->apiUrl($self->protocol().'://'.$self->hostname().($self->path() ? '/'.$self->path() : '')."/api.php");
}

sub setup {
    my $self= shift;
    my $ok = 1;

    # set the http auth. info if necessary
    if($self->httpUser()) {
	$self->userAgent->credentials($self->hostname().':'.($self->protocol() eq 'https' ? "443" : "80"), 
				      $self->httpRealm(), $self->httpUser(), $self->httpPassword() );
    }

    if ($self->user()) {
	# make the login http request
	my $httpResponse = $self->makeHttpPostRequest(
	    $self->indexUrl()."title=Special:Userlogin&action=submitlogin",
	    {
		'wpName' => $self->user(),
		'wpPassword' => $self->password(),
		'wpLoginattempt' => 'Log in',
	    },
	    );
	
	# check the http response
	if($httpResponse->code == 302 || $httpResponse->header("Set-Cookie"))
	{
	    $self->log("info", "Successfuly logged to '".$self->hostname()."' as '".$self->user()."'.");
	    $ok = 1;
	} else {
	    $self->log("info", "Failed to logged in '".$self->hostname()."' as '".$self->user()."'.");
	    $ok = 0;
	}
    }

    # check filepath & api
    $self->hasFilePath(1);
    $self->hasWriteApi(1);

    # edit token
    $self->loadEditToken();
    
    return $ok;
}

sub deletePage {
    my ($self, $page) = @_;

    my $httpResponse = $self->makeHttpPostRequest(
	$self->apiUrl(),
	{
	    "action" => "delete",
	    "title" => $page,
	    "token" => $self->editToken(),
	    "format"=> "xml",
	},
	);

    if ( $httpResponse->content() =~ /\<error\ /) {
	return 0;
    }
    return 1;
}

sub hasFilePath {
    my ($self, $compute) = @_;

    if ($compute) {
	my $httpResponse = $self->makeHttpGetRequest($self->indexUrl()."title=Special:Version");

	if ($httpResponse->content() =~ /filepath/i ) {
	    $self->log("info", "Site ".$self->hostname()." has the FilePath extension\n");
	    $hasFilePath = 1;
	} else {
	    $self->log("info", "Site ".$self->hostname()." does not have the FilePath extension\n");
	    $hasFilePath = 0;
	}
    }
    
    return $hasFilePath;
}

sub hasWriteApi {
    my ($self, $compute) = @_;

    if ($compute) {
	my $httpResponse = $self->makeHttpPostRequest($self->apiUrl().'action=edit&format=xml');

	if ($httpResponse->content() =~ /notitle/i ) {
	    $self->log("info", "Site ".$self->hostname()." has the Write API available.\n");
	    $hasWriteApi = 1;
	} else {
	    $self->log("info", "Site ".$self->hostname()." does not have the Write API available.\n");
	    $hasWriteApi = 0;
	}
    }

    return $hasWriteApi;
}

sub protocol {
    my $self =  shift;

    if (@_) { 
	$protocol = shift;
	$self->computeUrls();
    }
    return $protocol;
}

sub httpPassword {
    my $self = shift;
    if (@_) { $httpPassword = shift; }
    return $httpPassword;
}

sub httpUser {
    my $self = shift;
    if (@_) { $httpUser = shift; }
    return $httpUser;
}

sub httpRealm {
    my $self = shift;
    if (@_) { $httpRealm = shift; }
    return $httpRealm;
}

sub indexUrl {
    my $self = shift;
    if (@_) { $indexUrl = shift; }
    return $indexUrl;
}

sub userAgent {
    my $self = shift;
    if (@_) { $userAgent = shift; }
    return $userAgent;
}

sub apiUrl {
    my $self = shift;
    if (@_) { $apiUrl = shift; }
    return $apiUrl;
}

sub editToken {
    my $self = shift;
    if (@_) { $editToken = shift; }
    return $editToken;
}

sub hostname {
    my $self = shift;
    if (@_) { 
	$hostname = shift; 
	$self->computeUrls();
    }
    return $hostname;
}

sub path {
    my $self = shift;
    if (@_) { 
	$path = shift; 
	$self->computeUrls();
    }
    return $path;
}

sub user {
    my $self = shift;
    if (@_) { $user = shift; }
    return $user;
}

sub password {
    my $self = shift;
    if (@_) { $password = shift; }
    return $password;
}

sub downloadPage {
    my ($self, $page) = @_;
    my $xml;
    my $httpPostRequestParams = {
	'action' => 'query',
	'prop' => 'revisions',
	'titles' => $page,
	'format' => 'xml',
	'rvprop' => 'content',
    };
 
    # make the http request                                                                                                                       
    my $httpResponse = $self->makeApiRequest($httpPostRequestParams);
    $xml = $self->makeHashFromXml($httpResponse->content());

    if (exists($xml->{query}->{pages}->{page}->{missing})) {
	return;
    } else {
	my $content = $xml->{query}->{pages}->{page}->{revisions}->{rev};
	return ref($content) eq "HASH" ? "" : $content;
    }
    
    return "";
}

sub touchPage {
    my ($self, $page) = @_;
    my $content = $self->downloadPage($page);
    $self->uploadPage($page, $content, "null-edit");
}

sub uploadPage {
    my ($self, $title, $content, $summary, $createOnly) = @_;

    if ($self->hasWriteApi()) {
	unless ($self->editToken()) {
	    unless ($self->loadEditToken()) {
		$self->log("info", "Unable to load edit token for ".$self->hostname());
	    }
	}
	
	my $postValues = {
	    'action' => 'edit',
	    'token' => $self->editToken(),
	    'text' => $content,
	    'summary' => $summary,
	    'title' => $title,
	    'format' => 'xml',
	};
	
	if ($createOnly) {
	    $postValues->{'createonly'} = '1';
	}
	
	my $httpResponse = $self->makeHttpPostRequest($self->apiUrl(), $postValues);

	if ($httpResponse->content =~ /success/i ) {
	    if ($httpResponse->content =~ /nochange=\"\"/i ) {
		return 2;
	    }
	    return 1;
	}
    } else {
	$self->log("error", "Unable to write page '".$title."' on '".$self->hostname()."'. It works only with write api.");
    }
    
    return 0;
}

sub makeHttpRequest {
    my ($self, $method, $url, $httpHeaders, $formValues) = @_;
    
    my $httpResponse;
    my $loopCount = 0;

    if ($method eq "POST") {
	$httpResponse= $self->userAgent()->post(
	    $url,
	    $formValues,
	    %$httpHeaders,
	    );
    } elsif ($method eq "GET") {
	$httpResponse= $self->userAgent()->get(
	    $url,
	    %$httpHeaders,
	    );
    } else {
	die("'$method' is not a valid method for makeHttpRequest().");
    }

    return $httpResponse;
}

sub makeHttpPostRequest {
    my ($self, $url, $formValues, $httpHeaders) = @_;
    my $httpResponse;
    my $continue;

    do {
	$httpResponse = eval { $self->makeHttpRequest("POST", $url, $httpHeaders || { Content_Type  => 'multipart/form-data' }, $formValues || {}); };

	if ($@) {
	    $continue += 1;
	    $self->log("info", "Unable to make makeHttpPostRequest, will try again in $continue second(s).");
	    sleep($continue);
	} else {
	    $continue = 0;
	}

    } while ($continue);

    return $httpResponse;
}

sub makeHttpGetRequest {
    my ($self, $url, $httpHeaders) = @_;
    
    return $self->makeHttpRequest("GET", $url, $httpHeaders || {});
}

sub makeApiRequest {
    my ($self, $values, $method) = @_;
    my $httpResponse;
    my $httpHeaders = { "Accept-Charset" => "utf-8" };
    my $count=0;
    my $loop=0;

    unless ($method) {
	$method = "GET";
    }

    do {
	if ($httpResponse) {
	    $count++;
	    $self->log("info", "Unable to make the following API request ($count time) on '".$self->apiUrl()."':\n".Dumper($values));
	    sleep($count);
	}

	if ($method eq "POST") {
	    $httpResponse = $self->makeHttpGetRequest($self->apiUrl(), $values);
	} elsif ($method eq "GET") {
	    my $url = URI->new($self->apiUrl());
	    $url->query_form($values);
	    $httpResponse = $self->makeHttpGetRequest($url, $httpHeaders);
	} else {
	    die ("Method has to be GET or POST.");
	}

	if ($httpResponse->code() != 200) {
	    $self->log("info", $httpResponse->content());
	    $loop = 1;
	} else {
	    $loop = 0;
	}

    } while($loop);

    return $httpResponse;
}

sub makeHashFromXml {
    my ($self, $xml, $forceArray) = @_;

    my @params;
    push(@params, $xml);

    if ($forceArray) {
	push(@params, ForceArray => [($forceArray)] );
    }
    
    my $hash = XMLin( @params);
    
    if ($@ || !$hash) {
	die("Unable to parse the following XML:\n".Dumper($xml));
    }

    return $hash;
}

sub downloadImage {
    my ($self, $image) = @_;

    return $self->makeHttpGetRequest($self->indexUrl()."title=Special:FilePath&file=".uri_escape($image))->content();
}

sub uploadImage {
    my($self, $title, $content, $summary) = @_;

    my $httpResponse = $self->makeHttpPostRequest(
	$self->indexUrl().'title=Special:Upload',
	{
	    'wpUploadFile' => [ undef, $title, Content => $content ],
	    'wpDestFile' => $title,
	    'wpUploadDescription' => $summary ? $summary : "",
	    'wpUpload' => 'upload',
	    'wpIgnoreWarning' => 'true'
	},
	);
    
    my $status = $httpResponse->code == 302;

    return $status;
}

sub DESTROY
{
}

sub loadEditToken {
    my $self = shift;
    
    my $httpResponse = $self->makeHttpGetRequest($self->apiUrl()."action=query&prop=info&intoken=edit&format=xml&titles=42");

    if ($httpResponse->content =~ /edittoken=\"(.*)\"/ ) {
	$self->editToken($1);
	return 1;
    }
    
    return 0;
}

sub isIncompletePage {
    my $self = shift;
    my $page = shift;
    my $incomplete = 0;
    
    # check image dependences
    my @deps = $self->imageDependences($page);
    
    foreach my $dep (@deps) {
	if (exists($dep->{"missing"})) {
	    $incomplete = 1;
	    last;
	}
    }
    
    # check template dependences (if necessary)
    unless ($incomplete) {
	my @deps = $self->templateDependences($page);
	foreach my $dep (@deps) {
	    if (exists($dep->{"missing"})) {
		$incomplete = 1;
		last;
	    }
	}
    }

    return $incomplete;
}

sub templateDependences {
    my $self = shift;
    return $self->dependences(@_, "templates");
}

sub imageDependences {
    my $self = shift;
    return $self->dependences(@_, "images");
}

sub dependences {
    my($self, $page, $type) = @_;
    my @deps;

    my $continueProperty = $type eq "templates" ? "gtlcontinue" : "gimcontinue";
    my $httpPostRequestParams = {
	'action' => 'query',
	'titles' => $page,
	'format' => 'xml',
	'prop' => 'info',
	'gtllimit'=> '500',
	'generator' => $type,
    };
    my $continue;
    my $xml;

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{$continueProperty} = $continue;
	}

	# make the http request                                                                                                                       
        my $httpResponse = $self->makeApiRequest($httpPostRequestParams);
	$xml = $self->makeHashFromXml($httpResponse->content(), 'page' );
	
	if (exists($xml->{query}->{pages}->{page})) {
	    foreach my $dep (@{$xml->{query}->{pages}->{page}}) {
		$dep->{title} = $dep->{title} ;
		push(@deps, $dep);
	    } 
	}
    } while ($continue = $xml->{"query-continue"}->{$type}->{$continueProperty});
    
    return(@deps);
}

sub embeddedIn {
    my ($self, $title) = @_;
    my @links;
    my $continue;
    my $xml;

    do {
	my $httpResponse = $self->makeHttpGetRequest($self->apiUrl()."action=query&format=xml&eifilterredir=nonredirects&list=embeddedin&eilimit=500&eititle=".uri_escape($title).($continue ? "&eicontinue=".$continue : "") );

	if(!$httpResponse->is_success()) {
	    $self->log("info", "Unable to get the embedded in for '".$title."' by '".$self->hostname()."'.");
	    last;
	}
	else
	{
	    $xml = XMLin( $httpResponse->content() , ForceArray => [('ei')] );

	    foreach my $hash ( @{ $xml->{query}->{embeddedin}->{ei} } ) {
		push( @links, $hash->{title} );
	    }
	} 
    } while ($continue = $xml->{"query-continue"}->{embeddedin}->{eicontinue});

    return @links;
}

sub allPages {
    my($self, $namespace) = @_;
    my $httpPostRequestParams = {
        'action' => 'query',
        'apfilterredir' => 'nonredirects',
        'list' => 'allpages',
        'format' => 'xml',
	'aplimit' => '500',
    };
    my @pages;
    my $continue;
    my $xml;

    # set the appropriate namespace
    if (defined($namespace)) {
	$httpPostRequestParams->{'apnamespace'} = $namespace;
    }
    
    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'apfrom'} = $continue;
	}

	# make the http request                                                                                                                       
        my $httpResponse = $self->makeApiRequest($httpPostRequestParams);
	$xml = $self->makeHashFromXml($httpResponse->content(), 'p' );
	
	if (exists($xml->{query}->{allpages}->{p})) {
	    foreach my $page (@{$xml->{query}->{allpages}->{p}}) {
		if ($page->{title}) {
		    my $title = $page->{title};
		    push(@pages, $title);
		}
            }
	}
    } while ($continue = $xml->{"query-continue"}->{"allpages"}->{"apfrom"});

    return(@pages);
}

sub allImages {
    my $self = shift;
    my $httpPostRequestParams = {
        'action' => 'query',
        'generator' => 'allimages',
        'list' => 'allpages',
        'format' => 'xml',
	'gailimit' => '500',
    };
    my @images;
    my $continue;
    my $xml;
    
    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'gaifrom'} = $continue;
	}

	# make the http request                                                                                                                       
        my $httpResponse = $self->makeApiRequest($httpPostRequestParams);
	$xml = $self->makeHashFromXml($httpResponse->content(), 'page' );	

	if (exists($xml->{query}->{pages}->{page})) {
	    foreach my $page (@{$xml->{query}->{pages}->{page}}) {
		if ($page->{title}) {
		    my $image = $page->{title};
		    $image =~ s/^Image:// ;
		    $image =~ s/\ /_/ ;
		    push(@images, $image);
		}
            }
	}
    } while ($continue = $xml->{"query-continue"}->{"allimages"}->{"gaifrom"});

    return(@images);
}

sub redirects {
    my($self, $page) = @_;
    my $httpPostRequestParams = {
	'action' => 'query',
	'list' => 'backlinks',
        'bltitle' => $page,
        'format' => 'xml',
	'blfilterredir' => 'redirects',
        'bllimit' => '500',
    };
    my @redirects;
    my $continue;
    my $xml;

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'blcontinue'} = $continue;
	}

	# make the http request                                                                                                                       
        my $httpResponse = $self->makeApiRequest($httpPostRequestParams);
	$xml = $self->makeHashFromXml($httpResponse->content(), 'bl' );	
	
	if (exists($xml->{query}->{backlinks}->{bl})) {
	    foreach my $redirect (@{$xml->{query}->{backlinks}->{bl}}) {
		push(@redirects, $redirect->{title}) if ($redirect->{title});
	    }
	}
    } while ($continue = $xml->{"query-continue"}->{"backlinks"}->{"blcontinue"});

    return(@redirects);
}

sub history {
    my($self, $page, $versionIdLimit, $throttle, $rvlimit) = @_;
    my $history;
    my $continue;
    my $xml;
    my $versionIdFound = 0;

    unless (defined($rvlimit)) {
	$rvlimit = 500;
    }

    unless (defined($throttle)) {
	$throttle = 1;
    }

    my $httpPostRequestParams = {
        'action' => 'query',
        'titles' => $page,
        'format' => 'xml',
	'prop' => 'revisions',
        'rvlimit' => $rvlimit,
	'rvprop' => 'ids|timestamp|flags|user|size', 
	'redirects'=> '42',
    };

    do {
	# throttling
	if (time() - $lastRequestTimestamp < $throttle) {
	    sleep($throttle);
	}
	$lastRequestTimestamp = time();

	# set the appropriate offset
	if ($continue) {
            $httpPostRequestParams->{'rvstartid'} = $continue;
        }
	
	# make the http request
	my $httpResponse = $self->makeApiRequest($httpPostRequestParams, "GET");
	$xml = $self->makeHashFromXml($httpResponse->content(), 'rev' );	

	# merge with the history (if necessary)
	if ($history) {
	    foreach my $rev (@{$xml->{query}->{pages}->{page}->{revisions}->{rev}}) {
		push(@{$history->{revisions}->{rev}}, $rev);
	    }
	} else {
	    $history = $xml->{query}->{pages}->{page};
	}
	
	# check if the versionIdLImit is not reach
	if ($versionIdLimit) {
	    foreach my $rev (@{$xml->{query}->{pages}->{page}->{revisions}->{rev}}) {
		if ($rev->{revid} eq $versionIdLimit) {
		    $versionIdFound = 1;
		    last;
		}
	    }
	}
    } while (!$versionIdFound && ($continue = $xml->{"query-continue"}->{"revisions"}->{"rvstartid"}));

    # remove revid older than $versionIdLimit
    if ($versionIdLimit && $versionIdFound) {
	my $rev;
	do {
	    $rev = pop(@{$history->{revisions}->{rev}});
	} while (scalar(@{$history->{revisions}->{rev}}) && !($rev->{revid} eq $versionIdLimit) );
    }

    return $history;
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

1;
