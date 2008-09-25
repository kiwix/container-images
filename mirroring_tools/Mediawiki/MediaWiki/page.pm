package MediaWiki::page;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();

use strict;
use vars qw(
	$edittime_regex
	$watchthis_regex
	$minoredit_regex
	$edittoken_regex
	$edittoken_rev_regex
	$autosumm_regex
	$edittoken_delete_regex
	$pagehistory_delete_regex
	$timestamp_regex
	$historyuser_regex1
	$historyuser_regex_reg
	$historyuser_regex_anon
	$noanon_regex
	$minor_regex
	$autocomment_regex
	$autocomment_delete_regex
	$autocomment_clear_regex
	$unhex_regex
	$unhex_regex2
	$comment_regex
	$li_regex
	$link_regex1
	$filepath_regex
	$src_regex
	$oldid_regex
	$offset_regex
	$permission_error_regex
	$numbersonly_regex
	$edit_token
);
our @protection = ("", "autoconfirmed", "sysop");

BEGIN
{
	use URI::Escape qw(uri_escape);
	use HTTP::Request::Common;
	use MediaWiki qw(ERR_NO_ERROR ERR_NO_INIHASH ERR_PARSE_INI ERR_NO_AUTHINFO ERR_NO_MSGCACHE ERR_LOGIN_FAILED ERR_LOOP);

	#
	# We should compile all regular expressions first
	#
	$edittime_regex = qr/(?<=value=["'])[0-9]+(?=["'] name=["']wpEdittime["'])/;
	$watchthis_regex = qr/name=["']wpWatchthis["'] checked/;
	$minoredit_regex = qr/(?<=value=["'])1(?=["'] name=["']wpMinoredit["'])/;
	$edittoken_regex = qr/(?<=value=["'])[0-9a-f]*\+?\\?(?=["'] name=["']wpEditToken["'])/;
	$edittoken_rev_regex = qr/(?<=name=['"]wpEditToken['"] value=["'])[0-9a-f]+\+?\\?(?=["'])/;
	$autosumm_regex = qr/(?<=name=["']wpAutoSummary["'] value=["'])[0-9a-f]+(?=["'])/;
	$edittoken_delete_regex = qr/^.*wpEditToken["'][^>]*?value=["'](.*?)["'].*$/s;
	$pagehistory_delete_regex = qr/.*<ul id\=["']pagehistory["']>(.*?)<\/ul>.*/;

	$timestamp_regex = qr/(?<=>).*?(?=<\/a> <span class=['"]history\-user['"]>)/;

	$historyuser_regex1 = qr/(?<=<span class=["']history\-user["']>).*?(?=<\/span>)/;
	$historyuser_regex_anon = qr/(?<=\:)[^"']*?(?=['"]>Talk<)/;
	$historyuser_regex_reg = qr/(?<=:)(.*?)['"]>\1</;
	$noanon_regex = qr/\>contribs\</;
	$minor_regex = qr/span class=["']minor["']/;
	$autocomment_regex = qr/(?<=<span class=["']autocomment["']>).*?(?=<\/span>)/;
	$autocomment_delete_regex = qr/<span class=["']autocomment["']>.*?<\/span>\s*/;
	$autocomment_clear_regex = qr/(?<=#).*?(?=["'])/;
	$unhex_regex = qr/\.([0-9a-fA-F][0-9a-fA-F])/;
	$unhex_regex2 = qr/\%([0-9a-fA-F][0-9a-fA-F])/;
	$comment_regex = qr/(?<=<span class=["']comment["']>\().*?(?=\)<\/span>)/;
	$li_regex = qr/(?<=<li>).*?(?=<\/li>)/;
	$link_regex1 = qr/<a href=["']\/wiki\/(.*?)["'].*?title=["'](?:.*?)['"]>(.*?)<\/a>/;

	$filepath_regex = qr/(?<=<div class=["']fullImageLink["'] id=["']file["']>).*?(?=<\/div>)/;
	$src_regex = qr/(?<=src=['"]).*?(?=['"])/;

	$oldid_regex = qr/(?<=&amp;oldid=)[0-9]+(?=["'])/;
	$offset_regex = qr/(?<=offset=)[0-9]+/;
	$numbersonly_regex = qr/.*?([0-9]+).*/;

	# TODO: compile this only if admin interface enabled in bot.ini
	$permission_error_regex = qr/<h1 class="firstHeading">Permission error<\/h1>/;
}

sub new
{
	my($class, %params) = @_;
	my $ref = {};

	$ref->{client} = $params{-client} || MediaWiki->new();
	$ref->{title} = $params{-page} || "Special:Random";
	$ref->{prepared} = ($params{-mode} && $params{-mode} =~ /w/) ? 1 : 0;
	$ref->{loaded} = 0;
	$ref->{ua} = $ref->{client}->{ua};

	$ref->{title} =~ tr/ /_/;

	bless $ref, $class;
	$ref->load()
		if(!defined $params{-mode} || $params{-mode} =~ /r/ || $ref->{prepared});
	return $ref;
}

sub oldid
{
	my($obj, $oldid) = @_;
	my $t = $obj->{ua}->get($obj->_wiki_url . "&action=raw" . ($oldid ? "&oldid=$oldid" : ""));
	return $t->is_success ? $t->content : undef;
}
sub load
{
	my $obj = shift;
	$obj->{loaded} = 0;

	if($obj->{prepared})
	{
		$obj->prepare();
	}
	else
	{
		my $t = $obj->{ua}->get($obj->_wiki_url . "&action=raw");
		if(!$t->is_success())
		{
			if($t->code == 404 || $t->code =~ /^3/)
			{
				$obj->{exists} = $t->code == 404 ? 0 : 1;
				$obj->{loaded} = 1;
			}
			return if($t->code !~ /^3/);
		}

		$obj->{content} = $t->content;
		if($obj->{title} eq 'Special:Random')
		{
			my $title = $t->header("Title");
			$title =~ s/\s*(—|-)(.*?)$//;
			$obj->{title} = $title;
			return $obj->load();
		}

		$obj->{exists} = $t->code == 404 ? 0 : 1;
	}
	$obj->{title} =~ tr/ /_/;
	$obj->{loaded} = 1;

	return 1;
}
sub save
{
	my $obj = shift;

	$obj->prepare()
		if(!$obj->{prepared});
	$obj->{prepared} = 0;

	my $res;

	if($obj->{client}->_cfg("wiki", "has_writeapi"))
	{
	    unless ($obj->{client}->{edit_token}) {
		$obj->{client}->load_edit_token();
	    }

	    $res = $obj->{client}->{ua}->request(
						 POST $obj->_api_url(),
						 Content_Type  => 'application/x-www-form-urlencoded',
						 Content       => [(
								    'action' => 'edit',
								    'prop' => 'info',
								    'token' => $obj->{client}->{edit_token},
								    'text' => $obj->{content},
								    'summary' => $obj->_summary(),
								    'title' => $obj->{title},
								    'format' => 'xml'
								    )]
						 );

	    if ($res->content =~ /success/i ) {
		return 1;
	    }
	} else {
	    $res= $obj->{client}->{ua}->request(
						POST $obj->_wiki_url . "&action=edit",
						Content_Type  => 'application/x-www-form-urlencoded',
						Content       => [(
								   'wpTextbox1' => $obj->{content},
								   'wpEdittime' => $obj->{edittime},
								   'wpSave' => 'Save page',
								   'wpSection' => '',
								   'wpSummary' => $obj->_summary(),
								   'wpEditToken' => $obj->{edittoken},
								   'title' => $obj->{title},
								   'action' => 'submit',
								   'wpMinoredit' => $obj->{minor},
								   'wpAutoSummary' => $obj->{autosumm},
								   'wpRecreate' => 1
								   )]
						);

	    if($res->code == 302)
	    {
		$obj->history_clear();
		return 1;
	    }
	}

	# Handle size warning or forced preview
	my $t = $res->content;
	if($t =~ /Preview/)
	{
		$obj->prepare_update_tokens($t);
		$res = $obj->{client}->{ua}->request(
			POST $obj->_wiki_url . "&action=edit",
			Content_Type  => 'application/x-www-form-urlencoded',
			Content       => [(
				'wpTextbox1' => $obj->{content},
				'wpEdittime' => $obj->{edittime},
				'wpSave' => 'Save page',
				'wpSection' => '',
				'wpSummary' => $obj->_summary(),
				'wpEditToken' => $obj->{edittoken},
				'title' => $obj->{title},
				'action' => 'submit',
				'wpMinoredit' => $obj->{minor},
				'wpAutoSummary' => $obj->{autosumm},
				'wpRecreate' => 1
			)]
		);
		if($res->code == 302)
		{
			$obj->history_clear();
			return 1;
		}
	}
	return;
}

sub prepare_update_tokens
{
	my $obj = shift;
	my $t = shift;

	if($t =~ /$edittime_regex/)
	{
		$obj->{edittime} = $&;
	}
	if($obj->{client}->{watch} || $t =~ /$watchthis_regex/)
	{
		$obj->{watch} = 1;
	}
	if($obj->{client}->{minor} || $t =~ /$minoredit_regex/)
	{
		$obj->{minor} = 1;
	}
	if($t =~ /$edittoken_regex/)
	{
		$obj->{edittoken} = $&;
	}
	if($t =~ /$autosumm_regex/)
	{
		$obj->{autosumm} = $&;
	}
}

sub prepare
{
	my $obj = shift;

	my $t = $obj->{ua}->get($obj->_wiki_url . "&action=edit");
	return unless $t->is_success;
	$t = $t->content();

	if($obj->{prepared}) # Must fill 'content' field
	{
		my($a) = split /<\/textarea>/, $t;
		$a =~ s/.*<textarea.*?>//sg;

		$a =~ s/&lt;/</g;
		$a =~ s/&gt;/>/g;
		$a =~ s/&amp;/&/g;
		$a =~ s/&quot;/"/g;

		$obj->{content} = $a;
		$obj->{exists} = 1;
	}
	$obj->prepare_update_tokens($t);
	return;
}
sub exists
{
	my $obj = shift;
	$obj->load()
		unless($obj->{loaded});
	return $obj->{exists};
}
sub title
{
	my $obj = shift;
	return $obj->{title}
		if($obj->{loaded} || ($obj->{title} && $obj->{title} ne "Special:Random"));

	$obj->load();
	return $obj->{title};
}
sub content
{
	my $obj = shift;
	$obj->load()
		unless $obj->{loaded};
	return $obj->{content};
}

sub _wiki_url
{
	my($obj, $title) = @_;
	return $obj->{client}->{index} . "?title=" . uri_escape($title || $obj->{title});
}

sub _api_url
{
	my($obj, $title) = @_;
	return $obj->{client}->{api};
}

sub _summary
{
	my $obj = shift;
	return $obj->{summary} || $obj->{client}->{summary} || "Edit via perl MediaWiki framework ($MediaWiki::VERSION)";
}

sub delete
{
	my $obj = shift;

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url . "&action=delete");
		return unless($res->is_success);
		$res = $res->content;
		return if($res =~ /$permission_error_regex/);
		$res =~ s/$edittoken_delete_regex/$1/s;
		$obj->{edittoken} = $res;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url . "&action=delete",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'wpConfirmB' => 'Delete page'
		)]
	);
	return if($res->is_success && $res->content !~ /$permission_error_regex/);
}
sub restore
{
	my $obj = shift;

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Undelete") . "/" . $obj->title);
		return unless($res->is_success);
		$res = $res->content;
		return if($res =~ /$permission_error_regex/);
		$res =~ s/$edittoken_delete_regex/$1/s;

		$obj->{edittoken} = $res;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Undelete") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'target' => $obj->{title},
			'wpEditToken' => $obj->{edittoken},
			'wpComment' => $obj->_summary(),
			'restore' => 'confirm'
		)]
	);
	return if($res->is_success && $res->content !~ /$permission_error_regex/);
}
sub protect
{
	my($obj, $edit, $move) = @_;
	$edit = 1 unless(defined $edit);

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url . "&action=protect");
		return unless($res->is_success);
		$res = $res->content;
		$res =~ /$edittoken_rev_regex/;
		$obj->{edittoken} = $&;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url . "&action=protect",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'mwProtect-level-edit' => $protection[$edit],
			'mwProtect-level-move' => $protection[defined $move ? $move : $edit],
			'mwProtect-reason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken}
		)]
	);
	return if($res->is_success && $res->content !~ /$permission_error_regex/);
}
sub move
{
	my($obj, $title) = @_;

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Movepage/" . $obj->{title}));
		return unless($res->is_success);
		$res = $res->content;
		return if($res =~ /$permission_error_regex/);
		$res =~ s/$edittoken_delete_regex/$1/s;
		$obj->{edittoken} = $res;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Movepage") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpNewTitle' => $title,
			'wpOldTitle' => $obj->{title},
			'wpReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken}
		)]
	);
	return unless($res->code == 302);

	$obj->{title} = $title;
	return 1;
}
sub watch
{
	my($obj, $unwatch) = @_;
	return $obj->{ua}->get($obj->_wiki_url . "action=" . ($unwatch ? "un" : "") . "watch")->is_success;
}
sub unwatch
{
	my $obj = shift;
	$obj->watch(1);
}

sub _pagename
{
	my $obj = shift;
	my @a = split /:/, $obj->title();
	shift @a;
	return join(":", @a);
}

sub upload
{
	my($obj, $content, $note, $force) = @_;
	my $title = $obj->_pagename();

	#
	# TODO: check for all known warnings; return extended error info
	#
	my $upload_url = $obj->{client}->{index} . "/Special:Upload";
	my $loop = 0;

first_try_or_redir:
	my $res = $obj->{ua}->request(
		# FIXME: may not work for some MediaWiki installations
		POST $upload_url,
		Content_Type  => 'multipart/form-data',
		Content       => [(
			'wpUploadFile' => [ undef, $title, Content => $content ],
			'wpDestFile' => $title,
			'wpUploadDescription' => $note ? $note : "",
			'wpUpload' => 'upload',
			'wpIgnoreWarning' => $force ? 'true' : 0
		)]
	);

	if($res->code == 301 && $loop < 5)
	{
		$upload_url = $res->header("Location");
		$loop ++;

		goto first_try_or_redir;
	}
	$obj->{client}->_error(ERR_LOOP()) if($loop == 5);
	return $res->code == 302;
}
sub filepath
{
	my $obj = shift; my $path;

	if($obj->{client}->_cfg("wiki", "has_filepath"))
	{
		my $filepath_url = $obj->_wiki_url("Special:Filepath/" . $obj->_pagename());
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
		$obj->{client}->_error(ERR_LOOP()) if($loop == 5);
		return unless $res->code == 302;

		$path = $res->header("Location");
		goto expand_path;
	}

	my $res = $obj->{ua}->get($obj->_wiki_url());
	return unless $res->is_success();
	$res = $res->content();

	$res =~ /$filepath_regex/g;
	my $match = $&;
	$match =~ /$src_regex/;
	$path = $&;
	return unless $path;

expand_path:
	$path = $obj->{client}->{proto} . "//" . $obj->{client}->_cfg("wiki", "host") . $path
		if($path =~ /^\//);

	return $path;
}
sub download
{
	my $obj = shift;
	my $path = $obj->filepath() || return;
	return $obj->{ua}->get($path)->content();
}

sub xblock
{
	my($obj, $time, $anonOnly, $createAccount, $enableAutoblock) = @_;
	my $user = $obj->_pagename();

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Blockip/" . $obj->{title}));
		return unless($res->is_success);
		$res = $res->content;
		$res =~ /$edittoken_rev_regex/;
		$obj->{edittoken} = $&;
	}
	$obj->{prepared} = 0;

	return $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Blockip") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpBlockAddress' => $obj->_pagename(),
			'wpBlockExpiry' => 'other',
			'wpBlockOther' => $time,
			'wpBlockReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'wpBlock' => 'Block',
			'wpAnonOnly' => $anonOnly,
			'wpCreateAccount' => $createAccount,
			'wpEnableAutoblock' => $enableAutoblock,
		)]
	)->code == 302;
}
sub block
{
	my($obj, $time) = @_;
	return $obj->xblock($time, 1, 1, 1);
}
sub unblock
{
	my $obj = shift;
	my $user = $obj->_pagename();

	if(!$obj->{prepared})
	{
		my $res = $obj->{ua}->get($obj->_wiki_url("Special:Ipblocklist"). "&action=unblock&ip=$user");
		return unless($res->is_success);
		$res = $res->content;
		$res =~ /$edittoken_rev_regex/;
		$obj->{edittoken} = $&;
	}
	$obj->{prepared} = 0;

	my $res = $obj->{ua}->request(
		POST $obj->_wiki_url("Special:Ipblocklist") . "&action=submit",
		Content_Type  => 'application/x-www-form-urlencoded',
		Content       => [(
			'wpUnblockAddress' => $obj->_pagename(),
			'wpUnblockReason' => $obj->_summary(),
			'wpEditToken' => $obj->{edittoken},
			'wpBlock' => 'Unblock'
		)]
	);
}
sub _url_decode
{
	my $str = shift;
	$str =~ tr/+/ /;
	$str =~ s/$unhex_regex2/pack("C", hex($1))/eg;
	return $str;
}

sub _history_init
{
	my($obj, $force) = @_;
	if(!$obj->{history} || $force)
	{
		$obj->{history} = [];
		$obj->{history_offset} = undef;
	}
}
sub _history_preload
{
	my($obj, $offset) = @_;
	my $page = $obj->{title}; my $pageq = quotemeta($page);
	my $limit = $obj->{history_step} || 50;

	my $wiki_path = $obj->{client}->_cfg("wiki", "path");
	my $link_regex2 = qr/<a href=['"]\/$wiki_path\/index\.php(?:\/|\?title=)(.*?)\&.*?['"]>(.*?)<\/a>/;
	my $offset_area_regex = qr/(?<=<)[^\(]*?(?=>next $limit)/;

	my $url = $obj->_wiki_url . "&action=history&limit=$limit" . ($offset ? "&offset=$offset" : "") . "&uselang=en";

	my $res = $obj->{ua}->get($url);
	return unless($res->is_success);
	$res = $res->content();

	if($res =~ /$offset_area_regex/)
	{
		my $match = $&;
		$match =~ /$offset_regex/;
		$offset = $match;

		$offset =~ s/$numbersonly_regex/$1/g;
	}
	else
	{
		$offset = undef;
	}
	$res =~ s/$pagehistory_delete_regex/$1/g;

	$res =~ /$li_regex/g if($obj->{history_offset});
	while($res =~ /$li_regex/g)
	{
		my $item = $&;
		my $oldid;

		while($item =~ /$oldid_regex/g)
		{
			$oldid = $&;
		}

		$item =~ /$timestamp_regex/;
		my @a = split />/, $&;
		my $datetime = pop @a;
		my($time, $date) = split /, /, $datetime;

		$item =~ /$historyuser_regex1/;
		my $user = $&; my $anon;
		$anon = ($user =~ /$noanon_regex/) ? 0 : 1;

		if($anon)
		{
			$user =~ /$historyuser_regex_anon/;
			$user = $&;
		}
		else
		{
			$user =~ /$historyuser_regex_reg/;
			($user) = split(/['"]/, $&);
			$user = _url_decode($user);
		}
		#
		# For old MediaWiki versions - if parsing failed
		#
		if($user =~ /<a href/)
		{
			$user =~ /(?<=\>).*?(?=\<)/;
			$user = $&;
		}

		my $minor = 0;
		$minor = 1
			if($item =~ /$minor_regex/);

		my $section = "";
		if($item =~ /$autocomment_regex/)
		{
			my $autocomment = $&;
			$item =~ s/$autocomment_delete_regex//g;

			$autocomment =~ /$autocomment_clear_regex/;
			$section = $&;
			$section =~ s/$unhex_regex/pack("C", hex($1))/eg;
		}

		my $comment = "";
		if($item =~ /$comment_regex/)
		{
			$comment = $&;
			$comment =~ s/$link_regex1/[[$1|$2]]/g;
			$comment =~ s/$link_regex2/[[$1|$2]]/g;

			$comment =~ s/\[\[(.*?)\|(.*?)\]\]/"[[" . _url_decode($1) . "|" . _url_decode($2) . "]]"/ge;
		}

		my $edit = {
			'page' => $obj,
			'oldid' => $oldid,
			'user' => $user,
			'anon' => $anon,
			'minor' => $minor,
			'comment' => $comment,
			'section' => $section,
			'time' => $time,
			'date' => $date,
			'datetime' => "$time, $date"
		};
		push @{$obj->{history}}, $edit;
	}
	$obj->{history_offset} = $offset;
	return $offset;
}

sub history
{
	my($obj, $cb) =  @_;
	my $offset; my $j = 0;

	$obj->_history_init();
	while(1)
	{
		$offset = $obj->_history_preload($offset);

		for(my $k = $j; $k < @{$obj->{history}}; $k ++, $j ++)
		{
			my $ret = &$cb($obj->{history}->[$k]);
			return $ret if($ret);
		}
		last unless $offset;
	}
}
sub history_clear
{
	my $obj = shift;
	delete $obj->{history};
}
sub last_edit
{
	my $obj = shift;
	my $hp = $obj->{history};
	if(!$hp || !@$hp)
	{
		$obj->_history_init();
		$obj->_history_preload();
		$hp = $obj->{history};
	}
	return $hp->[0];
}
sub markpatrolled
{
	my $obj = shift;
	my $hp = $obj->{history};
	if(!$hp || !@$hp)
	{
		$obj->_history_init();
		$obj->_history_preload();
		$hp = $obj->{history};
	}
	my $oldid = $hp->[0]->{oldid};
	return $obj->{ua}->get($obj->_wiki_url . "&action=markpatrolled&rcid=$oldid")->is_success;
}
sub revert
{
	my($obj, $expected_last_user) = @_;
	$obj->_history_init();

	my $j = 0; my $offset = $obj->{history_offset}; my $last_user;
	while(1)
	{
		if(!$obj->{history}->[$j])
		{
			last if($j && !$offset);
			$offset = $obj->_history_preload($offset);
		}

		my $edit = $obj->{history}->[$j];
		my $user = $edit->{user};

		if($last_user && $last_user ne $user)
		{
			my $msg = $obj->{client}->message("Revertpage") || "rv";
			$msg =~ s/\$2/$last_user/g;
			$msg =~ s/\$1/$user/g;

			$obj->{content} = $obj->oldid($edit->{oldid});

			my $save_summ = $obj->{summary};
			$obj->{summary} = $msg;
			my $ret = $obj->save();
			$obj->{summary} = $save_summ;

			return $ret;
		}

		if(!$last_user)
		{
			return if($expected_last_user && ($edit->{user} ne $expected_last_user));
			$last_user = $edit->{user};
		}

		$j ++;
	}
	return;
}
sub find_diff
{
	my($obj, $regex) =  @_;
	my $offset; my $j = 0;

	$obj->_history_init();
	while(1)
	{
		$offset = $obj->_history_preload($offset);

		for(my $k = $j; $k < @{$obj->{history}}; $k ++, $j ++)
		{
			if($obj->oldid($obj->{history}->[$k]->{oldid}) !~ /$regex/)
			{
				return unless($k);
				return $obj->{history}->[$k-1];
			}
		}
		last unless $offset;
	}
	return;
}

sub replace
{
	my($obj, $cb) = @_;
	my $text = $obj->content();
	return if($text =~ /\{\{NO_BOT_TEXT_PROCESSING}}/);

	my @parts = ();
	my $last_end = 0;
	while($text =~ /<(nowiki|math|pre)>.*?<\/\1>/sg)
	{
		my $skipped = $&;
		my $len = length $&;
		my $end = pos($text);
		my $start = $end - $len;

		my $used = substr $text, $last_end, $start - $last_end;
		$last_end = $end;

		push @parts, [$used, 1]
			if(length($used) > 0);
		push @parts, [$skipped, 0];
	}
	if($last_end <= length($text) - 1)
	{
		push @parts,
			[substr($text, $last_end, length($text) - $last_end), 1];
	}

	foreach my $part(@parts)
	{
		&$cb(\$part->[0])
			if($part->[1] == 1);
	}

	my $new_text = "";
	foreach my $part(@parts)
	{
		$new_text .= $part->[0];
	}
	return 1 if($new_text eq $text);
	$obj->{content} = $new_text;
	return $obj->save();
}
sub remove
{
	my($obj, $regex) = @_;
	my $text = $obj->content();

	my @parts = ();
	my $last_end = 0;
	while($text =~ /<(nowiki|math|pre)>.*?<\/\1>/sg)
	{
		my $skipped = $&;
		my $len = length $&;
		my $end = pos($text);
		my $start = $end - $len;

		my $used = substr $text, $last_end, $start - $last_end;
		$last_end = $end;

		push @parts, [$used, 1]
			if(length($used) > 0);
		push @parts, [$skipped, 0];
	}
	if($last_end <= length($text) - 1)
	{
		push @parts,
			[substr($text, $last_end, length($text) - $last_end), 1];
	}

	foreach my $part(@parts)
	{
		$part->[0] =~ s/$regex//g
			if($part->[1] == 1);
	}

	my $new_text = "";
	foreach my $part(@parts)
	{
		$new_text .= $part->[0];
	}
	return 1 if($new_text eq $text);
	$obj->{content} = $new_text;
	return $obj->save();
}
sub remove_template
{
	my($obj, $tmpl) = @_;
	return $obj->remove('\{\{' . quotemeta($tmpl) . '\|[.\n]*?\}\}');
}
