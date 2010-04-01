package MediaWiki;

use utf8;
use strict;
use warnings;
use XML::Simple;
use Data::Dumper;
use LWP::UserAgent;
use URI;
use URI::Escape;
use Encode;
use Getargs::Long;

use threads;
use threads::shared;

my $logger;
my $loggerMutex : shared = 1;

our %filePathCache : shared;
our %redirectRegexCache : shared;
our %writeApiCache : shared;

my $lastRequestTimestamp = 0;

sub new {
    my $class = shift;
    my $self = {
	editToken => undef,
	hostname => "127.0.0.1",
	indexUrl => undef,
	apiUrl => undef,
	path => "",
	user => undef,
	password => undef,
	userAgent => undef,
	protocol => "http",
	httpUser => undef,
	httpPassword => undef,
	httpRealm => undef,
	namespaces => undef,
	useImageUploadToken => 1
    };

    bless($self, $class);

    # create third parth tools
    $self->userAgent(LWP::UserAgent->new());
    $self->userAgent()->cookie_jar( {} );

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
	if ($self->apiUrl()) {
	    # make the login http request
	    my $httpResponse = $self->makeApiRequest(
		{
		    'lgname' => $self->user(),
		    'lgpassword' => $self->password(),
		    'action' => 'login',
		    'format'=> 'xml',
		},
		"POST"
		);

	    if ($httpResponse->content() =~ /wronpass/i ) {
		$self->log("info", "Failed to logged in '".$self->hostname()."' as '".$self->user()."' : wrong pass.");
		$ok = 0;
	    } elsif ($httpResponse->content() =~ /NotExists/i ) {
		$self->log("info", "Failed to logged in '".$self->hostname()."' as '".$self->user()."' : wrong login.");
		$ok = 0;
	    } else {
		$self->log("info", "Successfuly logged to '".$self->hostname()."' as '".$self->user()."'.");
		$ok = 1;
	    }
	} else {
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
	    if($httpResponse->code == 302 || $httpResponse->header("Set-Cookie")) {
		$self->log("info", "Successfuly logged to '".$self->hostname()."' as '".$self->user()."'.");
		$ok = 1;
	    } else {
		$self->log("info", "Failed to logged in '".$self->hostname()."' as '".$self->user()."'.");
		$ok = 0;
	    }
	}
    }

    # edit token
    $self->loadEditToken();
    
    return $ok;
}

sub deletePage {
    my ($self, $page) = @_;

    my $httpResponse = $self->makeApiRequest(
	{
	    "action" => "delete",
	    "title" => $page,
	    "token" => $self->editToken(),
	    "format"=> "xml",
	    "reason"=>"42",
	},
	"POST"
	);

    if ( $httpResponse->content() =~ /\<error\ /) {
	return 0;
    }

    return 1;
}

sub restorePage {
    my ($self, $page) = @_;

    my $httpResponse = $self->makeApiRequest(
	{
	    "action" => "undelete",
	    "title" => $page,
	    "token" => $self->editToken(),
	    "format"=> "xml",
	    "reason"=> "42"
	},
	"POST"
	);

    if ( $httpResponse->content() =~ /\<error\ /) {
	return 0;
    }
    
    return 1;
}

sub getRedirectionRegex {
    my $self = shift;

    lock(%redirectRegexCache);
    unless (exists($redirectRegexCache{$self->hostname()})) {
	my $xml = $self->makeApiRequestAndParseResponse(
	    values=>{ meta => "siteinfo", siprop => "magicwords", action => "query", format => "xml"}, 
	    method=>"GET",
	    forceArray => "alias"
	    );

	my @names;
	if (ref($xml->{query}->{magicwords}->{magicword}->{redirect}->{aliases}->{alias}) eq "ARRAY") {
	    @names = @{$xml->{query}->{magicwords}->{magicword}->{redirect}->{aliases}->{alias}};
	}
	else {
	    @names = ("REDIRECT");
	}

	$redirectRegexCache{$self->hostname()} = "(".join("|", @names).")[ ]*\[\[[ ]*(.*)[ ]*\]\]";
    }

    return $redirectRegexCache{$self->hostname()};
}

