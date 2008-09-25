package MediaWiki;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(ERR_NO_ERROR ERR_NO_INIHASH ERR_PARSE_INI ERR_NO_AUTHINFO ERR_NO_MSGCACHE ERR_LOGIN_FAILED ERR_LOOP ERR_NOT_FOUND);

use strict;
use XML::Simple;

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
		'cookie_jar' => { "/tmp/lwpcookies.txt", autosave => 1 }
	);
	$ref->{error} = 0;

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
	return $mw->get("Image:$page", "")->upload($content, $note, $force);
}
sub filepath
{
	my($mw, $page) = @_;
	return $mw->get("Image:$page", "")->filepath();
}
sub download
{
	my($mw, $page) = @_;
	return $mw->get("Image:$page", "")->download();
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
		$xml = eval { XMLin( $res->content ); };
		
#		if ($@) {
#		    $self->log("error", $@);
#		}
		
		if ($xml && exists($xml->{query}->{pages}->{page})) {
		    if(ref($xml->{query}->{pages}->{page}) eq 'ARRAY') {
			push(@deps, @{$xml->{query}->{pages}->{page}});
		    } else {
			push(@deps, $xml->{query}->{pages}->{page});
		    }
		}
	    }
	} while ($continue = $xml->{"query-continue"}->{$type}->{$continue_property} );
    }

    return(\@deps);
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

__END__

=head1 NAME

MediaWiki - OOP MediaWiki engine client

=head1 SYNOPSIS

 use MediaWiki;

 $c = MediaWiki->new;
 $is_ok = $c->setup("config.ini");
 $is_ok = $c->setup({
 	'bot' => { 'user' => 'Vasya', 'pass' => '123456' },
 	'wiki' => {
 		'host => 'en.wikipedia.org',
 		'path' => 'w'
 	}})
 $is_ok = $c->switch('starwars.wikia.com');
 $is_ok = $c->switch('en.wikipedia.org', 'w', { 'has_query' => 1, 'has_filepath' => 1 });
 $whoami = $c->user();

 $text = $c->text("page_name_here");
 $is_ok = $c->text("page_name_here", "some new text");

 $c->refresh_messages();
 $msg = $c->message("MediaWiki_message_name");

 die unless $c->exists("page_name");

 my($articles_p, $subcats_p) = $c->readcat("category_name");

 $is_ok = $c->upload("image_name", `cat myfoto.jpg`, "some notes", $force);

 $is_ok = $c->block("VasyaPupkin", "2 days");
 $is_ok = $c->xblock("SomeBadBot", "2 weeks", 0, 1, 0);
 $is_ok = $c->unblock("VasyaPupkin");

 $c->{summary} = "Automatic auto-replacements 1.2";
 $c->{minor} = 1;
 $c->{watch} = 1;

 if(!$is_ok)
 {
    $err = $c->{error};
    # do something
 }

 $pg = $c->random();
 $pg = $c->get("page_name");
 $pg = $c->get("page_name", "");
 $pg = $c->get("page_name", "rw");

 $is_ok = $pg->load();
 $is_ok = $pg->save();
 $text = $pg->oldid($old_version_id);
 $text = $pg->content();
 $title = $pg->title();

 $is_ok = $pg->delete();
 $is_ok = $pg->restore();
 $is_ok = $pg->protect();
 $is_ok = $pg->protect($edit_protection);
 $is_ok = $pg->protect($edit_protection, $move_protection);

 $is_ok = $pg->move("new_name");
 $is_ok = $pg->watch();
 $is_ok = $pg->unwatch();

 $is_ok = $pg->upload(`cat myfoto.jpg`, "some notes", $force);

 $is_ok = $pg->block("2 days");
 $is_ok = $pg->xblock("3 days", 0, 1, 0);
 $is_ok = $pg->unblock();

 $pg->history(sub { my $edit_p = shift; } );
 $pg->history_clear();
 my $edit_p = $pg->last_edit;
 my $edit_p = $pg->find_diff(qr/some_regex/);
 $is_ok = $pg->markpatrolled();
 $is_ok = $pg->revert();

 $pg->{history_step} = 10;

 $is_ok = $pg->replace(sub { my $text_p = shift; } );
 $is_ok = $pg->remove("some_regex_here");
 $is_ok = $pg->remove_template("template_name");

 $pg->{content} = "new text";
 $pg->{summary} = "do something strange";
 $pg->{minor} = 0;
 $pg->{watch} = 1;

=head1 Functions and options

=head2 Client object (MediaWiki) functions

