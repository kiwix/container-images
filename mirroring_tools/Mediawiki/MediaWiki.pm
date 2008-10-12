package MediaWiki;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ERR_NO_ERROR ERR_NO_INIHASH ERR_PARSE_INI ERR_NO_AUTHINFO ERR_NO_MSGCACHE ERR_LOGIN_FAILED ERR_LOOP ERR_NOT_FOUND);

use strict;
use XML::Simple;
use URI::Escape qw(uri_escape);
use Search::Tools::XML;
use Data::Dumper;

our($VERSION) = "1.13";
our($has_ini, $has_dumper);

BEGIN
{
	eval 'use LWP::UserAgent; 1;' or die;
	eval 'use HTTP::Request::Common; 1;' or die;
	$has_dumper = eval 'use Data::Dumper; 1;';
	$has_ini = eval 'use Config::IniHash; 1;';

	use MediaWiki::page qw();
}

#
# Error codes
#
sub ERR_NO_ERROR { 0 }
sub ERR_NO_INIHASH { 1 }
sub ERR_PARSE_INI { 2 }
sub ERR_NO_AUTHINFO { 3 }
sub ERR_NO_MSGCACHE { 4 }
sub ERR_LOGIN_FAILED { 5 }
sub ERR_LOOP { 6 }
sub ERR_NOT_FOUND { 7 }

sub new
{
	my $class = shift;
	my $ref = {};

	$ref->{ua} = LWP::UserAgent->new(
		'agent' => __PACKAGE__ . "/$VERSION",
		'cookie_jar' => { "/tmp/lwpcookies.txt", autosave => 0 }
	);
	$ref->{error} = 0;
	
	$ref->{xmlTool} = Search::Tools::XML->new();

	return bless $ref, $class;
}
sub _error
{
	my($mw, $code) = @_;
	$mw->{error} = $code;

	$mw->{on_error}->()
		if($mw->{on_error});
}
sub setup
{
	my($mw, $file) = @_;

	my $cfg;
	if(!$file || ref($file) eq '') # string with file name
	{
		return $mw->_error(ERR_NO_INIHASH)
			if(!$has_ini);

		$cfg = ReadINI($file || (($ENV{HOME} ? "$ENV{HOME}/" : "") . ".bot.ini"),
			systemvars => 1,
			case => 'sensitive',
			forValue => \&_ini_keycheck
		);

		return $mw->_error(ERR_PARSE_INI)
			unless($cfg);
	}
	else
	{
		$cfg = $file;
	}
	$mw->{ini} = $cfg;

	my $proto = ($mw->_cfg("wiki", "ssl") ? "https:" : "http:");
	$mw->{proto} = $proto;

	$mw->{index} = $proto . "//" . $mw->_cfg("wiki", "host") . ( $mw->_cfg("wiki", "path") ? "/".$mw->_cfg("wiki", "path") : "") . "/index.php";

	$mw->{api} = $proto . "//" . $mw->_cfg("wiki", "host") . ( $mw->_cfg("wiki", "path") ? "/".$mw->_cfg("wiki", "path") : "") . "/api.php";

	$mw->{query} =  $proto . "//" . $mw->_cfg("wiki", "host") . "/" . $mw->_cfg("wiki", "path") . "/api.php"
		if($mw->_cfg("wiki", "has_query"));

	my $user = $mw->_cfg("bot", "user");
	my $ret = $mw->login()
		if($user);

	$mw->{msgcache_path} = $mw->_cfg("tmp", "msgcache");
	if(!$mw->{msgcache_path})
	{
		delete $mw->{msgcache};
	}
	else
	{
		my $raw;
		if(open F, $mw->{msgcache_path})
		{
			read F, $raw, -s F;
			close F;
			$mw->{msgcache} = eval $raw;
		}
		else
		{
			$mw->{msgcache} = {};
		}
		$mw->{msgcache_modified} = 0;
	}

	return $ret;
}
sub switch
{
	my($mw, @p) = @_;
	my %wiki_cfg = ();
	if(defined $p[0] && ref($p[0]) eq 'HASH')
	{
		%wiki_cfg = %{$p[0]};
	}
	else
	{
		if(defined $p[0])
		{
			$wiki_cfg{host} = $p[0];
			if(defined $p[1])
			{
				if(ref($p[1]) eq 'HASH')
				{
					foreach my $key(%{$p[1]})
					{
						$wiki_cfg{$key} = $p[1]->{$key};
					}
				}
				else
				{
					$wiki_cfg{path} = $p[1];
					if(defined $p[2] && ref($p[2]) eq 'HASH')
					{
						foreach my $key(%{$p[2]})
						{
							$wiki_cfg{$key} = $p[2]->{$key};
						}
					}
				}
			}
		}
	}
	foreach my $key(keys %{$mw->{ini}->{wiki}})
	{
		$wiki_cfg{$key} = $mw->{ini}->{wiki}->{$key}
			if(!exists $wiki_cfg{$key});
	}

	$wiki_cfg{path} = ""
		if(!$wiki_cfg{path});

	$mw->setup({
		'bot' => $mw->{ini}->{bot},
		'wiki' => \%wiki_cfg,
		'tmp' => $mw->{ini}->{tmp}
	});
}
sub user
{
	my $mw = shift;
	my $user = $mw->_cfg("bot", "user");
	return $user if($user);

	my $obj = $mw->get("Sandbox/getmyip", "rw");
	$obj->{content} .= "_";
	$obj->save();

	my $e = $obj->last_edit;
	return $e->{user};
}

