#!/usr/bin/php
<?php
require_once("../libs/PiwikTracker/PiwikTracker.php");

/* Classes */
class LogParser
{
  var $badRows;
  var $fp;
  var $fileName;

  function formatLogLine($line) {
    preg_match("/^(\S+) (\S+) (\S+) \[([^:]+):(\d+:\d+:\d+) ([^\]]+)\] \"(\S+) (.*?) (\S+)\" (\S+) (\S+) (\".*?\") (\".*?\")$/", $line, $matches);
    return $matches;
  }

  function formatLine($line) {
    $logs = $this->formatLogLine($line);

    if (isset($logs[0])) {
      $formatedLog = array();
      $formatedLog['ip'] = $logs[1];
      $formatedLog['identity'] = $logs[2];
      $formatedLog['user'] = $logs[2];
      $formatedLog['date'] = $logs[4];
      $formatedLog['time'] = $logs[5];
      $formatedLog['timezone'] = $logs[6];
      $formatedLog['method'] = $logs[7];
      $formatedLog['path'] = $logs[8];
      $formatedLog['protocol'] = $logs[9];
#      $formatedLog['status'] = $logs[10] == "302" || $logs[10] == "301" ? "200" : $logs[10];
      $formatedLog['status'] = $logs[10];
      $formatedLog['bytes'] = $logs[11];
      $formatedLog['referer'] = str_replace('"', "", $logs[12]);
      $formatedLog['agent'] = $logs[13];
      $formatedLog['unixtime'] = strtotime($formatedLog["date"].":".$formatedLog["time"]." ".$formatedLog["timezone"]);
      $formatedLog['utcdatetime'] = date("Y-m-d H:i:s", $formatedLog['unixtime']);
      return $formatedLog;
    } else {
      $this->badRows++;
      return false;
    }
  }

  function openLogFile($fileName) {
    if (preg_match("/^.*\.gz$/i", $fileName)) {
      $this->fp = gzopen($fileName, 'r');
    } else {
      $this->fp = fopen($fileName, 'r');
    }
    if (!$this->fp) {
      return false;
    }
    
    $this->fileName = $fileName;
    return true;
  }

  function closeLogFile() {
    fclose($this->fp);
    unset($this->fileName);
    unset($this->fp);
  }

  function getLine() {
    global $followLog;

    if (preg_match("/^.*\.log$/i", $this->fileName) && $followLog) {
      $size = 0;
      $fileName = $this->fileName;
      while (true) {

	// If file already open try to read the content
	if (isset($this->fp)) {
	  if (($buffer = fgets($this->fp, 4096)) !== false) {
	    return $buffer;
	  }
	  $size = filesize($this->fileName);
	  $this->closeLogFile();
	}
	
	// Try to see if new content is there
	clearstatcache();
	$currentSize = filesize($fileName);
	if ($size == $currentSize) {
	  sleep(1);
	  continue;
        }

	// New content there, reopen the file and seek
	$this->openLogFile($fileName);
	fseek($this->fp, $size);
      }
    } else {
      if (($buffer = fgets($this->fp, 4096)) !== false) {
	return $buffer;
      }
      return false;
    }
  }
} 

/* Usage() */
function usage() {
  echo "fillPiwikWithWebServerLogs.php --idSite=1 --webUrl=http://download.kiwix.org --piwikUrl=http://stats.kiwix.org/piwik/piwik/ --tokenAuth=b9a7f2d030888a9a0b5d31a02da56ca2 [--followLog] download.access.log*\n";
  exit(1);
}

/* Check if there is already a request stored for that (avoid duplicates) */
$duplicateHash = Array();
$duplicateDelay = 60 * 60 * 24 * 31;
function isAlreadyStored($logHash) {
  global $duplicateHash, $duplicateDelay;
  $key = $logHash["ip"].$logHash["path"];
  if (!empty($duplicateHash[$key]) && $duplicateHash[$key] > $logHash["unixtime"] - $duplicateDelay) {
    return true;
  }

  $duplicateHash[$key] = $logHash["unixtime"];
  return false;
}

