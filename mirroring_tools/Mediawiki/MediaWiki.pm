package MediaWiki;

use strict;
use XML::Simple;
use URI::Escape qw(uri_escape);
use Search::Tools::XML;
use Data::Dumper;
use LWP::UserAgent;
use threads;
use threads::shared;
use Devel::Size qw(size total_size);

my $indexUrl;
my $apiUrl;
my $path;
my $hostname;
my $user;
my $password;
my $userAgent;
my $xmlTool;
my $protocol;

my $httpUser;
my $httpPassword;
my $httpRealm;

my $logger;
my $loggerMutex : shared = 1;

my $hasFilePath;
my $hasWriteApi;
my $editToken;

sub new
{
    my $class = shift;
    my $self = {};

    bless($self, $class);

    # create third parth tools
    $self->userAgent(LWP::UserAgent->new());
    $self->xmlTool(Search::Tools::XML->new());

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
    $self->apiUrl($self->protocol().'://'.$self->hostname().($self->path() ? '/'.$self->path() : '')."/api.php?");
}

sub login {
    my $self= shift;

    # return unless a username is specified
    if (!$self->user()) {
	$self->log("info", "Unable to log in to the mediawiki '".$self->hostname()."', no user is specified.");
	return;
    }
    
    # set the http auth. info if necessary
    if($self->httpUser()) {
	$self->userAgent->credentials($self->hostname().':'.($self->protocol() eq 'https' ? "443" : "80"), 
				      $self->httpRealm(), $self->httpUser(), $self->httpPassword() );
    }

    # make the login http request
    my $httpResponse = $self->makeHttpPostRequest(
	$self->indexUrl()."title=Special:Userlogin&action=submitlogin",
	{
	    'wpName' => $self->user(),
	    'wpPassword' => $self->password(),
	    'wpLoginattempt' => 'Log in',
	},
	);

    # check filepath & api
    $self->hasFilePath(1);
    $self->hasWriteApi(1);
    
    # check the http response
    if($httpResponse->code == 302 || $httpResponse->header("Set-Cookie"))
    {
	$self->log("info", "Successfuly logged to '".$self->hostname()."' as '".$self->user()."'.");
	return 1;
    } else {
	$self->log("info", "Failed to logged in '".$self->hostname()."' as '".$self->user()."'.");
	return 0;
    }
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

sub xmlTool {
    my $self = shift;
    if (@_) { $xmlTool = shift; }
    return $xmlTool;
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
    my $content;
    
    my $httpResponse = $self->makeHttpGetRequest($self->apiUrl()."action=query&prop=revisions&titles=".uri_escape($page)."&format=xml&rvprop=content");
    
    if(!$httpResponse->is_success()) {
	$self->log("info", "Unable to download page $page.");
    } else {
	my $xml = eval { XMLin( $httpResponse->content, ForceArray => [('rev')] ); };
	
	if ($xml && 
	    exists($xml->{query}->{pages}->{page}->{revisions}) 
	    && exists($xml->{query}->{pages}->{page}->{revisions}->{rev})) {
	    ($content) = (@{$xml->{query}->{pages}->{page}->{revisions}->{rev}});
	}
    }
    
    return $content;
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
	die("$method is not a valide method for makeHttpRequest().");
    }

    return $httpResponse;
}

sub makeHttpPostRequest {
    my ($self, $url, $formValues, $httpHeaders) = @_;
    
    return $self->makeHttpRequest("POST", $url, $httpHeaders || { Content_Type  => 'multipart/form-data' }, $formValues || {});
}

sub makeHttpGetRequest {
    my ($self, $url, $httpHeaders) = @_;
    
    return $self->makeHttpRequest("GET", $url, $httpHeaders || {});
}

