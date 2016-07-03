#!/bin/sh
":" //# -*- mode: js -*-; exec /usr/bin/env node --max-old-space-size=1900 --stack-size=4096 "$0" "$@"

"use strict";

/* INCLUDES */
var twitter = require( 'twitter' );
var irc = require( 'irc' );
var rssWatcher = require( 'rss-watcher' );
var htmlToText = require( 'html-to-text' );
var yargs = require( 'yargs' );

/* Arguments */
var argv = yargs.usage( 'Feed #kiwix Freenode IRC channels in real-time with Sourceforge, twitter, wikis activities: $0' )
    .require( ['consumerKey', 'consumerSecret', 'accessTokenKey', 'accessTokenSecret', 'githubToken' ] )
    .argv;

/* VARIABLES */
var lastTwitterId;
var ircClient
var client = new twitter({
    consumer_key: argv.consumerKey,
    consumer_secret: argv.consumerSecret,
    access_token_key: argv.accessTokenKey,
    access_token_secret: argv.accessTokenSecret
});
var kiwixItunesFeed = 'https://itunes.apple.com/us/rss/customerreviews/id=997079563/sortBy=mostRecent/xml';
var kiwixWikiFeed = 'http://www.kiwix.org/w/api.php?hidebots=1&days=7&limit=50&translations=filter&action=feedrecentchanges&feedformat=rss';
var openzimWikiFeed = 'http://www.openzim.org/w/api.php?hidebots=1&days=7&limit=50&translations=filter&action=feedrecentchanges&feedformat=rss';
var openzimGitFeed = 'https://github.com/wikimedia/openzim/commits/master.atom';
var sourceforgeFeed = 'https://sourceforge.net/p/kiwix/activity/feed.rss';
var githubFeed = 'https://github.com/organizations/kiwix/kelson42.private.atom?token=' + argv.githubToken;

/* FUNCTIONS */
function connectIrc() {
    ircClient= new irc.Client( 'irc.freenode.net', 'WatcherBot', {
	channels: [ '#kiwix' ],
    });
}

function html2txt( html ) {
    return htmlToText.fromString( html ).replace( new RegExp( /\[[^\[]*\]/ ), '' ).replace( new RegExp( /[ ]+/ ), ' ' );
}

/* INIT */
connectIrc();

/* GITHUB */
var lastGithubPubDate;
var githubWatcher = new rssWatcher( githubFeed );
githubWatcher.set( {feed: githubFeed, interval: 120} );
githubWatcher.on( 'new article', function( article ) {
    var pubDate = Date.parse( article.pubDate )
    console.log( 'lastPuDate:' + lastGithubPubDate );
    console.log( 'pubDate:' + pubDate );
    if ( !lastGithubPubDate || ( pubDate > lastGithubPubDate ) ) {
	lastGithubPubDate = pubDate;    var message = '[GITHUB] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
	console.log( '[MSG]' + message );
	ircClient.say( '#kiwix', message );
    }
});
githubWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR] ' + error );
    }
});
githubWatcher.on( 'error', function( error ) {
    console.error( '[ERROR] ' + error );
});

/* ITUNES */
var kiwixItunesWatcher = new rssWatcher( kiwixItunesFeed );
kiwixItunesWatcher.set( {feed: kiwixItunesFeed, interval: 120} );
kiwixItunesWatcher.on( 'new article', function( article ) {
    var message = '[ITUNES] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
kiwixItunesWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR] ' + error );
    }
});
kiwixItunesWatcher.on( 'error', function( error ) {
    console.error( '[ERROR] ' + error );
});

/* KIWIX.ORG */
var kiwixWikiWatcher = new rssWatcher( kiwixWikiFeed );
kiwixWikiWatcher.set( {feed: kiwixWikiFeed, interval: 120} );
kiwixWikiWatcher.on( 'new article', function( article ) {
    var message = '[WIKI] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
kiwixWikiWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR] ' + error );
    }
});
kiwixWikiWatcher.on( 'error', function( error ) {
    console.error( '[ERROR] ' + error );
});

/* OPENZIM.ORG */
var openzimWikiWatcher = new rssWatcher( openzimWikiFeed );
openzimWikiWatcher.set( {feed: openzimWikiFeed, interval: 120} );
openzimWikiWatcher.on( 'new article', function( article ) {
    var message = '[OPENZIM WIKI] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
openzimWikiWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR] ' + error );
    }
});
openzimWikiWatcher.on( 'error', function( error ) {
    console.error( '[ERROR] ' + error );
});

/* OPENZIM GIT GITHUB */
var openzimGitWatcher = new rssWatcher( openzimGitFeed );
openzimGitWatcher.set( {feed: openzimGitFeed, interval: 120} );
openzimGitWatcher.on( 'new article', function( article ) {
    var message = '[OPENZIM GIT] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
openzimGitWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR] ' + error );
    }
});
openzimGitWatcher.on( 'error', function( error ) {
    console.error( '[ERROR] ' + error );
});

/* SOURCEFORGE */
var lastSourceforgePubDate;
var sourceforgeWatcher = new rssWatcher( sourceforgeFeed );
sourceforgeWatcher.set( {feed: sourceforgeFeed, interval: 120} );
sourceforgeWatcher.on( 'new article', function( article ) {
    var pubDate = Date.parse( article.pubDate )
    console.log( 'lastPuDate:' + lastSourceforgePubDate );
    console.log( 'pubDate:' + pubDate );
    if ( !lastSourceforgePubDate || ( pubDate > lastSourceforgePubDate ) ) {
	lastSourceforgePubDate = pubDate;
	var message = '[SOURCEFORGE] ' + html2txt( article.summary ) +  ' -- ' + article.link + ' --';
	console.log( '[MSG]' + message );
	ircClient.say( '#kiwix', message );
    }
});
sourceforgeWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR] ' + error );
    }
});
sourceforgeWatcher.on( 'error', function( error ) {
    console.error( '[ERROR] ' + error );
});

/* TWITTER */
setInterval ( function() {
    client.get('statuses/user_timeline', {screen_name: 'KiwixOffline', count: 1}, function( error, tweets, response ) {
	if ( error ) {
	    console.error( '[ERROR] ' + error.essage );
	} else if ( !error && tweets[0] && lastTwitterId != tweets[0].id_str ) {
	    lastTwitterId = tweets[0].id_str;
	    var message = '[MICROBLOG] ' + tweets[0].text + ' -- https://twitter.com/KiwixOffline/status/' + tweets[0].id_str + ' --';
	    console.log( '[MICROBLOG]' + message );
	    ircClient.say( '#kiwix', message );
	}
    })
}, 60000 );

/* IRC ERROR HANDLING */
ircClient.addListener( 'error', function( error ) {
    console.log( '[ERROR] ' + error );
    lastTwitterId = undefined;
    setTimeout( connectIrc, 300000 );
});