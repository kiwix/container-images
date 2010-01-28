package MediaWiki::Install;

use strict;
use warnings;
use Data::Dumper;
use LWP::UserAgent;

my $logger;
my $site;
my $path="";
my $code;
my $directory;
my $languageCode;
my $sysopUser;
my $sysopPassword;
my $dbUser;
my $dbPassword;
my @confIncludes;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub install {
    my $self = shift;

    # install url
    my $installUrl = "http://".$self->site()."/".$self->path()."/config/index.php";

    # Create a user agent object
    my $ua = LWP::UserAgent->new;
    $ua->agent("Kiwix");
    
    # Create a request
    my $req = HTTP::Request->new(POST => $installUrl);
    $req->content_type('application/x-www-form-urlencoded');
    
    # set up content
    my $content = '';
    $content .= getParamString('Sitename', $self->code());
    $content .= getParamString('EmergencyContact', 'kelson@kiwix.org');
    $content .= getParamString('LanguageCode', $self->languageCode());
    $content .= getParamString('License', 'none');
    $content .= getParamString('SysopName', $self->sysopUser());
    $content .= getParamString('SysopPass', $self->sysopPassword());
    $content .= getParamString('SysopPass2', $self->sysopPassword());
    $content .= getParamString('Shm', 'memcached');
    $content .= getParamString('MCServers', 'localhost:11211');
    $content .= getParamString('Email', 'email_enabled');
    $content .= getParamString('Emailuser', 'emailuser_enabled');
    $content .= getParamString('Enotif', 'enotif_allpages');
    $content .= getParamString('Eauthent', 'eauthent_enabled');
    $content .= getParamString('DBtype', 'mysql');
    $content .= getParamString('DBserver', 'localhost');
    $content .= getParamString('DBname', 'mirror_'.$self->code());
    $content .= getParamString('DBuser', $self->dbUser());
    $content .= getParamString('DBpassword', $self->dbPassword());
    $content .= getParamString('DBpassword2', $self->dbPassword());
    $content .= getParamString('useroot', '1');
    $content .= getParamString('RootUser', $self->dbUser());
    $content .= getParamString('RootPW', $self->dbPassword());
    $content .= getParamString('DBprefix', '');
    $content .= getParamString('DBengine', 'InnoDB');
    $content .= getParamString('DBschema', 'mysql4');
    
    $req->content($content);
    
    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    my @errors = ($res->content =~ /<span class='error'>(.+)<\/span>/ );

    # Check the outcome of the response
    if ($res->is_success && !@errors) {
	$self->log("info", "Mediawiki mirror '".$self->code()."' successfuly installed.");
    }
    else {
	$self->log("error", "Mediawiki mirror '".$self->code()."' failed to install.");
	if (scalar(@errors)) {
	    foreach my $error (@errors) {
		$self->log("error", $error);
	    }
	} else {
	    $self->log("error", "Unable to connect to ".$self->site().".");
	}
	return;
    }

    # move config file
    rename($directory."/config/LocalSettings.php", $directory."/LocalSettings.php");

    # add the conf includes
    my $confIncludeString="";
    foreach my $confInclude ($self->confIncludes()) {
	$confIncludeString .= "require_once('".$confInclude."');\n";
    }
    $confIncludeString .= "?>\n" ;
    my $conf = "";
    my $localSettingsFile = "$directory/LocalSettings.php";
    open FILE, $localSettingsFile or die $!." - unable to open ".$localSettingsFile; 
    while (my $line = <FILE>) {
	$conf .= $line;
    }
    close(FILE); 

    $conf =~ s/\?\>//mg ;
    $conf .= $confIncludeString;
    open FILE, ">$directory/LocalSettings.php" or die $!; 
    print FILE $conf; 
    close(FILE); 

    # copy the Kiwix skins
    my $cmd = "cp ../data/skins/*.php ".$directory."/skins/";
    `$cmd`;

    # copy and modify Parser.php
    $cmd = "cp $directory/includes/parser/Parser.php $directory/skins/ParserOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/class Parser/class ParserOriginal/' $directory/skins/ParserOriginal.php";
    `$cmd`;

    # copy and modify ImageGallery.php
    $cmd = "cp $directory/includes/ImageGallery.php $directory/skins/ImageGalleryOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/class ImageGallery/class ImageGalleryOriginal/' $directory/skins/ImageGalleryOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/private /protected /' $directory/skins/ImageGalleryOriginal.php";
    `$cmd`;

    # copy and modify title.php
    $cmd = "cp $directory/includes/Title.php $directory/skins/TitleOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/class Title/class TitleOriginal/' $directory/skins/TitleOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/private /protected /' $directory/skins/TitleOriginal.php";
    `$cmd`;

    # compile textvc
    $cmd = "cd $directory/math ; make clean all";
    print $cmd."\n";
    `$cmd`;

    # Set link color to 'black' in the timeline extension
    if ( -f $directory.'/extensions/timeline/EasyTimeline.pl') {
	$cmd = 'sed -i -e \'s/\$LinkColor[ |]=.*$/\$LinkColor = "black";/\' ' . $directory . '/extensions/timeline/EasyTimeline.pl';
	`$cmd`;
    }

    # Make the link for the 'local directory
    $cmd = 'ln -s /var/www/mirror/commons/images/ '.$directory.'/images/shared';
    `$cmd`;

    # Make the link for the 'local' directory
    $cmd = 'ln -s '.$directory.'/images/ '.$directory.'/images/local';
    `$cmd`;

    # todo: check if all extern tools are there
}


sub getParamString {
    my $name = shift;
    my $value = shift;
    return $name."=".$value."&";
}

sub site {
    my $self = shift;
    if (@_) { $site = shift }
    return $site;
}

sub path {
    my $self = shift;
    if (@_) { $path = shift }
    return $path;
}

sub code {
    my $self = shift;
    if (@_) { $code = shift }
    return $code;
}

sub directory {
    my $self = shift;
    if (@_) { $directory = shift }
    return $directory;
}

sub languageCode {
    my $self = shift;
    if (@_) { $languageCode = shift }
    return $languageCode;
}

sub sysopUser {
    my $self = shift;
    if (@_) { $sysopUser = shift }
    return $sysopUser;
}

sub sysopPassword {
    my $self = shift;
    if (@_) { $sysopPassword = shift }
    return $sysopPassword;
}

sub dbUser {
    my $self = shift;
    if (@_) { $dbUser = shift }
    return $dbUser;
}

sub dbPassword {
    my $self = shift;
    if (@_) { $dbPassword = shift }
    return $dbPassword;
}

sub confIncludes {
    my $self = shift;
    if (@_) { @confIncludes = @_ }
    return @confIncludes;
}

sub logger {
    my $self = shift;
    if (@_) { $logger = shift }
    return $logger;
}

sub log {
    my $self = shift;
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