sub filepath {
	my ($obj, $image) = shift;
	my $path;

	if($obj->_cfg("wiki", "has_filepath")) {
	    my $filepath_url = $obj->{index}."/Special:Filepath/" . uri_escape($image);
	    my $loop = 0;
	  first_try_or_redir:
	    $obj->{ua}->{requests_redirectable} = [];
	    my $res = $obj->{ua}->get($filepath_url);
	    $obj->{ua}->{requests_redirectable} = [ "GET", "HEAD" ];
	    
	    if($res->code == 301 && $loop < 5)
	    {
		$filepath_url = $res->header("Location");
		$loop ++;
		
		goto first_try_or_redir;
	    }
	    $obj->_error(ERR_LOOP()) if($loop == 5);
	    return unless $res->code == 302;
	    
	    $path = $res->header("Location");
	}
	
	$path = $obj->{proto} . "//" . $obj->_cfg("wiki", "host") . $path
	    if($path =~ /^\//);

	return $path;
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
    my $continue;
    my $xml;

    do {
	my $httpResponse = $self->makeHttpGetRequest($self->apiUrl(). "action=query&titles=".uri_escape($page)."&format=xml&prop=info&gtllimit=500&generator=$type".($continue ? "&".$continueProperty."=".$continue : "") );
	
	if(!$httpResponse->is_success())
	{
	    $self->log("info", "Unable to get the dependences for '".$page."' by '".$self->hostname()."'.");
	}
	else
	{
	    $xml = XMLin( $httpResponse->content(), ForceArray => [('page')] );
	    
	    if ($@) {
		$self->log("error", "Unable to parse the XML.");
	    }
	    
	    if ($xml && exists($xml->{query}->{pages}->{page})) {
		foreach my $dep (@{$xml->{query}->{pages}->{page}}) {
		    $dep->{title} = $self->xmlTool()->unescape( $dep->{title} );
		    push(@deps, $dep);
		} 
	    }
	}
    } while ($continue = $xml->{"query-continue"}->{$type}->{$continueProperty} );

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
	}
	else
	{
	    $xml = XMLin( $httpResponse->content() , ForceArray => [('ei')]  );

	    foreach my $hash ( @{ $xml->{query}->{embeddedin}->{ei} } ) {
		push( @links, $hash->{title} );
	    }
	} 
    } while ($continue = $xml->{"query-continue"}->{embeddedin}->{eicontinue} );

    return @links;
}

sub allPages {
    my($self, $namespace) = @_;
    my @pages;
    my $continue;
    my $xml;
    
    do {
	my $httpResponse = $self->makeHttpGetRequest($self->apiUrl()."action=query&list=allpages&format=xml&aplimit=500&".(defined($namespace) ? "&apnamespace=".$namespace : "").($continue ? "&apfrom=".$continue : ""));
	
	if(!$httpResponse->is_success()) {
	    $self->log("info", "Unable to get all pages by '".$self->hostname()."'.");
	} else {
	    $xml = XMLin( $httpResponse->content(), ForceArray => [('p')]  );
	    
	    if ($@) {
		$self->log("error", $@);
	    }
	    
	    if ($xml && exists($xml->{query}->{allpages}->{p})) {
		foreach my $page (@{$xml->{query}->{allpages}->{p}}) {
		    push(@pages, $page->{title}) if ($page->{title});
		}
            }
	}
    } while ($continue = $xml->{"query-continue"}->{"allpages"}->{"apfrom"} );

    return(@pages);
}

sub allImages {
    my $self = shift;
    my @images;
    my $continue;
    my $xml;
    
    do {
	my $httpResponse = $self->makeHttpGetRequest($self->apiUrl()."action=query&generator=allimages&format=xml&gailimit=500&".($continue ? "&gaifrom=".$continue : ""));

	if(!$httpResponse->is_success()) {
	    $self->log("info", "Unable to get all images by '".$self->hostname()."'.");
	} else {
	    $xml = XMLin( $httpResponse->content(), ForceArray => [('page')] );
	    
	    if ($@) {
		$self->log("error", $@);
	    }
	    
	    if ($xml && exists($xml->{query}->{pages}->{page})) {
		foreach my $page (@{$xml->{query}->{pages}->{page}}) {
		    if ($page->{title}) {
			my $image = $page->{title};
			$image =~ s/Image:// ;
			$image =~ s/\ /_/ ;
			push(@images, $image);
		    }
		}
            }
	}
    } while ($continue = $xml->{"query-continue"}->{"allimages"}->{"gaifrom"} );


    return(@images);
}

sub redirects {
    my($self, $page) = @_;
    my @redirects;
    my $continue;
    my $xml;
    
    do {
        my $httpResponse = $self->makeHttpGetRequest($self->apiUrl()."action=query&list=backlinks&bltitle=".$page."&blfilterredir=redirects&bllimit=500&format=xml&".($continue ? "&blcontinue=".$continue : ""));
	
	if(!$httpResponse->is_success()) {
	    $self->log("info", "Unable to get incoming redirects for '".$page."' by '".$self->hostname()."'.");
	}
	else
	{
	    $xml = XMLin( $httpResponse->content, ForceArray => [('bl')] );
	    
	    if ($@) {
		$self->log("error", $@);
	    }
	    
	    if ($xml && exists($xml->{query}->{backlinks}->{bl})) {
		foreach my $redirect (@{$xml->{query}->{backlinks}->{bl}}) {
		    push(@redirects, $redirect->{title}) if ($redirect->{title});
		}
            }
	}
    } while ($continue = $xml->{"query-continue"}->{"backlinks"}->{"blcontinue"} );

    return(@redirects);
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