sub hasFilePath {
    my ($self) = @_;
    
    lock(%filePathCache);
    unless (exists($filePathCache{$self->hostname()})) {
	my $httpResponse = $self->makeHttpGetRequest($self->indexUrl()."title=Special:Version");

	if ($httpResponse->content() =~ /filepath/i ) {
	    $self->log("info", "Site ".$self->hostname()." has the FilePath extension\n");
	    $filePathCache{$self->hostname()} = 1;
	} else {
	    $self->log("info", "Site ".$self->hostname()." does not have the FilePath extension\n");
	    $filePathCache{$self->hostname()} = 0;
	}
    }
    
    return $filePathCache{$self->hostname()};
}

sub hasWriteApi {
    my ($self) = @_;

    lock(%writeApiCache);
    unless (exists($writeApiCache{$self->hostname()})) {
	my $httpResponse = $self->makeApiRequest( { 'action' => 'edit', 'format' => 'xml' }, "POST" );

	if ($httpResponse->content() =~ /notitle/i ) {
	    $self->log("info", "Site ".$self->hostname()." has the Write API available.\n");
	    $writeApiCache{$self->hostname()} = 1;
	} else {
	    $self->log("info", "Site ".$self->hostname()." does not have the Write API available.\n");
	    $writeApiCache{$self->hostname()} = 0;
	}
    }

    return $writeApiCache{$self->hostname()};
}

sub protocol {
    my $self = shift;

    if (@_) { 
	$self->{protocol} = shift;
	$self->computeUrls();
    }
    return $self->{protocol};
}

sub httpPassword {
    my $self = shift;
    if (@_) { $self->{httpPassword} = shift; }
    return $self->{httpPassword};
}

sub httpUser {
    my $self = shift;
    if (@_) { $self->{httpUser} = shift; }
    return $self->{httpUser};
}

sub httpRealm {
    my $self = shift;
    if (@_) { $self->{httpRealm} = shift; }
    return $self->{httpRealm};
}

sub indexUrl {
    my $self = shift;
    if (@_) { $self->{indexUrl} = shift; }
    return $self->{indexUrl};
}

sub userAgent {
    my $self = shift;
    if (@_) { $self->{userAgent} = shift; }
    return $self->{userAgent};
}

sub apiUrl {
    my $self = shift;
    if (@_) { $self->{apiUrl} = shift; }
    return $self->{apiUrl};
}

sub editToken {
    my $self = shift;
    if (@_) { $self->{editToken} = shift; }
    return $self->{editToken};
}

sub hostname {
    my $self = shift;
    if (@_) { 
	$self->{hostname} = shift; 
	$self->computeUrls();
    }
    return $self->{hostname};
}

sub path {
    my $self = shift;
    if (@_) { 
	$self->{path} = shift; 
	$self->computeUrls();
    }
    return $self->{path};
}

sub user {
    my $self = shift;
    if (@_) { $self->{user} = shift; }
    return $self->{user};
}

sub password {
    my $self = shift;
    if (@_) { $self->{password} = shift; }
    return $self->{password};
}

sub useImageUploadToken {
    my $self = shift;
    if (@_) { $self->{useImageUploadToken} = shift; }
    return $self->{useImageUploadToken};
}

sub downloadPage {
    my ($self, $page, $revision) = @_;
    my $xml;
    my $httpPostRequestParams = {
	'action' => 'query',
	'prop' => 'revisions',
	'format' => 'xml',
	'rvprop' => 'content|ids',
    };
 
    # add revisionid if necessary
    if (defined($revision) && !($revision eq "")) {
	$httpPostRequestParams->{'revids'} = $revision;
    } else {
	$httpPostRequestParams->{'titles'} = $page;
    }

    # make the http request and parse response
    $xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams);

    if (ref($xml->{query}->{pages}->{page}) eq "ARRAY" || exists($xml->{query}->{pages}->{page}->{missing})) {
	return;
    } else {
	my $content = $xml->{query}->{pages}->{page}->{revisions}->{rev}->{content};
	$revision = $xml->{query}->{pages}->{page}->{revisions}->{rev}->{revid};

	unless (Encode::is_utf8($content)) {
	    $content = decode_utf8($content);
	}	

	return (ref($content) eq "HASH" ? "" : $content, $revision);
    }
    
    return "";
}

