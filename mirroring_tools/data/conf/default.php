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

# permissions
$wgGroupPermissions['*']['createaccount']    = true;
$wgGroupPermissions['*']['edit']             = true;
$wgGroupPermissions['*']['createpage']       = true;
$wgGroupPermissions['*']['createtalk']       = true;
$wgGroupPermissions['*']['writeapi']         = true;
$wgGroupPermissions['*']['upload']           = true;
$wgGroupPermissions['*']['reupload']         = true;
$wgGroupPermissions['*']['purge']            = true; 
$wgGroupPermissions['*']['reupload-shared']  = true;
$wgGroupPermissions['*']['upload_by_url']    = true;

# write API
$wgEnableWriteAPI = true; 

# file upload
$wgEnableUploads = true;
$wgAllowCopyUploads = true;

# memory
$wgMaxShellMemory = 1024000;
$wgMaxShellFileSize = 1024000;
$wgMimeDetectorCommand= 'file -bi ';
$wgVerifyMimeType = true;
$wgSVGConverter = 'rsvg';
$wgImageMagickConvertCommand = 'convert';

# logging
$wgDisableCounters = true;

# interwikis
$wgHideInterlanguageLinks = true;

# ajax
$wgUseAjax = true;

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

# Timeline
$wgTimelineSettings->perlCommand = "/usr/bin/perl";

# sub pages
$wgNamespacesWithSubpages[100] = true;

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

?>