sub downloadPage
{
    my ($self, $page) = @_;
    my $content;

    if ( $self->_cfg("wiki", "has_query") && $self->{query} ) {

	my $res = $self->{ua}->get($self->{query} . "?action=query&prop=revisions&titles=".uri_escape($page)."&format=xml&rvprop=content");
	
	if(!$res->is_success)
	{
	    delete $self->{query} if ($res->code == 404);
	}
	else
	{
	    my $xml = eval { XMLin( $res->content ); };
	    
	    if ($xml && exists($xml->{query}->{pages}->{page}->{revisions}) && exists($xml->{query}->{pages}->{page}->{revisions}->{rev})) {
		if(ref($xml->{query}->{pages}->{page}->{revisions}->{rev}) eq 'ARRAY') {
		    ($content) = (@{$xml->{query}->{pages}->{page}->{revisions}->{rev}});
		} else {
		    $content = $xml->{query}->{pages}->{page}->{revisions}->{rev};
		}
	    }
	}
    } else {
	my $t = $self->{ua}->get($self->_wiki_url . "&action=raw");
	if(!$t->is_success())
	{
	    if($t->code == 404 || $t->code =~ /^3/)
	    {
		$self->{exists} = $t->code == 404 ? 0 : 1;
		$self->{loaded} = 1;
	    }
	    return if($t->code !~ /^3/);
	}
	
	$content = $t->content;
    }
    
    return $content;
}

sub uploadPage {
    my ($self, $title, $content, $summary, $createOnly) = @_;
    
    my $res;
    
    if($self->_cfg("wiki", "has_writeapi"))
    {
	unless ($self->{edit_token}) {
	    $self->load_edit_token();
	}
	
	my $postValues = ({
	    'action' => 'edit',
	    'prop' => 'info',
	    'token' => $self->{edit_token},
	    'text' => $content,
	    'summary' => $summary,
	    'title' => $title,
	    'format' => 'xml'
		       });
	
	if ($createOnly) {
	    $postValues->{'createonly'} = '1';
	}
	
	$res = $self->{ua}->request(
	    POST $self->{query},
	    Content_Type  => 'application/x-www-form-urlencoded',
	    Content       => $postValues
	    );
	
	if ($res->content =~ /success/i ) {
	    if ($res->content =~ /nochange=\"\"/i ) {
		return 2;
	    }
	    return 1;
	}
    } else {
	die ("Error, work only with write api");
    }
    
    return 0;
}

