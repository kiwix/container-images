#!/bin/sh
":" //# -*- mode: js -*-; exec /usr/bin/env node --max-old-space-size=1900 --stack-size=4096 "$0" "$@"

"use strict";

/* INCLUDES */
var irc = require( 'irc' );
var twitterRss = require('twitter-rss-noauth')
var rssParser = new(require('rss-parser'));
var rssWatcher = require( 'rss-watcher' );
var htmlToText = require( 'html-to-text' );
var yargs = require( 'yargs' );

/* ARGUMENTS */
var argv = yargs.usage( 'Feed #kiwix Freenode IRC channels in real-time with Sourceforge, twitter, wikis activities: $0' )
    .require( [ 'kiwixGithubToken', 'openzimGithubToken' ] )
    .argv;

/* CONSTANTS */
var kiwixGithubFeed = 'https://github.com/organizations/kiwix/kelson42.private.atom?token=' + argv.kiwixGithubToken;
var kiwixWikiFeed = 'http://wiki.kiwix.org/w/api.php?hidebots=1&days=7&limit=50&translations=filter&action=feedrecentchanges&feedformat=rss';
var kiwixItunesFeed = 'https://itunes.apple.com/us/rss/customerreviews/id=997079563/sortBy=mostRecent/xml';
var kiwixSourceforgeFeed = 'https://sourceforge.net/p/kiwix/activity/feed.rss';

var openzimGithubFeed = 'https://github.com/organizations/openzim/kelson42.private.atom?token=' + argv.openzimGithubToken;
var openzimWikiFeed = 'http://www.openzim.org/w/api.php?hidebots=1&days=7&limit=50&translations=filter&action=feedrecentchanges&feedformat=rss';

var ideascubeFramagitFeed = 'https://framagit.org/ideascube.atom';

/* FUNCTIONS */
function connectIrc() {
    var ircClient = new irc.Client( 'irc.freenode.net', 'WatcherBot', {
	channels: [ '#kiwix' ],
    });
    return ircClient;
}

function html2txt( html ) {
    return htmlToText.fromString( html ).replace( new RegExp( /\[[^\[]*\]/ ), '' ).replace( new RegExp( /[ ]+/ ), ' ' );
}

/* IRC */
var ircClient = connectIrc();

/* TWITTER */
var lastTwitterId = "";
setInterval ( function() {
    twitterRss('kiwixoffline', function (err, feed) {
	if ( err ) {
            console.error( '[ERROR KIWIX MICROBLOG] ' + err);
	} else {
	    (async () => {
		let parsedFeed = await rssParser.parseString(feed);
		parsedFeed.items.forEach(item => {
		    if ( lastTwitterId.localeCompare(item.isoDate) < 0 ) {
			lastTwitterId = item.isoDate;
			var message = '[KIWIX MICROBLOG] ' + item.title + ' -- ' + item.link + ' --';
			console.log( '[KIWIX MICROBLOG]' + message );
			ircClient.say( '#kiwix', message );
		    }
		});
	    })();
	}
    })
}, 60000 );

/* KIWIX GITHUB */
var lastKiwixGithubPubDate;
var kiwixGithubWatcher = new rssWatcher( kiwixGithubFeed );
kiwixGithubWatcher.set( {feed: kiwixGithubFeed, interval: 120} );
kiwixGithubWatcher.on( 'new article', function( article ) {
    var kiwixGithubPubDate = Date.parse( article.pubDate )
    console.log( 'lastPuDate:' + lastKiwixGithubPubDate );
    console.log( 'pubDate:' + kiwixGithubPubDate );
    if ( !lastKiwixGithubPubDate || ( kiwixGithubPubDate > lastKiwixGithubPubDate ) ) {
	lastKiwixGithubPubDate = kiwixGithubPubDate;
	var message = '[KIWIX GITHUB] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
	console.log( '[MSG]' + message );
	ircClient.say( '#kiwix', message );
    }
});
kiwixGithubWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR KIWIX GITHUB] ' + error );
    }
});
kiwixGithubWatcher.on( 'error', function( error ) {
    console.error( '[ERROR KIWIX GITHUB] ' + error );
});

/* KIWIX WIKI */
var kiwixWikiWatcher = new rssWatcher( kiwixWikiFeed );
kiwixWikiWatcher.set( {feed: kiwixWikiFeed, interval: 120} );
kiwixWikiWatcher.on( 'new article', function( article ) {
    var message = '[KIWIX WIKI] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
kiwixWikiWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR KIWIX WIKI] ' + error );
    }
});
kiwixWikiWatcher.on( 'error', function( error ) {
    console.error( '[ERROR KIWIX WIKI] ' + error );
});

/* KIWIX ITUNES */
var kiwixItunesWatcher = new rssWatcher( kiwixItunesFeed );
kiwixItunesWatcher.set( {feed: kiwixItunesFeed, interval: 120} );
kiwixItunesWatcher.on( 'new article', function( article ) {
    var message = '[ITUNES] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
kiwixItunesWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR KIWIX ITUNES] ' + error );
    }
});
kiwixItunesWatcher.on( 'error', function( error ) {
    console.error( '[ERROR KIWIX ITUNES] ' + error );
});