/* Remove directories and icon requests */
function shouldBeStored($path) {
  if (!preg_match("/^.*\.\w{3,}$/i", $path)
      || preg_match("/^.*\.md5$/i", $path)
      || preg_match("/^.*\.mirrorlist$/i", $path)
      || strpos($path, "favicon") != false 
      || strpos($path, "icons") != false
      || strpos($path, "robots.txt") != false) {
    return false;
  }
  return true;
}

/* Save in Piwik */
function saveInPiwik($logHash) {
  echo $logHash["ip"]." ".$logHash["status"]." ".$logHash["utcdatetime"]." ".$logHash["path"]."\n";
  global $idSite, $webUrl, $piwikUrl, $tokenAuth;
  $t = new PiwikTracker($idSite, $piwikUrl);
  $t->setUserAgent($logHash["agent"]);
  $t->setTokenAuth($tokenAuth);
  $t->setIp($logHash["ip"]);
  $t->setForceVisitDateTime($logHash["utcdatetime"]);
  $t->setUrlReferrer($logHash["referer"]);
  $t->setUrl($webUrl.$logHash["path"]);
  $t->doTrackPageView(basename($logHash["path"]));
}

/* Get last log insertion in Piwik to avoid duplicates */
function getLastPiwikInsertionTime() {
  global $piwikUrl, $idSite, $tokenAuth;
  $apiUrl = $piwikUrl."/index.php?module=API&method=Live.getLastVisitsDetails&idSite=".$idSite."&period=year&format=xml&token_auth=".$tokenAuth."&filter_limit=1&format=xml&date=today";
  $xml = file_get_contents($apiUrl);
  if (preg_match('#<lastActionDateTime(?:\s+[^>]+)?>(.*?)</lastActionDateTime>#s', $xml, $matches)) {
    return strtotime($matches[1]);
  }
  return 0;
}

/* Get options */
$options = getopt("", Array("idSite:", "webUrl:", "piwikUrl:", "tokenAuth:", "followLog"));

/* Check options */
$idSite = "";
$webUrl = "";
$piwikUrl = "";
$tokenAuth = "";
$followLog = false;
if (empty($options["idSite"]) || empty($options["webUrl"]) || empty($options["piwikUrl"]) || empty($options["tokenAuth"])) {
  usage();
} else {
  global $idSite, $webUrl, $piwikUrl, $tokenAuth, $followLog;
  $idSite = $options["idSite"];
  $webUrl = $options["webUrl"];
  $piwikUrl = $options["piwikUrl"];
  $tokenAuth = $options["tokenAuth"];
  $followLog = array_key_exists("followLog", $options);
}

/* Get files to parse */
$logFiles = Array();
foreach (array_slice($argv, 1, sizeof($argv)-1) as $arg) {
  if (!preg_match("/^--.*$/i", $arg)) {
    array_push($logFiles, $arg);
  }
}

/* Set Piwik internal timezone */
date_default_timezone_set("UTC");

/* Get last insertion date */
$lastPiwikInsertionTime = getLastPiwikInsertionTime();

/* Sort files and remove the too old ones */
$sortedLogFiles = Array();
foreach ($logFiles as $logFile) {
  global $duplicateDelay;
  $logFileTime = filemtime($logFile);

  /* Check if the logFile is not too old, we are only interested in
   logs which are 30 days before the lastPiwikiInsertionTime */
  if ($lastPiwikInsertionTime - $logFileTime > $duplicateDelay) {
    echo "File '$logFile' is too old, it will be skiped.\n";
  } else {
    $sortedLogFiles[filemtime($logFile)] = $logFile;
  }
}
ksort($sortedLogFiles);

/* Read files */
foreach ($sortedLogFiles as $logFile) {
  $parser = new LogParser();

  if ($parser->openLogFile($logFile)) {
    echo "File '$logFile' opened.\n";
    while ($line = $parser->getLine()) {
      $logHash = $parser->formatLine($line);
      if (shouldBeStored($logHash["path"]) && 
	  $logHash["status"] != '404' &&
	  $logHash["status"] != '301' &&
	  !isAlreadyStored($logHash) && 
	  $logHash["unixtime"] > $lastPiwikInsertionTime) {
	saveInPiwik($logHash);
      }
    }
    $parser->closeLogFile();
  } else {
    echo "File '$logFile' is not readable.\n";
    exit(1);
  }
}

?>