=head3 MediaWiki->new()

Performs basic initialization of the client structure. Returns client object.

=head3 $c->setup([ $ini_file_name | $config_hash_pointer ])

Reads configuration file in INI format; also performs login if username and
password are specified. If file name is omited, "~/.bot.ini is used.

Configuration file can use [bot], [wiki] and [tmp] sections. Keys 'user' and
'pass' in 'bot' section specify login information, additionally the key 'realm'
will trigger basic http authentication instead of a wiki login. 'wiki' section
B<must> have 'host' and 'path' keys (for example, host may be 'en.wikipedia.org'
and path may be 'w') which specify path to I<index.php> script. Also, the
'wiki' section may specify the 'ssl' key (boolean 0/1) if the server uses an
SSL connection. Section 'tmp' and key 'msgcache' specify path to the MediaWiki
messages cache.

Options 'has_query' and 'has_filepath' in 'wiki' section enable experimental
optimized interfaces. Set has_query to 1 if there is query.php extension
(this should reduce traffic usage and servers load). Set has_filepath to 1
if there is Special:Filepath page in target wiki (affects only filepath() and
download() functions).

You may specify configuration in hash array (pass pointer to it instead of
string with file name). It should contain something like
 {
    'wiki' => { 'host' => ..., 'path' => ... },
    'bot' => { 'user' => ..., 'pass' => ... }
 }
 (key of global hash is section and keys of sub-hashes are keys).

=head3 $c->login([$user [, $password [, $realm]]])

Performs login if no login information was specified in configuration. Called
automatically from setup().

=head3 $c->logout([$host])

Removes all HTTP cookies. All following edits will be anonymous until next login() call.
If $host parameter is specified, only cookies for selected served (as in 'wiki'->'host'
configuration key) are cleared.

=head3 $c->switch(($wiki_hash_pointer | $wiki_host [, $wiki_path] [, $wiki_hash_pointer]))

Reconfigures client with specified configuration (this is pointer to hash
array describing _only_ 'wiki' section). Tries login with the same username
and password if auth info specified. If you have already switched to this
wiki (or this is initial wiki, set with I<$c->setup()>), login attempt will
be ommited.

First parameter is either hash pointer ({ 'host' => ..., 'path' => ... }) or
host in first parameter and path in second optional parameter. You may add
hash array pointer as second or third parameter to set other keys, something
like 'has_query'. Call to switch() preserves keys not specified in parameters.

Primary use of this function should be in interwiki bots.

=head3 $c->user()

Returns username from configuration file or makes a dummy edit in wiki sandbox to get
client IP from page history. Note: no result caching is done.

=head3 $c->text( $page_name [, $new_text ])

If $new_text is specified, replaces content of $page_name article with $new_text.
Returns current revision text otherwise. Errors: ERR_NOT_FOUND (article not exists).

=head3 $c->refresh_messages()

Downloads all MediaWiki messages and saves to messages cache.

=head3 $c->message($message_name)

Returns message from cache or undef it cache entry not exists. When no cache is
present at all this functions downloads only one message.

=head3 $c->exists($page_name)

Returns true value if page exists.

=head3 $c->readcat($category_name);

Returns two array references, first with names of all articles, second with names
of all subcategories (without 'Category:' namespace prefix).

=head3 $c->upload($image_name, $content [, $description [, $force]]);

Uploads an image with name 'Image:$image_name' and with content $content. If
description is not specified, empty string will be used. Force flag may be set
to 1 to disable warnings. Currently warnings are not handled properly (see
L</LIMITATIONS>), so force=1 is recommended. That's not default because each rewriting
of the image creates new version, no matter are there any differences or not.
If you never rewrite image, feel free to set $force to 1.

=head3 $c->filepath($image_name)

Returns direct URL for downloading raw image $image_name or undef if image not exists.

=head3 $c->download($image_name)

Returns content of $image_name image or undef if not exists.

=head3 $c->block($user_name, $block_time)

Blocks specified user from editing. Block time should be in format
 [0-9]+ (seconds|minutes|hours|days|months|years)
or in L<ctime> format.

Equal to $c->xblock($user_name, $block_time, 1, 1, 1) call (see below).

B<Note>: this operation requires sysop rights.

=head3 $c->xblock($user_name, $block_time, $anonOnly, $createAccount, $enableAutoblock)