sub touchPage {
    my ($self, $page) = @_;
    my ($content, $revision) = $self->downloadPage($page);
    if ($content) {
	$self->uploadPage($page, $content, $revision);
    }
}

sub uploadPage {
    my ($self, $title, $content, $summary, $createOnly) = @_;
    my $returnValue = 0;

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
	
	my $retryCounter = 0;
	do {
	    my $httpResponse = $self->makeApiRequest($postValues, "POST");

	    if ($httpResponse->content() =~ /success/i || $httpResponse->content() =~ /articleexists/i ) {
		if ($httpResponse->content() =~ /nochange=\"\"/i) {
		    $returnValue = 2;
		} else {
		    $returnValue = 1;
		}
	    } elsif ($httpResponse->content() =~ /badtoken/i) {
		$self->loadEditToken();
		$postValues->{'token'} = $self->editToken();
		$self->log("info", "Reloading edit token...");
		$returnValue = 0;
	    } elsif ($httpResponse->content() =~ /invalidtitle/i) {
		$self->log("info", "Invalid title '$title', this page '$title' can simply not be uploaded.");
		$returnValue = 0;
		last;
	    }

	    if (!$returnValue && $retryCounter <= 15) {
		$self->log("info", "Was unable to upload correctly page '$title' (".$httpResponse->content()."), will retry in ".($retryCounter++)." s.");
		sleep($retryCounter);
	    }

	} while (!$returnValue && $retryCounter <= 15);

	if ($retryCounter > 15) {
	    $self->log("info", "Was unable to upload correctly page '$title'... I abandon now after 15 retries.");
	}
	
    } else {
	$self->log("error", "Unable to write page '".$title."' on '".$self->hostname()."'. It works only with write api.");
	$returnValue = 0;
    }
    
    return $returnValue;
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
	$httpResponse = eval { $self->makeHttpRequest("POST", $url, $httpHeaders || {}, $formValues || {}); };

	if ($@) {
	    $continue += 1;
	    $self->log("info", "Unable to make makeHttpPostRequest (".$@."), will try again in $continue second(s).");
	    sleep($continue);
	} else {
	    $continue = 0;
	}

    } while ($continue);

    return $httpResponse;
}

sub makeHttpGetRequest {
    my ($self, $url, $httpHeaders, $values) = @_;
    
    if ($values) {
	my $urlObj = URI->new($url);
	$urlObj->query_form($values);
	return $self->makeHttpGetRequest($urlObj, $httpHeaders);
    }

    return $self->makeHttpRequest("GET", $url, $httpHeaders || {});
}

sub makeIndexRequest {
    my $self = shift;
    return $self->makeSiteRequest($self->indexUrl(), @_);
}

sub makeApiRequest {
    my $self = shift;
    return $self->makeSiteRequest($self->apiUrl(), @_);
}