/* KIWIX SOURCEFORGE */
var lastKiwixSourceforgePubDate;
var kiwixSourceforgeWatcher = new rssWatcher( kiwixSourceforgeFeed );
kiwixSourceforgeWatcher.set( {feed: kiwixSourceforgeFeed, interval: 120} );
kiwixSourceforgeWatcher.on( 'new article', function( article ) {
    var kiwixSourceforgePubDate = Date.parse( article.pubDate )
    console.log( 'lastPuDate:' + lastKiwixSourceforgePubDate );
    console.log( 'pubDate:' + kiwixSourceforgePubDate );
    if ( !lastKiwixSourceforgePubDate || ( kiwixSourceforgePubDate > lastKiwixSourceforgePubDate ) ) {
	lastKiwixSourceforgePubDate = kiwixSourceforgePubDate;
	var message = '[KIWIX SOURCEFORGE] ' + html2txt( article.summary ) +  ' -- ' + article.link + ' --';
	console.log( '[MSG]' + message );
	ircClient.say( '#kiwix', message );
    }
});
kiwixSourceforgeWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR KIWIX SOURCEFORGE] ' + error );
    }
});
kiwixSourceforgeWatcher.on( 'error', function( error ) {
    console.error( '[ERROR KIWIX SOURCEFORGE] ' + error );
});

/* OPENZIM GITHUB */
var lastOpenzimGithubPubDate;
var openzimGithubWatcher = new rssWatcher( openzimGithubFeed );
openzimGithubWatcher.set( {feed: openzimGithubFeed, interval: 120} );
openzimGithubWatcher.on( 'new article', function( article ) {
    var openzimGithubPubDate = Date.parse( article.pubDate )
    console.log( 'lastPuDate:' + lastOpenzimGithubPubDate );
    console.log( 'pubDate:' + openzimGithubPubDate );
    if ( !lastOpenzimGithubPubDate || ( openzimGithubPubDate > lastOpenzimGithubPubDate ) ) {
	lastOpenzimGithubPubDate = openzimGithubPubDate;
	var message = '[OPENZIM GITHUB] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
	console.log( '[MSG]' + message );
	ircClient.say( '#kiwix', message );
    }
});
openzimGithubWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR OPENZIM GITHUB] ' + error );
    }
});
openzimGithubWatcher.on( 'error', function( error ) {
    console.error( '[ERROR OPENZIM GITHUB] ' + error );
});

/* OPENZIM WIKI */
var openzimWikiWatcher = new rssWatcher( openzimWikiFeed );
openzimWikiWatcher.set( {feed: openzimWikiFeed, interval: 120} );
openzimWikiWatcher.on( 'new article', function( article ) {
    var message = '[OPENZIM WIKI] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
    console.log( '[MSG]' + message );
    ircClient.say( '#kiwix', message );
});
openzimWikiWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR OPENZIM WIKI] ' + error );
    }
});
openzimWikiWatcher.on( 'error', function( error ) {
    console.error( '[ERROR OPENZIM WIKI] ' + error );
});

/* IDEASCUBE FRAMAGIT */
var lastIdeascubeFramagitPubDate;
var ideascubeFramagitWatcher = new rssWatcher( ideascubeFramagitFeed );
ideascubeFramagitWatcher.set( {feed:ideascubeFramagitFeed, interval: 120} );
ideascubeFramagitWatcher.on( 'new article', function( article ) {
    var ideascubeFramagitPubDate = Date.parse( article.pubDate )
    console.log( 'lastPuDate:' + lastIdeascubeFramagitPubDate );
    console.log( 'pubDate:' + lastIdeascubeFramagitPubDate );
    if ( !lastIdeascubeFramagitPubDate || ( ideascubeFramagitPubDate > lastIdeascubeFramagitPubDate ) ) {
	lastIdeascubeFramagitPubDate = ideascubeFramagitPubDate;
	var message = '[IDEASCUBE FRAMAGIT] ' + html2txt( article.title ) + ' by ' + html2txt( article.author ) + ' -- ' + article.link + ' --';
	console.log( '[MSG]' + message );
	ircClient.say( '#kiwix', message );
    }
});
ideascubeFramagitWatcher.run( function( error, articles ) {
    if ( error ) {
	console.error( '[ERROR IDEASCUBE FRAMAGIT] ' + error );
    }
});
ideascubeFramagitWatcher.on( 'error', function( error ) {
    console.error( '[ERROR IDEASCUBE FRAMAGIT] ' + error );
});

/* IRC ERROR HANDLING */
ircClient.addListener( 'error', function( error ) {
    console.error( '[ERROR IRC] ' + error.command );
    lastTwitterId = undefined;
    setTimeout( connectIrc, 300000 );
});