sub uploadImage {
    my($self, $title, $content, $summary) = @_;

    my $url = $self->{index}.'/Special:Upload';

    my $res = $self->{ua}->request(
	POST $url,
	Content_Type  => 'multipart/form-data',
	Content       => [(
	    'wpUploadFile' => [ undef, $title, Content => $content ],
	    'wpDestFile' => $title,
	    'wpUploadDescription' => $summary ? $summary : "",
	    'wpUpload' => 'upload',
	    'wpIgnoreWarning' => 'true'
			  )]
	);

    my $status = $res->code == 302;

    return $status;
}

sub DESTROY
{
	my $mw = shift;
	if($mw->{msgcache_modified} && $has_dumper)
	{
		open F, ">" . $mw->{msgcache_path} or return;
		print F Dumper($mw->{msgcache});
		close F;
	}
}
sub login
{
	my($mw, $user, $pass, $http_user, $http_pass, $http_realm) = @_;
	$user = $mw->_cfg("bot", "user")
		unless $user;
	$pass = $mw->_cfg("bot", "pass")
		unless $pass;
	$http_user = $mw->_cfg("http", "user")
		unless $http_user;
	$http_pass = $mw->_cfg("http", "pass")
		unless $http_pass;
	$http_realm = $mw->_cfg("http", "realm")
		unless $http_realm;


	return $mw->_error(ERR_NO_AUTHINFO)
		unless($user && $pass);
	return 1 if($mw->{logged_in}->{$mw->{index}, $user});

	$mw->{ini}->{bot}->{user} = $user;
	$mw->{ini}->{bot}->{pass} = $pass;

	if($http_user)
	{
		$mw->{ua}->credentials($mw->_cfg("wiki", "host").':'.($mw->_cfg("wiki", "ssl") ? "443" : "80"), $http_realm, $http_user, $http_pass );
		#$mw->{logged_in}->{$mw->{index}, $user} = 1;
		#return 1;
	}

	my $res = $mw->{ua}->request(
		POST $mw->{index} . "?title=Special:Userlogin&action=submitlogin",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [ ( 'wpName' => $user, 'wpPassword' => $pass, 'wpLoginattempt' => 'Log in' ) ]
	);

	if($res->code == 302 || $res->header("Set-Cookie"))
	{
		$mw->{logged_in}->{$mw->{index}, $user} = 1;
		return 1;
	}

	return $mw->_error(ERR_LOGIN_FAILED);
}

sub load_edit_token
{
    my $mw = shift;
    my $res = $mw->{ua}->request(
				POST $mw->{api},
				Content_Type  => 'application/x-www-form-urlencoded',
				Content       => [(
						   'action' => 'query',
						   'prop' => 'info',
						   'intoken' => 'edit',
						   'format' => 'xml',
						   'titles' => '42'
						   )]
				);
    if ($res->content =~ /edittoken=\"(.*)\"/ ) {
	$mw->{edit_token} = $1;
    }
    
    return $mw->{edit_token};
}

sub logout
{
	my($mw, $host) = @_;

	if($host)
	{
		delete $mw->{ua}->{cookie_jar}->{COOKIES}->{$host};
	}
	else
	{
		$mw->{ua}->{cookie_jar}->{COOKIES} = ();
	}

	return 1;
}

sub get
{
	my($mw, $page, $mode) = @_;
	return MediaWiki::page->new(
		-client => $mw,
		-page => $page,
		-mode => $mode
	);
}
sub exists
{
	my($mw, $page) = @_;
	return MediaWiki::page->new(
		-client => $mw,
		-page => $page
	)->exists();
}

sub random
{
	my $mw = shift;
	return MediaWiki::page->new(-client => $mw, -mode => "r");
}