sub makeSiteRequest {
    my ($self, $url, $values, $method) = @_;
    my $httpResponse;
    my $httpHeaders = { "Accept-Charset" => "utf-8"};
    my $count=0;
    my $loop=0;

    unless (defined($method)) {
	$method = "GET";
    }

    do {
	if ($method eq "POST") {
	    $httpResponse = $self->makeHttpPostRequest($self->apiUrl(), $values, $httpHeaders);
	} elsif ($method eq "GET") {
	    my $urlObj = URI->new($url);
	    $urlObj->query_form($values);
	    $httpResponse = $self->makeHttpGetRequest($urlObj, $httpHeaders);
	} else {
	    die ("Method has to be GET or POST.");
	}

	if ($httpResponse->code() != 200) {
	    $count++;
	    $self->log("info", "Unable to make the following API request, HTTP error code was '".$httpResponse->code()."', ($count time) on '".$url."'. Response content is ".$httpResponse->content().":\n");
	    sleep($count);
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
    
    my $hash = eval { XMLin( @params) } ;
    
    if ($@ || !$hash) {
	$self->log("info", "Unable to parse the following XML:\n".Dumper($xml));
	$hash = undef;
    }

    unless (ref($hash) eq "HASH") {
	$self->log("info", "XMLin result is not a HASH");
	$hash = undef;
    }

    return $hash;
}

sub makeApiRequestAndParseResponse {
    my $self = shift;
    my ($values, $forceArray, $method) = 
	xgetargs(@_, "values"=>"HASH", "forceArray"=>['s', undef], "method"=>['s', undef])  ;
    my $xml;
    my $httpResponse;

    do {
	$httpResponse = $self->makeApiRequest($values, $method);
	$xml = $self->makeHashFromXml($httpResponse->content(), $forceArray );
	
	unless ($xml) {
	    $self->log("info", "Unable to makeAndParse API request, will retry...");
	    sleep(1);
	}

    } while (!$xml);

    return $xml;
}

sub getImageUrl {
    my ($self, $image) = @_;
    my $url;
    my $title = 'Special:FilePath';
    my $continue = 0;

    do {
	$self->userAgent()->requests_redirectable([]);
	$url = $self->makeHttpGetRequest($self->indexUrl(), {}, {  'title' => $title, 'file' => $image } )->header('location') ;
	$self->userAgent()->requests_redirectable(['HEAD', 'POST', 'GET']);

	if ( $url && $url =~ /\?/ && $url =~ /title\=(.*)\&/ ) {
	    $title = uri_unescape($1);
	    unless (Encode::is_utf8($title)) {
		$title = decode_utf8($title);
	    }
	    $continue = 1;
	} else {
	    $continue = 0;
	}
    } while ( $continue );

    return $url;
}

sub getImageSize {
    my($self, $image) = @_;
    my $size;
    my $imageNamespaceName = $self->getFileNamespaceName();

    unless ($image =~ /^file:/i || $image =~ /^$imageNamespaceName:/i ) {
	$image = "file:".$image;
    }

    my $httpPostRequestParams = {
	'action' => 'query',
	'titles' => $image,
	'format' => 'xml',
	'iiprop' => 'size',
	'prop' => 'imageinfo'
    };
    
    my $xml;

    # make the http request and parse response
    $xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams);

    if (exists($xml->{query}->{pages}->{page}->{imageinfo}->{ii})) {
	$size = $xml->{query}->{pages}->{page}->{imageinfo}->{ii}->{size}
    }
    
    return $size;
}

sub downloadImage {
    my ($self, $image) = @_;
    return $self->makeHttpGetRequest($self->indexUrl(), {}, {  'title' => 'Special:FilePath', 'file' => $image } )->content();
}

sub uploadImageFromUrl {
    my($self, $title, $url, $summary) = @_;

    my $httpPostRequestParams = {
	    'title' => 'Special:Upload',
	    'wpSourceType' => "url",
	    'wpUploadFileURL' => $url,
	    'wpDestFile' => $title, 
	    'wpUploadDescription' => $summary ? $summary : "",
	    'wpUpload' => 'upload',
	    'wpIgnoreWarning' => '1',
    };

    # Get upload token
    # Not all Mediawikis have this edit token security
    if ($self->useImageUploadToken()) {
	my $httpResponseToken = $self->makeHttpGetRequest($self->indexUrl(), {}, {  'title' => 'Special:Upload' } );
	if ($httpResponseToken->content =~ /value\=\"([^\"]+)\"\ name\=\"wpEditToken\"/ ) {
	    $httpPostRequestParams->{'wpEditToken'} = $1;
	} else {
	    if ($httpResponseToken->code == 200) {
		$self->log("warn", "Unable to retrieve wpEditToken to upload image, will try to do without in the future.");
		$self->useImageUploadToken(0);
	    } else {
		$self->log("warn", "Unable to retrieve wpEditToken to upload image, will try to do without this time.");
	    }
	}
    }

    my $httpResponse = $self->makeHttpPostRequest(
	$self->indexUrl(),
	$httpPostRequestParams
	);

    my $status = $httpResponse->code == 302;

    return $status;
}

# Curently not use, seems to be buggy
# After hours it doe not work anymore
sub uploadImageFromUrl_withapi {
    my($self, $title, $url, $summary) = @_;
    my $status;

    my $httpPostRequestParams = {
	'action' => 'upload',
	'url' => $url,
	'filename' => $title,
	'token' => $self->editToken(),
	'format' => 'xml',
	'asyncdownload' => '1',
	'ignorewarnings' => '1',
    };
    
    my $httpResponse = $self->makeApiRequest($httpPostRequestParams, "POST" );
    my $content = $httpResponse->content;

    $self->log("info", "Upload $title : ".$httpResponse->content);

    if ($content =~ /error\ code\=\"([^\"]+)\"/) {
	$self->log("error", "Error by uploading image '$title' : $1");
    }
    elsif ($content =~ /upload_session_key\=\"([\d]+)\"/) {
	my $sessionKey = $1;
	$httpResponse = $self->makeApiRequest( { 'action' => 'upload', 'httpstatus' => '1', 'sessionkey' => "$sessionKey", 'format' => 'xml', 'token' => $self->editToken() } , 'POST');

	$self->log("info", "Status Upload $title : ".$httpResponse->content);

	$status = 1;
    } else {
	$self->log("error", "Error by uploading image '$title' : $content");
    }

    return $status;
}

sub uploadImage {
    my($self, $title, $content, $summary) = @_;

    my $httpPostRequestParams = {
	    'title' => 'Special:Upload',
	    'wpSourceType' => "file",
	    'wpUploadFile' => [ undef, $title, Content => $content ],
	    'wpDestFile' => $title,
	    'wpUploadDescription' => $summary ? $summary : "",
	    'wpUpload' => 'upload',
	    'wpIgnoreWarning' => 'true'
    };

    my $httpResponse = $self->makeHttpPostRequest(
	$self->indexUrl(),
	$httpPostRequestParams,
	{ Content_Type  => 'multipart/form-data' }
	);

    my $status = $httpResponse->code == 302;

    return $status;
}

sub DESTROY
{
}

sub loadEditToken {
    my $self = shift;
    
    my $httpResponse = $self->makeApiRequest( { 'action' => 'query', 'prop' => 'info', 'intoken' => 'edit', 'format' => 'xml', 'titles' => '42' } , 'GET');
    if ($httpResponse->content() =~ /edittoken=\"(.*)\"/ ) {
	$self->editToken($1);
	return 1;
    } else {
	$self->log("info", "Was unable to loadEditToken correctly : (".$httpResponse->content().").");
    }
    
    return 0;
}

sub getOutgoingLinks {
    my($self, $page) = @_;
    my $httpPostRequestParams = {
	'action' => 'query',
	'prop' => 'links',
        'titles' => $page,
        'format' => 'xml',
        'allimit' => '500',
    };
    my %links;
    my $continue;
    my $xml;

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'plcontinue'} = $continue;
	}

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'pl');
	if (exists($xml->{query}->{pages}->{page}->{links}->{pl})) {
	    foreach my $link (@{$xml->{query}->{pages}->{page}->{links}->{pl}}) {
		$links{$link->{title}} = 1 if ($link->{title});
	    }
	}
    } while ($continue = $xml->{"query-continue"}->{"links"}->{"plcontinue"});

    return(keys(%links));
}

