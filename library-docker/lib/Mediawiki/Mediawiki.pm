package Mediawiki::Mediawiki;

use utf8;
use strict;
use warnings;
use XML::Simple;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Cookies;
use URI;
use URI::Escape;
use Encode;
use Getargs::Long;
use Carp qw( );
use URI qw( );

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
	useImageUploadToken => 1,
	specialFilePath => 'Special:FilePath'
    };

    bless($self, $class);

    # create third parth tools
    $self->userAgent(LWP::UserAgent->new( agent => "MW bot"));
    $self->userAgent()->cookie_jar( HTTP::Cookies->new() );

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
	    my $connectionRetryCounter = 0;
	    my $httpResponse;
	    my $lgtoken = "";
	    do {
		my $postValues = {
			'lgname' => $self->user(),
			'lgpassword' => $self->password(),
			'action' => 'login',
			'format'=> 'xml',
		};
		
		if ($lgtoken) {
		    $postValues->{'lgtoken'} = $lgtoken;
		}
		$httpResponse = $self->makeApiRequest($postValues, "POST");

		if ($httpResponse->content() =~ /token=\"(.*?)\"/ ) {
		    $lgtoken = $1;
		}

	    } while ($httpResponse->content() =~ /NeedToken/i && $connectionRetryCounter++ < 1);

	    if ($httpResponse->content() =~ /wrongpass/i ) {
		$self->log("error", "Failed to logged in '".$self->hostname()."' as '".$self->user()."' : wrong pass.");
		$ok = 0;
	    } elsif ($httpResponse->content() =~ /Throttled/i ) {
		$self->log("error", "Failed to logged in '".$self->hostname()."' as '".$self->user()."' : throttled.");
		$ok = 0;
	    } elsif ($httpResponse->content() =~ /NotExists/i ) {
		$self->log("error", "Failed to logged in '".$self->hostname()."' as '".$self->user()."' : wrong login.");
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
		$self->log("error", "Failed to logged in '".$self->hostname()."' as '".$self->user()."'.");
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

sub rollbackPage {
    my ($self, $page) = @_;
    my $rollbackToken;

    my $httpResponse = $self->makeApiRequest( { 'action' => 'query', 'prop' => 'revisions', 'rvtoken' => 'rollback', 'format' => 'xml', 'titles' => $page } , 'GET');
    if ($httpResponse->content() =~ /rollbacktoken=\"(.*?)\"/ ) {
	$rollbackToken = $1;
    } else {
	$self->log("info", "Was unable to get rollbacktoken correctly : (".$httpResponse->content().").");
	return 0;
    }

    $httpResponse = $self->makeApiRequest(
	{
	    "action" => "rollback",
	    "title" => $page,
	    "token" => $rollbackToken,
	    "format"=> "xml",
	    "user" => $self->user(),
	    "reason"=> "42"
	},
	"POST"
	);

    if ( $httpResponse->content() =~ /\<error\ /) {
	return 0;
    }
    
    return 1;
}

sub emailUser {
    my ($self, $user, $subject, $text) = @_;

    my $httpResponse = $self->makeApiRequest(
	{
	    "action" => "emailuser",
	    "target" => $user,
	    "token" => $self->editToken(),
	    "subject" => "$subject",
	    "text" => "$text",
	    "format" => "xml"
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
	my $httpResponse = $self->makeApiRequest( { 'action' => 'edit', 'format' => 'xml', 'token' => $self->editToken() }, "POST" );
	if ($httpResponse->content() =~ /notitle/i || $httpResponse->content() =~ /notext/i) {
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

sub specialFilePath {
    my $self = shift;
    if (@_) { $self->{specialFilePath} = shift; }
    return $self->{specialFilePath};
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
	'rvprop' => 'content|ids|user',
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
	my $user = $xml->{query}->{pages}->{page}->{revisions}->{rev}->{user};
	$revision = $xml->{query}->{pages}->{page}->{revisions}->{rev}->{revid};

	unless (Encode::is_utf8($content)) {
	    $content = decode_utf8($content);
	}	

	return (ref($content) eq "HASH" ? "" : $content, $revision, $user);
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

    # Encoding
    utf8::encode($title);
    utf8::encode($content);
    utf8::encode($summary);

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

    if ($method eq "POST") {
	$httpResponse = $self->userAgent()->post(
	    $url,
	    $formValues,
	    %$httpHeaders,
	    );
    } elsif ($method eq "GET") {
	$httpResponse = $self->userAgent()->get(
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
    my $loop=0;
    my $loopCount=0;
    my $maxLoopCount = 5;

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
	    $loopCount++;
	    $self->log("error", "Unable to make the following API request. ".Dumper($values)."\n\n, HTTP error code was '".$httpResponse->code()."', ($loopCount time) on '".$url."'. Response content is ".$httpResponse->content().":\n");
	    sleep($loopCount);

	    if ($loopCount > $maxLoopCount) {
		$self->log("info", "Max Loop Count reaches, will NOT retry...");
		$loop = 0;
	    } else {
		$self->log("info", "Will retry..."); 
		$loop = 1;
	    }
	} else {
	    $loop = 0;
	}

    } while($loop);

    return $httpResponse;
}

sub makeHashFromXml {
    my ($self, $xml, $forceArray) = @_;
    return unless $xml;

    # Remove trailing spaces or tabs
    $xml =~ s/^[\ |\t|\n]+//g;

    my @params;
    push(@params, $xml);

    if ($forceArray) {
	push(@params, ForceArray => [($forceArray)] );
    }

    my $hash = eval { XMLin( @params) } ;

    if ($@ || !$hash) {
	$self->log("info", "Unable to parse the following XML:\n".Dumper($xml));
	$self->log("info", "  Reason is:\n$@\n");
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
    my $continue = 0;

    do {
	$self->userAgent()->requests_redirectable([]);
	$url = $self->makeHttpGetRequest($self->indexUrl(), {}, {  'title' => $self->specialFilePath(), 
								   'file' => $image } )->header('location') ;
	$self->userAgent()->requests_redirectable(['HEAD', 'POST', 'GET']);

	if ( $url && $url =~ /\?/ && $url =~ /title\=(.*)\&/ ) {
	    my $newSpecialFilePath = uri_unescape($1);
	    unless (Encode::is_utf8($newSpecialFilePath)) {
		$newSpecialFilePath = decode_utf8($newSpecialFilePath);
	    }
	    $self->specialFilePath($newSpecialFilePath);
	    $continue = 1;
	} else {
	    $continue = 0;
	}
    } while ( $continue );

    return $url;
}

sub getImageHistory {
    my($self, $image) = @_;
    my $size;
    my $imageNamespaceName = $self->getFileNamespaceName();

    unless ($image =~ /^file:/i || $image =~ /^$imageNamespaceName:/i ) {
	$image = "file:".$image;
    }

    my $httpPostRequestParams = {
	'action' => 'query',
	'prop' => 'imageinfo',
	'titles' => $image,
	'format' => 'xml',
	'iilimit' => '10'
    };
    my $xml;

    # make the http request and parse response
    $xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'ii');

    my @results;
    if (exists($xml->{query}->{pages}->{page}->{imageinfo})) {
	@results = @{$xml->{query}->{pages}->{page}->{imageinfo}->{ii}};
    }

    return @results;
}

sub downloadImage {
    my ($self, $image) = @_;
    return $self->makeHttpGetRequest($self->indexUrl(), {}, {  'title' => 'Special:FilePath', 'file' => $image } )->content();
}

sub _uploadImageFromUrl {
    my($self, $title, $url, $summary) = @_;

    my $httpPostRequestParams = {
	    'title' => 'Special:Upload',
	    'wpSourceType' => "url",
	    'wpUploadFileURL' => $url,
	    'wpDestFile' => $title, 
	    'wpUploadDescription' => $summary ? $summary : "",
	    'wpUpload' => 'upload',
	    'wpIgnoreWarning' => '1',
	    'wpForReUpload' => 'true',
	    'wpDestFileWarningAck' => 'true',
	    'action' => 'submit',
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
sub uploadImageFromUrl {
    my($self, $title, $url, $summary, $maxRetry) = @_;
    my $status = 0;
    my $retryCount = 0;
    $maxRetry ||= 1;

    my $httpPostRequestParams = {
	'action' => 'upload',
	'url' => $url,
	'filename' => $title,
	'token' => $self->editToken(),
	'format' => 'xml',
#	'asyncdownload' => '1',
	'ignorewarnings' => '1',
    };
    
    my $httpResponse;
    while (!$status && ($retryCount++ < $maxRetry)) {
	$httpResponse = $self->makeApiRequest($httpPostRequestParams, "POST" );
	my $content = $httpResponse->content;
	
	if ($content =~ /error\ code\=\"([^\"]+)\"/) {
	    $self->log("error", "Error by uploading image '$title' : $1");
	    
	    if ($content =~ /badtoken/i) {
		$self->loadEditToken();
		$self->log("info", "Reloading edit token...");
	    }
	    
	    $status = 0;
	} elsif ($content =~ /upload_session_key\=\"([\d]+)\"/) {
	    my $sessionKey = $1;
	    $httpResponse = $self->makeApiRequest( { 'action' => 'upload', 'httpstatus' => '1', 'sessionkey' => "$sessionKey", 'format' => 'xml', 'token' => $self->editToken() } , 'POST');
	    $self->log("info", "Status upload $title : ".$httpResponse->content);
	    $status = 1;
	} elsif ($content =~ /queued\=\"1"/) {
	    $self->log("info", "Status upload $title : queued");
	    $status = 1;
	} elsif ($content =~ /result=\"success\"/i) {
	    $self->log("info", "File $title successfuly uploaded.");
	    $status = 1;
	} else {
	    $self->log("error", "Error by uploading image '$title' : $content");
	    $status = 0;
	}
    }

    $self->log("info", "Upload reponse for '$title' was : ".$httpResponse->content)
	unless ($status);

    return $status;
}

sub uploadImageWithoutApi {
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

sub uploadImage {
    my ($self, $title, $content, $text, $summary, $ignoreWarning) = @_;
    my $returnValue = 0;

    # Encoding
    utf8::encode($title);
    utf8::encode($text);
    utf8::encode($summary);

    if ($self->hasWriteApi()) {
	unless ($self->editToken()) {
	    unless ($self->loadEditToken()) {
		$self->log("info", "Unable to load edit token for ".$self->hostname());
	    }
	}

	my $postValues = {
	    'action' => 'upload',
	    'token' => $self->editToken(),
	    'file' => [ undef, $title, Content => $content ],
	    'text' => $text,
	    'filename' => $title,
	    'format' => "xml",
	    'comment' => $summary,
	    'ignorewarnings' => $ignoreWarning
	};
	
	my $retryCounter = 0;
	do {
	    my $httpResponse = $self->makeHttpPostRequest($self->apiUrl(), $postValues, { Content_Type  => 'multipart/form-data' });

	    if ($httpResponse->content() =~ /success/i || $httpResponse->content() =~ /articleexists/i || $httpResponse->code() == 503) {
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
		$self->log("error", "Invalid title '$title', this page '$title' can simply not be uploaded.");
		$returnValue = 0;
		last;
	    }

	    if (!$returnValue && $retryCounter <= 15) {
		$self->log("error", "Was unable to upload correctly page '$title' (".$httpResponse->content()."), will retry in ".($retryCounter++)." s.");
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

sub DESTROY
{
}

sub logout {
    my $self = shift;
    
    my $httpResponse = $self->makeApiRequest( { 'action' => 'logout' } , 'GET');
    
    return 0;
}

sub loadEditToken {
    my $self = shift;
    
    my $httpResponse = $self->makeApiRequest( { 'action' => 'query', 'prop' => 'info', 'intoken' => 'edit', 'format' => 'xml', 'titles' => '42' } , 'GET');

    if ($httpResponse->content() =~ /edittoken=\"(.*?)\"/ ) {
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
    my ($self, $title, $ignoredNamespaces) = @_;
    return $self->dependences($title, "templates", $ignoredNamespaces);
}

sub imageDependences {
    my ($self, $title, $ignoredNamespaces) = @_;
    return $self->dependences($title, "images", $ignoredNamespaces);
}

sub dependences {
    my($self, $page, $type, $ignoredNamespaces) = @_;
    $ignoredNamespaces ||= [];
    my @deps;

    my $continueProperty = $type eq "templates" ? "gtlcontinue" : "gimcontinue";
    my $httpPostRequestParams = {
	'action' => 'query',
	'titles' => $page,
	'format' => 'xml',
	'prop' => 'info',
	'gtllimit'=> '500',
	'gimlimit' => '500',
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
		push(@deps, $dep) unless (grep(/^$dep->{'ns'}$/, @$ignoredNamespaces));
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

	    if (!defined($namespace) || defined($namespace) && ($namespace eq $hash->{ns})) {
		my $title = $hash->{title};
		$title =~ tr/ /_/;

                unless (Encode::is_utf8($title)) {
                    $title = decode_utf8($title);
                }

		push( @links, $title );
	    }

	}

    } while ($continue = $xml->{"query-continue"}->{"embeddedin"}->{"eicontinue"});

    return @links;
}

sub langLinks {
    my ($self, $title) = @_;
    my $xml;
    my $httpPostRequestParams = {
	'action' => 'query',
	'titles' => $title,
	'prop' => 'langlinks',
	'lllimit'=> '500',
	'format' => 'xml'
    };

    # make the http request and parse response
    $xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, , forceArray=>'ll');
    return $xml->{query}->{pages}->{page}->{langlinks}->{ll} || [];
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
    } while ($continue = $xml->{"query-continue"}->{"allpages"}->{"apcontinue"});

    return(@pages);
}

sub allUsers {
    my($self) = @_;

    my $httpPostRequestParams = {
        'action' => 'query',
        'list' => 'allusers',
        'format' => 'xml',
	'aulimit' => '500',
    };
    my @users;
    my $continue;
    my $xml;

    do {
	# set the appropriate offset
	if ($continue) {
	    $httpPostRequestParams->{'aufrom'} = $continue;
	}

	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams);

	if (exists($xml->{query}->{allusers})) {
	    foreach my $name (keys($xml->{query}->{allusers}->{u})) {
		my %user;
		$user{'id'} = $xml->{query}->{allusers}->{u}->{$name}->{'userid'};
		$name =~ tr/ /_/;
		$user{'name'} = $name; 
		push(@users, \%user);
            }
	}
    } while ($continue = $xml->{"query-continue"}->{"allusers"}->{"aufrom"});

    # Get more information about the users

    return(@users);
}

sub isGlobalUser {
    my($self, $user) = @_;
    $user = ucfirst($user);

    my $httpPostRequestParams = {
        'action' => 'query',
        'meta' => 'globaluserinfo',
        'format' => 'xml',
	'guiuser' => "$user",
    };
    my @users;
    my $xml;

    do {
	# make the http request and parse response
	$xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams);

	if (exists($xml->{query}->{globaluserinfo}->{missing})) {
	    return;
	}
    };

    return 1;
}

sub userInfo {
    my($self, $user) = @_;
    $user = ucfirst($user);

    my $httpPostRequestParams = {
        'action' => 'query',
        'list' => 'users',
        'usprop' => 'emailable|editcount',
        'format' => 'xml',
	'ususers' => "$user",
    };
    my @users;
    my $xml;

    # make the http request and parse response
    $xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams);
    return $xml->{query}->{users}->{user};
}

sub imageInfos {
    my ($self, $title) = @_;

    my $httpPostRequestParams = {
        'action' => 'query',
        'titles' => $title,
        'prop' => 'imageinfo',
        'format' => 'xml',
	'iilimit' => '50',
	'iiprop' => 'url|archivename',
    };
    my @versions;
    my $xml;

    # make the http request and parse response
    $xml = $self->makeApiRequestAndParseResponse(values=>$httpPostRequestParams, forceArray=>'ii');

    if (exists($xml->{query}->{pages}->{page}->{imageinfo}->{ii})) {
	foreach my $version (@{$xml->{query}->{pages}->{page}->{imageinfo}->{ii}}) {
	    push(@versions, { url => $version->{url} });
	}
    }

    return @versions;
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

    my $imageNamespaceName = $self->getFileNamespaceName();

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
		    $image =~ s/^($imageNamespaceName|file)://i ;
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
    my $title = shift;
    my %result = $self->exist($title);
    my ($key) = keys(%result);
    return $result{$key};
}

sub exist {
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
		exists($page->{missing}) && print STDERR $page->{title}."\n";
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

    $explorationDepth ||= 1;

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
	    
	    print STDERR "Reading '$category'...\n";
	    $self->log("info", "Reading '$category'...");
	    do {
		my $httpPostRequestParams = {
		    'action' => 'query',
		    'cmtitle' => $category,
		    'format' => 'xml',
		    'list' => 'categorymembers',
		    'cmlimit' => '400',
		};
		$httpPostRequestParams->{'cmnamespace'} = join("|", "14", $namespace) 
		    if (defined($namespace) && $namespace ne "");

		
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
			if (!defined($namespace) || $namespace eq "" || ($namespace eq $entry->{ns})) {
			    push(@entries, $entry->{title}) if ($entry->{title});
			}
		    }
		}
		
		$doneCategories{$category} = 1;
		
	    } while ($continue = $xml->{"continue"}->{"cmcontinue"});
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

sub getTemplateNamespaceName() {
    my $self = shift;
    return $self->getNamespaceName(10);
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
    my ($method, $text) = @_;
    
    if ($logger) {
	$logger->$method($text);
    } else {
	if ($method eq "error") {
	    print STDERR $text."\n";
	}
    }
}

1;