Extended blocking, does the same as block() except for the following:
1. if anonOnly is 1 and we're blocking an IP, registered users who edit from this IP
aren't affected
2. if createAccount is 0, it's not allowed to register new accounts from this IP
3. if enableAutoblock is 1 and we're blocking a registered user, the IP used by
this user is also blocked (it remains hidden in blocks log, however).
See http://meta.wikimedia.org/wiki/Help:Block_and_unblock for more info.

B<Note>: this operation requires sysop rights.

=head3 $c->unblock($user_name)

Unblocks specified user.

B<Note>: this operation requires sysop rights.

B<Note>: this operation requires sysop rights.

=head3 $c->random()

Returns I<page handle> for random article (page in namespace 0).

=head3 $c->get($page [, $mode])

Returns page handle for specified article. Mode parameter may be
"", "r", "w" or "rw" (default "r"). If there is no 'r' in mode,
no page content will be fetched.

If there is 'w' flag, page is loaded in I<Prepared Load Mode>.
There're some options in edit form required for saving page.
When using prepared loading, text is fetched from edit form (not
from raw page) with this values. This reduces traffic usage.
For normal editing, edit form is loaded before saving.

B<Note>: prepared mode is toggled off after first saving.

=head2 Client object (MediaWiki) options

=head3 $c->{minor}

If not set, default value for account will be used. If set to 0,
major edits are made, it set to 1 - minor edits.

=head3 $c->{watch}

If set to 1, edited pages will be included to watch list. If not
set, account default will be used; 0 disables adding to list.

=head3 $c->{summary}

Short description used by default for all edits.

=head3 $c->{error}

Contains advanced error code or 0 if no error/unknown error occured.
See also L</ERRORS HANDLING>

=head3 $c->{on_error}

Callback used each time the error occured.

=head2 Page object (MediaWiki::page) functions

=head3 $pg->load()

Loads page content.

=head3 $pg->save()

Saves changes to this page.

=head3 $pg->prepare()

Performs prepared load (B<do not use this function directly>).

=head3 $pg->content()

Returns page content.

=head3 $pg->oldid($id)

Returns content of an old revision.

=head3 $pg->title()

Returns page title.

=head3 $pg->delete()

Deletes this page.

B<Note>: this operation requires sysop rights.

=head3 $pg->restore()

Restores recently deleted page.

B<Note>: this operation requires sysop rights.

=head3 $pg->protect([$edit_mode [, $move_mode]])

Protects page from edits and/or moves. Protection modes:
2 - for sysop only, 1 - for registered users only, 0 - default,
means no protection. If no parameters specified, protects
against anonymous edits. If only first parameter specified,
move mode will be set to same value.

In order to unprotect page, use C<$pg->protect(0)>.

=head3 $pg->move($new_name)

Renames page setting new title to $new_name and creating redirect
in place of old article. This is only possible if target article
not exists or is redirect without non-redirect versions.

=head3 $pg->watch([$unwatch])

Adds page to watch list. If $unwatch is set, removes page from watch list

=head3 $pg->unwatch()

Synonym for $pg->watch(1)

=head3 $pg->upload($content, [, $description [, $force]])

See $c->upload

=head3 $pg->filepath()

See $c->filepath

=head3 $pg->download()

See $c->download()

=head3 $pg->block($block_time)

See $c->block

=head3 $pg->block($block_time)

See $c->xblock

=head3 $pg->unblock($block_time, $anonOnly, $createAccount, $enableAutoblock)

See $c->unblock

=head3 $pg->history(&cb)

Iterates callback through page history. One parameter is passed, edit info
(this is hash reference). Callback should return undef to continue listing
of true value to stop it. Returns this true value or undef if all edits listed
without interrupting.

Hash reference has the following keys:
 page - pointer to page handler ($pg)
 oldid - revision identifier (may be used in call to $pg->oldid())
 user - username or ip
 anon - is 1 if 'user' contains IP address
 minor - is 1 if this is minor edit
 comment - contains short comment
 section - contains section name (so-called autocomment)
 time - edit time (in format 'HH:MM')
 date - edit date (in format 'D MONTH YYYY')
 datetime - contains time and date separated by ', '

B<Note>: this function used the same history cache as last_edit(), revert() etc.

=head3 $pg->history_clear()

Clear history cache. This is done automatically when page is modified.

=head3 $pg->last_edit()

Return structure of the last edit

=head3 $pg->find_diff($regex)

Finds latest edit in which text matched against $regex added and returns it's structure.

=head3 $pg->markpatrolled()

Mark latest revision of this page as checked by administrator. This is experimental
option and may not present in many MediaWiki installations.

B<Note>: this operation requires sysop rights.

=head3 $pg->revert([$user])