sub getFailingDependences {
    my $self = shift;
    my $page = shift;
    
    my @dependences = ($self->imageDependences($page), $self->templateDependences($page));
    my @failingDependences;

    foreach my $dep (@dependences) {
        if (exists($dep->{"missing"})) {
	    $dep->{title} =~ tr/ /_/;
	    push(@failingDependences, $dep->{title});
        }
    }

    return @failingDependences;
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
	
	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'page');

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
    my ($self, $title, $namespace) = @_;
    my @links;
    my $continue;
    my $xml;
    my $httpPostRequestParams = {
	'action' => 'query',
	'eititle' => $title,
	'format' => 'xml',
	'eifilterredir' => 'nonredirects',
	'eilimit'=> '500',
	'list' => 'embeddedin',
    };

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'eicontinue'} = $continue;
	}

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'ei');

	foreach my $hash ( @{ $xml->{query}->{embeddedin}->{ei} } ) {

	    if (defined($namespace) && ($namespace eq $hash->{ns})) {
		my $title = $hash->{title};
		$title =~ tr/ /_/;

                unless (Encode::is_utf8($title)) {
                    $title = decode_utf8($title);
                }

		push( @links, $title );
	    }

	}

    } while ($continue = $xml->{"query-continue"}->{embeddedin}->{eicontinue});

    return @links;
}

