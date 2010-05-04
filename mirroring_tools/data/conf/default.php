<?php

// Add specific path
function add_include_path ($path)
{
    foreach (func_get_args() AS $path)
    {
        if (!file_exists($path) OR (file_exists($path) && filetype($path) !== 'dir'))
        {
            trigger_error("Include path '{$path}' not exists", E_USER_WARNING);
            continue;
        }
       
        $paths = explode(PATH_SEPARATOR, get_include_path());
       
        if (array_search($path, $paths) === false)
            array_push($paths, $path);
       
        set_include_path(implode(PATH_SEPARATOR, $paths));
    }
}

add_include_path("/usr/share");

# images 
$wgFileExtensions = array( 'png', 'gif', 'jpg', 'jpeg', 'mp3', 'ogg', 'pdf', 'svg' );
$wgStrictFileExtensions = false;

# image shared dir
$wgUseSharedUploads = true;
$wgSharedUploadPath = "http://commons.mirror.kiwix.org/images";
$wgFetchCommonsDescriptions = false;
$wgSharedUploadDirectory = "/var/www/mirror/commons/images";
$wgSharedUploadDBname = "mirror_commons";
$wgCacheSharedUploads = false;

# permissions
$wgGroupPermissions['*']['createaccount']    = true;
$wgGroupPermissions['*']['edit']             = false; // otherwise 'editsection' present in the page
$wgGroupPermissions['*']['createpage']       = false;
$wgGroupPermissions['*']['createtalk']       = false;
$wgGroupPermissions['*']['writeapi']         = false;
$wgGroupPermissions['*']['upload']           = false;
$wgGroupPermissions['*']['reupload']         = false;
$wgGroupPermissions['*']['purge']            = false; 
$wgGroupPermissions['*']['reupload-shared']  = false;
$wgGroupPermissions['*']['upload_by_url']    = false;

# write API
$wgEnableWriteAPI = true; 

# file upload
$wgEnableUploads = true;
$wgAllowCopyUploads = true;

# memory
$wgMaxShellMemory = 502400;
$wgMaxShellTime = 180;
$wgMaxShellFileSize = 202400;
$wgMimeDetectorCommand= 'file -bi ';
$wgVerifyMimeType = false;

# image conversion
$wgSVGConverter = 'rsvg';

# problem is that libgd ist not able to deal with animated gif
# http://bugs.libgd.org/?do=details&task_id=57&histring=animated%20gif
$wgUseImageMagick = true;

# remove the syndication feeds
$wgFeed = false;

# logging
$wgDisableCounters = true;

# interwikis
$wgHideInterlanguageLinks = true;

# ajax
$wgUseAjax = true;

# timeout
$wgSyncHTTPTimeout = 1200;
$wgAsyncHTTPTimeout = 1200;

# jobs
$wgJobRunRate = 0;

# throttling
$wgPasswordAttemptThrottle = array( 'count' => 424242424242, 'seconds' => 1 );

# Indexing policy
$wgExemptFromUserRobotsControl = Array();
$wgDefaultRobotPolicy = 'index,follow';
$wgNamespaceRobotPolicies = array( 0 => 'index,follow' );

# cache policy
$wgMainCacheType = CACHE_MEMCACHED;
$wgParserCacheType = CACHE_MEMCACHED;
$wgMessageCacheType = CACHE_MEMCACHED;

# HTML tidy
$wgUseTidy = true;
$wgAlwaysUseTidy = true;
$wgTidyBin = 'tidy';
$wgTidyConf = $IP.'/includes/tidy.conf';
$wgTidyOpts = '';
$wgTidyInternal = extension_loaded( 'tidy' );

# Latex
$wgUseTeX = true;
$wgTexvc = $IP.'/math/texvc';

# Timeline
$wgTimelineSettings->perlCommand = "/usr/bin/perl";

# Additional namespace
define("NS_WIKIPEDIA", 424);
$wgExtraNamespaces[NS_WIKIPEDIA] = "Wikipedia"; 
$wgNamespaceProtection[NS_WIKIPEDIA] = array( 'editwikipedia' ); #permission "editfoo" required to edit the foo namespace
$wgNamespacesWithSubpages[NS_WIKIPEDIA] = true;                  #subpages enabled for the foo namespace
$wgGroupPermissions['*']['editwikipedia'] = true; 

define("NS_CONTRIBUTORS", 411);
$wgExtraNamespaces[NS_CONTRIBUTORS] = "Contributors"; 
$wgNamespaceProtection[NS_CONTRIBUTORS] = array( 'editcontributors' ); #permission "editfoo" required to edit the foo namespace
$wgNamespacesWithSubpages[NS_CONTRIBUTORS] = true;                  #subpages enabled for the foo namespace
$wgGroupPermissions['*']['editcontributors'] = true; 

# jumpto link
$wgDefaultUserOptions["showjumplinks"] = 0;

# edit section
$wgDefaultUserOptions ['editsection'] = 0;

# exception handling
$wgShowExceptionDetails = true; 

# search engin
$wgDisableTextSearch = true;
$wgDisableSearchContext = true;

# rewriting of some classes
global $wgAutoloadLocalClasses;
$wgAutoloadLocalClasses['ImageGallery'] = 'skins/ImageGallery.php';
$wgAutoloadLocalClasses['Parser'] = 'skins/Parser.php';
$wgAutoloadLocalClasses['Title'] = 'skins/Title.php';

# ploticus
putenv("GDFONTPATH=/usr/share/fonts/truetype/freefont"); 
?>