sub _ini_keycheck
{
	my($key, $val, $section) = @_;

	if($section eq "bot")
	{
		return if($key ne "user" && $key ne "pass");
	}
	elsif($section eq "wiki")
	{
		return if($key ne "host" && $key ne "path" && $key ne "has_filepath" && $key ne "has_query");
	}
	elsif($section eq "tmp")
	{
		return if($key ne "msgcache");
	}
	else
	{
		return;
	}

	return $val;
}
sub _cfg
{
	my($mw, $sec, $key) = @_;
	return $mw->{ini}->{$sec}->{$key};
}

sub _get_msg_key
{
	my $mw = shift;
	return $mw->_cfg('wiki', 'host') . "/" . $mw->_cfg('wiki', 'path') . "/";
}
sub refresh_messages
{
	my $mw = shift;
	if(!exists $mw->{msgcache} || !$has_dumper)
	{
		$mw->_error(ERR_NO_MSGCACHE);
		return;
	}

	my $key = $mw->_get_msg_key;
	my $res = $mw->{ua}->get($mw->{index} . "?title=Special:Allmessages");
	return unless $res->is_success;
	$res = $res->content();

	$mw->{msgcache} = {}; my $i = 0;
	while($res =~ /(?<=<tr class=')(?:def|orig)/g)
	{
		my $class = $&;

		$res =~ /(?<=title="MediaWiki:).*?(?=")/g;
		my $msg = $&;
		$res =~ /(?<=<td>).*?(?=<\/td>)/sg;
		$res =~ /(?<=<td>).*?(?=<\/td>)/sg if($class eq 'orig');
		my $val = $&;

		$val =~ s/^\s+//s;
		$val =~ s/\s+$//s;
		$val =~ s'&lt;'<'g;
		$val =~ s'&gt;'>'g;
		$val =~ s'&quot;'"'g;

		$mw->{msgcache}->{$key . $msg} = $val;
		$i ++;
	}
	$mw->{msgcache_modified} = 1 if($i);

	return 1;
}
sub _message
{
	my($mw, $msg) = @_;
	return $mw->get("MediaWiki:$msg")->content;
}
sub message
{
	my($mw, $msg) = @_;
	my $key = $mw->_get_msg_key . ucfirst($msg);

	return $mw->_message($msg)
		unless(exists $mw->{msgcache});

	if(!exists $mw->{msgcache}->{$key})
	{
		$mw->{msgcache}->{$key} = $mw->_message($msg);
		$mw->{msgcache_modified} = 1;
	}
	return $mw->{msgcache}->{$key};
}
sub readcat
{
	my($mw, $cat) = @_;
	my(@pages, @subs) = ();

	#
	# Can we use optimized interface?
	#
	if($mw->{query})
	{
		my $res = $mw->{ua}->get($mw->{query} . "?format=xml&what=category&cptitle=$cat");
		if(!$res->is_success)
		{
			delete $mw->{query} if($res->code == 404);
			goto std_interface;
		}

		$res = $res->content();
		while($res =~ /(?<=<page>).*?(?=<\/page>)/sg)
		{
			my $page = $&;
			$page =~ /(?<=<ns>).*?(?=<\/ns>)/;
			my $ns = $&;
			$page =~ /(?<=<title>).*?(?=<\/title>)/;
			my $title = $&;

			if($ns == 14)
			{
				push @subs, $mw->get($title, "")->_pagename();
			}
			else
			{
				push @pages, $title;
			}
		}
		goto done;
	}

std_interface:
	my $next;
get_one_page:
	my $res = $mw->{ua}->get($mw->{index} . "?title=Category:$cat\&showas=list" . ($next ? "&from=$next" : "") . "&uselang=en");
	return unless $res->is_success;
	$res = $res->content;

	if($res =~ /(?<=from=).*?" title=".*?">next 200/)
	{
		my @a = split /"/, $&;
		$next = shift @a;
	}
	else
	{
		$next = undef;
	}

	my $pos;
	while($res =~ /<h2>Subcategories<\/h2>/g)
	{
		$pos = pos($res);
	}
	if($pos)
	{
		my $sub = substr $res, $pos, (index($res, '</ul>', $pos) - $pos);

		while($sub =~ /(?<=title=").*?(?=">)/sg)
		{
			my @a = split /:/, $&;
			shift @a;
			push @subs, (join ":", @a);
		}
	}
	$res =~ s/.*<h2>Articles in category "$cat"<\/h2>(.*?)<\/table>.*/$1/sg;
	while($res =~ /(?<=title=").*?(?=">)/sg)
	{
		push @pages, $&;
	}
	goto get_one_page
		if($next);

done:
	return(\@pages, \@subs);
}

sub upload
{
	my($mw, $page, $content, $note, $force) = @_;
	return $mw->get("Image:$page", "w")->upload($content, $note, $force);
}

sub download
{
	my($mw, $page) = @_;
	return $mw->get("Image:$page", "r")->download();
}
sub text
{
	my($mw, $page, $content) = @_;
	if(!defined $content)
	{
		my $obj = $mw->get($page);
		return $obj->{exists} ? $obj->{content} : $mw->_error(ERR_NOT_FOUND);
	}

	my $obj = $mw->get($page, "w");
	$obj->{content} = $content;
	return $obj->save();
}
sub block
{
    my($mw, $user, $time) = @_;
	return $mw->get("User:$user", "")->xblock($time, 1, 1, 1);
}
sub xblock
{
	my($mw, $user, $time, $anonOnly, $createAccount, $enableAutoblock) = @_;
	return $mw->get("User:$user", "")->xblock($time, $anonOnly, $createAccount, $enableAutoblock);
}
sub unblock
{
	my($mw, $user) = @_;
	return $mw->get("User:$user", "")->unblock();
}

##ADDED

sub templateDependences {
    my $self = shift;
    return $self->dependences(@_, "templates");
}

sub imageDependences {
    my $self = shift;
    return $self->dependences(@_, "images");
}

sub dependences {
    my($mw, $page, $type) = @_;
    my @deps;

    if ($mw->{query})
    {
	my $continue_property = $type eq "templates" ? "gtlcontinue" : "gimcontinue";
	my $continue;
	my $xml;
	do {
	    my $res = $mw->{ua}->get($mw->{query} . "?action=query&titles=$page&format=xml&prop=info&gtllimit=500&generator=$type".($continue ? "&".$continue_property."=".$continue : "") );
	    
	    if(!$res->is_success)
	    {
		delete $mw->{query} if($res->code == 404);
	    }
	    else
	    {
		$xml = eval { XMLin( $res->content, ForceArray => [('page')] ); };
		
#		if ($@) {
#		    $self->log("error", $@);
#		}
		
		if ($xml && exists($xml->{query}->{pages}->{page})) {
		    foreach my $dep (@{$xml->{query}->{pages}->{page}}) {
			$dep->{title} = $mw->{xmlTool}->unescape( $dep->{title} );
			push(@deps, $dep);
		    } 
		}
	    }
	} while ($continue = $xml->{"query-continue"}->{$type}->{$continue_property} );
    }

    return(\@deps);
}

sub embeddedIn {
    my ($self, $title) = @_;
    my @links;

    my $continue;
    my $xml;

    do {
	my $res = $self->{ua}->get($self->{query}."?action=query&format=xml&eifilterredir=nonredirects&list=embeddedin&eilimit=500&eititle=".uri_escape($title).($continue ? "&eicontinue=".$continue : "") );

	if(!$res->is_success)
	{
	    delete $self->{query} if($res->code == 404);
	}
	else
	{
	    $xml = eval { XMLin( $res->content , ForceArray => [('ei')]  ) };
	    
	    foreach my $hash ( @{ $xml->{query}->{embeddedin}->{ei} } ) {
		push( @links, $hash->{title} );
	    }
	} 
    } while ($continue = $xml->{"query-continue"}->{embeddedin}->{eicontinue} );

    return \@links;
}

sub allPages {
    my($mw, $namespace) = @_;
    my @pages;

    if ($mw->{query})
    {
        my $continue;
        my $xml;
        do {
            my $res = $mw->{ua}->get($mw->{query} . "?action=query&list=allpages&format=xml&aplimit=500&".(defined($namespace) ? "&apnamespace=".$namespace : "").($continue ? "&apfrom=".$continue : "") );

            if(!$res->is_success)
            {
                delete $mw->{query} if($res->code == 404);
            }
            else
            {
		$xml = eval { XMLin( $res->content ); };
		
#		if ($@) {
#		    $self->log("error", $@);
#		}

                if ($xml && exists($xml->{query}->{allpages}->{p})) {
                    if(ref($xml->{query}->{allpages}->{p}) eq 'ARRAY') {
			foreach my $page (@{$xml->{query}->{allpages}->{p}}) {
			    push(@pages, $page->{title}) if ($page->{title});
			}
                    } else {
                        push(@pages, $xml->{allpages}->{p}->{title}) if ($xml->{allpages}->{p}->{title});
                    }
                }
            }
        } while ($continue = $xml->{"query-continue"}->{"allpages"}->{"apfrom"} );
    }

    return(\@pages);
}

sub allImages {
    my($mw) = @_;
    my @images;

    if ($mw->{query})
    {
        my $continue;
        my $xml;
        do {
            my $res = $mw->{ua}->get($mw->{query} . "?action=query&generator=allimages&format=xml&gailimit=500&".($continue ? "&gaifrom=".$continue : "") );

            if(!$res->is_success)
            {
                delete $mw->{query} if($res->code == 404);
            }
            else
            {
		$xml = eval { XMLin( $res->content ); };
		
#		if ($@) {
#		    $self->log("error", $@);
#		}

                if ($xml && exists($xml->{query}->{pages}->{page})) {
                    if(ref($xml->{query}->{pages}->{page}) eq 'ARRAY') {
			foreach my $page (@{$xml->{query}->{pages}->{page}}) {
			    if ($page->{title}) {
				my $image = $page->{title};
				$image =~ s/Image:// ;
				$image =~ s/\ /_/ ;
				push(@images, $image);
			    }
			}
                    } else {
                        if ($xml->{pages}->{page}->{title}) {
			    my $image = $xml->{pages}->{page}->{title};
			    $image =~ s/\ /_/ ;
			    $image =~ s/Image://;
			    push(@images, $image);
			}
                    }
                }
            }
        } while ($continue = $xml->{"query-continue"}->{"allimages"}->{"gaifrom"} );
    }

    return(\@images);
}

sub redirects {
    my($mw, $page) = @_;
    my @redirects;

    if ($mw->{query})
    {
        my $continue;
        my $xml;
        do {
            my $res = $mw->{ua}->get($mw->{query} . "?action=query&list=backlinks&bltitle=".$page."&blfilterredir=redirects&bllimit=500&format=xml&".($continue ? "&blcontinue=".$continue : "") );

            if(!$res->is_success)
            {
                delete $mw->{query} if($res->code == 404);
            }
            else
            {
		$xml = eval { XMLin( $res->content ); };
		
#		if ($@) {
#		    $self->log("error", $@);
#		}

                if ($xml && exists($xml->{query}->{backlinks}->{bl})) {
                    if(ref($xml->{query}->{backlinks}->{bl}) eq 'ARRAY') {
			foreach my $redirect (@{$xml->{query}->{backlinks}->{bl}}) {
			    push(@redirects, $redirect->{title}) if ($redirect->{title});
			}
                    } else {
                        push(@redirects, $xml->{backlinks}->{bl}->{title}) if ($xml->{backlinks}->{bl}->{title});
                    }
                }
            }
        } while ($continue = $xml->{"query-continue"}->{"backlinks"}->{"blcontinue"} );
    }

    return(\@redirects);
}

1;