sub allPages {
    my($self, $namespace, $filter, $prefix) = @_;

    unless ($filter) {
	$filter = 'nonredirects';
    }

    my $httpPostRequestParams = {
        'action' => 'query',
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

    # set filter if necessary
    if (defined($filter)) {
	$httpPostRequestParams->{'apfilterredir'} = $filter;
    }
    
    # set prefix if necessary
    if (defined($prefix)) {
	$httpPostRequestParams->{'apprefix'} = $prefix;
    }

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'apfrom'} = $continue;
	}
	
	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'p');

	if (exists($xml->{query}->{allpages}->{p})) {
	    foreach my $page (@{$xml->{query}->{allpages}->{p}}) {
		if ($page->{title}) {
		    my $title = $page->{title};
		    $title =~ tr/ /_/;
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
    
    my %namespaces = $self->namespaces();
    my $imageNamespace = $namespaces{6};

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'gaifrom'} = $continue;
	}

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'page');

	if (exists($xml->{query}->{pages}->{page})) {
	    foreach my $page (@{$xml->{query}->{pages}->{page}}) {
		if ($page->{title}) {
		    my $image = $page->{title};
		    $image =~ s/^$imageNamespace:// ;
		    $image =~ tr/\ /_/ ;
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

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'bl');
	
	if (exists($xml->{query}->{backlinks}->{bl})) {
	    foreach my $redirect (@{$xml->{query}->{backlinks}->{bl}}) {
		push(@redirects, $redirect->{title}) if ($redirect->{title});
	    }
	}
    } while ($continue = $xml->{"query-continue"}->{"backlinks"}->{"blcontinue"});

    return(@redirects);
}

sub exists {
    my $self = shift;
    my @pages = @_;
    my $httpPostRequestParams = {
	'action' => 'query',
	'prop' => 'info',
        'format' => 'xml'
    };
    my %pages;
    my $xml;
    my $step=50;

    do {
	$self->log("info", "Will check existense for $step pages (or less).");
	my $titles = "";
	for (my $i=0; $i<$step; $i++) {
	    last unless (scalar(@pages));
	    $titles .= shift(@pages);
	    $titles .= "|" unless ($i == $step-1 || !scalar(@pages));
	}

	$httpPostRequestParams->{titles} = $titles;

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'page', method=>"POST");

	if (exists($xml->{query}->{pages}->{page})) {
	    foreach my $page (@{$xml->{query}->{pages}->{page}}) {
		$pages{$page->{title}} = !(exists($page->{missing})) if ($page->{title});
	    }
	}
    } while (scalar(@pages));

    return(%pages);
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

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, method=>"GET", forceArray=>'rev');

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