Reverts all changes made by last user who edited this page. This functions B<not>
uses admin quick-revert interface and can be run by anybody. If $user parameter
specified, revert() will do nothing if this user's edits were already reverted
(something already reverted it). Usage of this optional parameter is recommended.

B<Note>: MediaWiki message 'Revertpage' will be used as summary.

=head3 $pg->replace(&cb)

This is most common implementation of replacements bot. It splits wiki-code to
parts which I<may> and which I<should not> be affected (for example, inside pre/nowiki/math
tags) and runs callback for each allowed part. Callback gets pointer to text as parameter
and may change it (and may not change). If text was not change after work of all callbacks,
it will not be saved (this is checked at client-side - that reduces traffic usage).

B<Note>: If page has '{{NO_BOT_TEXT_PROCESSING}}' template, no changes will be done.

=head3 $pg->remove($regex)

This function removes all matches against regex specified.

=head3 $pg->remove_template($template_name)

This function is wrapper for remove. It removes all matches of template specified.

=head2 Page object (MediaWiki::page) options

=head3 $pg->{content}

Raw page content. This is needed to set new content for article.

=head3 $pg->{minor}

See $c->{minor} - local setting (only for this page handle).

=head3 $pg->{watch}

See $c->{watch} - local setting (only for this page handle).

=head3 $pg->{summary}

See $c->{summary} - local setting (only for this page handle).

=head3 $pg->{history_step}

Number of edits fetched in one time. This field can be used for task-related optimization
(increasing it decrease traffic usage and servers load). Default 50.

=head1 ERRORS HANDLING

Currently all methods where return value isn't documented return 1 for success and undef
for failure. You may check advanced error code in $c->{error}, but now not all errors are
properly handled (0 in $c->{error} can mean both success and unknown error).

Also callback may be specified: if there is pointer to subroutine in $c->{on_error} when
error occures, it will be called (with no parameters - error code in $c->{error}).

=head2 ERR_NO_ERROR = 0

No error or unknown error.

=head2 ERR_NO_INIHASH

$c->setup() called with configuration file name but module Config::IniHash not found.

=head2 ERR_PARSE_INI

Parser Config::IniHash found fatal error in configuration file.

=head2 ERR_NO_AUTHINFO

$c->login() called but no auth info known (bot's username & password)

=head2 ERR_NO_MSGCACHE

$c->refresh_messages() called but no path specified in configuration (or Data::Dumper
module not found).

=head2 ERR_LOGIN_FAILED

Login returned something unexpected (maybe password is incorrect).

=head2 ERR_LOOP

Endless loop in some of modules (internal module error or error in wiki engine).

=head2 ERR_NOT_FOUND

$c->text() called but page not exists.

=head1 EXAMPLE

All examples start with

 use MediaWiki;
 my $c = MediaWiki->new();
 $c->setup();

=head2 Very easy example: creating prepared articles

 opendir D, "articles";
 while(defined ($file = readdir(D)))
 {
   if(($file =~ s/\.txt$//) == 1)
   {
      my $text;
      open F, "$file.txt";
      read F, $text, -s F;
      close F;

      $c->text($file, $text);
   }
 }
 closedir D;

=head2 Easy example: replacements bot

 for(my $i = 0; $i < 10000; $i ++)
 {
    my $pg = $c->random();
    $pg->replace(\&my_replacements);
 }

=head2 More complex example: anti-vandalism bot

 $c->{summary} = "Vandalism: blanking more than 5 times";

 my %users = (); my %articles = ();
 while(1)
 {
    my $pg = $c->random();
    if($pg->content() eq '')
    {
      my $e = $pg->last_edit;
      $blanker = $e->{user};

      $pg->revert();
      $e = $pg->last_edit;

      if($e->{user} eq $blanker) # Only author
      {
         $pg->{content} .= "{{db-author}}"; # Delete note for admins
	 $pg->{summary} = "+ {{db-author}}";
	 $pg->save();
      }
      else
      {
        $users{$blanker} = 1 + (exists $users{$blanker} ? $users{$blanker} : 0);
	if($users{$blanker} > 5)
	{
	  $c->block($blanker, "1 hour");
	  delete $users{$blanker};
	}
      }
    }
 }

=head1 AUTHOR

Edward Chernenko <edwardspec@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2006 Edward Chernenko.
This program is protected by Artistic License and can be used and/or
distributed by the same rules as perl. All right reserved.

=head1 SEE ALSO

L<CMS::MediaWiki>, L<WWW::Wikipedia>, L<WWW:Mediawiki::Client>