sub listCategoryEntries {
    my($self, $category, $explorationDepth, $namespace) = @_;
    my @entries;
    my $continue;
    my $xml;
    my @categoryStack = ("Category:".$category, "|");
    my $currentDepth = 0;
    my %doneCategories;

    unless (defined($namespace)) { $namespace = ""};
    unless (defined($explorationDepth)) { $explorationDepth=1 };

    while ( $currentDepth < $explorationDepth && scalar(@categoryStack) ) {

	while ($category = shift(@categoryStack)) {

	    if ($category eq "|") {
		$self->log("info", "Still ".scalar(@categoryStack)." categories width depth > $currentDepth...");
		$currentDepth++;

		if (scalar(@categoryStack)) {
		    push(@categoryStack, "|");
		}
		
		last;
	    }
	    
	    if (exists($doneCategories{$category})) {
		$self->log("info", "'$category' already check for sub categories.");
		next;
	    }
	    
	    sleep(1);
	    
	    $self->log("info", "Reading '$category'...");
	    do {
		my $httpPostRequestParams = {
		    'action' => 'query',
		    'cmtitle' => $category,
		    'format' => 'xml',
		    'list' => 'categorymembers',
		    'cmlimit' => '500',
		    'cmnamespace' => join("|", "14", $namespace), 
		};
		
		# set the appropriate offset
		if ($continue) {
		    $httpPostRequestParams->{'cmcontinue'} = $continue;
		}
		
		# make the http request and parse response
		$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'cm');
		
		if (exists($xml->{query}->{categorymembers}->{cm})) {
		    foreach my $entry (@{$xml->{query}->{categorymembers}->{cm}}) {
			# Add a subcategory
			if ($entry->{ns} eq "14") {
			    push(@categoryStack, $entry->{title}) if ($entry->{title});
			}
			
			# Add a page 
			if (defined($namespace) && ($namespace eq $entry->{ns})) {
			    push(@entries, $entry->{title}) if ($entry->{title});
			}
		    }
		}
		
		$doneCategories{$category} = 1;
		
	    } while ($continue = $xml->{"query-continue"}->{"categorymembers"}->{"cmcontinue"});
	}
    }

    return(@entries);    
}

# namespaces
sub namespaces {
    my $self = shift;
    
    unless ($self->{namespaces}) {
	my $httpResponse = $self->makeHttpPostRequest(
	    $self->indexUrl()."title=Special:PrefixIndex"
	    );
	
	my $content = $httpResponse->content();
	
	my %hash;

	# Add the special page namespace
	if ($content =~ /var\ wgPageName\ \=\ "(.*):(.*)"/) {
	    my $name = $1;
	    $name =~ tr/\ /_/;
	    $name = ucfirst($name);
	    
	    unless (Encode::is_utf8($name)) {
		$name = decode_utf8($name);
	    }
	    
	    $hash{-1} = $name;
	}
	
	while ($content =~ /<option value="([\d]+)"[^>]*>(.*)<\/option>/mg ) {
	    my $code = $1;
	    my $name = $2;
	    $name =~ tr/\ /_/;
	    $name = ucfirst($name);
	    
	    unless (Encode::is_utf8($name)) {
		$name = decode_utf8($name);
	    }
	    
	    $hash{$code} = $name;
	}
	
	$self->{namespaces} = \%hash;
    }

    return %{$self->{namespaces}};
}

sub getNamespaceName() {
    my $self = shift;
    my $number = shift;

    my %namespaces = $self->namespaces();
    return $namespaces{$number};
}

sub getFileNamespaceName() {
    my $self = shift;
    return $self->getNamespaceName(6);
}

# Prepare a page: ask for the HTML code and check if no error
sub preparePage {
    my $self = shift;
    my $title = shift;
    my $ok = 1;

    do {
	$self->log("info", "Preparing page '$title'...");
	
	my $httpResponse = $self->makeHttpGetRequest(
	    $self->apiUrl()."?action=parse&text={{:$title}}"
	);
	my $content = $httpResponse->content();
	
	if ($content =~ /passthru/ && $content =~ /unable to fork/i) {
	    $ok = 0;
	} else {
	    $ok = 1;
	}
    } while (!$ok);
}

# mirroring stuff
sub isRedirectContent {
    my $self = shift;
    my $content = shift;

    my $regex = $self->getRedirectionRegex();

    if ( $content =~ /$regex/i ) {
	my $title = $2;
	$title =~ tr/ /_/;
	$title = lcfirst($title);
	return $title;
    }
    return "";
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
