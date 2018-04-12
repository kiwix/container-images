#!/usr/bin/php
<?php
require_once("../libs/PiwikTracker/PiwikTracker.php");

/* Classes */
class LogParser
{
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
      $formatedLog['status'] = $logs[10];
      $formatedLog['bytes'] = $logs[11];
      $formatedLog['referer'] = str_replace('"', "", $logs[12]);
      $formatedLog['agent'] = $logs[13];
      $formatedLog['unixtime'] = strtotime($formatedLog["date"].":".$formatedLog["time"]." ".$formatedLog["timezone"]);
      $formatedLog['utcdatetime'] = date("Y-m-d H:i:s", $formatedLog['unixtime']);

      if (eregi('.*(bot|index|spider|crawl|wget|slurp|Mediapartners-Google|W3\ Total\ Cache|qwant|cis455mapreduce).*', $formatedLog['agent'])) {
         echo "Bot/crawler detected: ".$formatedLog['agent']."\n";
      	 return false;
      } else {
      	 return $formatedLog;
      }
    } else {
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

/* Check if there is already a request stored for that (avoid duplicates) */
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
function shouldBeStored($path, $filter, $filterOut) {
  if (strpos($path, "favicon.") != false 
      || strpos($path, "icons/") != false
      || strpos($path, "robots.txt") != false) {
    return false;
  }

  if ($filter) {
    if (!preg_match("/$filter/", $path)) {
      return false;
    }
  }

  if ($filterOut) {
    if (preg_match("/$filterOut/", $path)) {
      return false;
    }
  }

  return true;
}

/* Save in Piwik */
function saveInPiwik($logHash) {
  global $idSite, $webUrl, $piwikUrl, $tokenAuth, $skipFailingRequests;
  $t = new PiwikTracker($idSite, $piwikUrl);
  $t->setUserAgent(substr($logHash["agent"], 0, 100));
  $t->setTokenAuth($tokenAuth);
  $t->setIp($logHash["ip"]);
  $t->setForceVisitDateTime($logHash["utcdatetime"]);
  $t->setUrlReferrer($logHash["referer"]);
  $t->setUrl($webUrl.$logHash["path"]);
  $HTTPResult = false;
  $HTTPFailCount = 0;
  do {
    echo $logHash["ip"]." ".$logHash["status"]." ".$logHash["utcdatetime"]." ".$logHash["path"]." (".$logHash["agent"].")... ";
    $HTTPResult = $t->doTrackPageView(basename($logHash["path"]));

    if (!$HTTPResult) {
      $HTTPFailCount++;
      echo "FAIL\n";
      echo "Unable to save (via HTTP) last log entry for the $HTTPFailCount time.\n";
      if (!$skipFailingRequests) {
        echo "Retrying in a few seconds...\n";
        sleep($HTTPFailCount);
      }
    } else {
      echo "SUCCESS\n";
    }
  } while (!$HTTPResult && !$skipFailingRequests); 
}

/* Get last log insertion in Piwik to avoid duplicates */
function getLastPiwikInsertionTime() {
  global $piwikUrl, $idSite, $tokenAuth;
  $apiUrl = $piwikUrl."/index.php?module=API&method=Live.getLastVisitsDetails&idSite=".$idSite."&period=year&format=xml&token_auth=".$tokenAuth."&filter_limit=1&format=xml&date=today";
  $xml = file_get_contents($apiUrl);
  if (preg_match('#<lastActionDateTime(?:\s+[^>]+)?>(.*?)</lastActionDateTime>#s', $xml, $matches)) {
    return strtotime($matches[1]);
  } else {
    echo $apiUrl."\n";
    echo($xml."\n");
  }
  return 0;
}

/* Usage() */
function usage() {
  echo "fillPiwikWithWebServerLogs.php --idSite=1 --webUrl=http://download.kiwix.org --piwikUrl=http://stats.kiwix.org/piwik/piwik/ --tokenAuth=b9a7f2d030888a9a0b5d31a02da56ca2 [--filter=\"\/A\/\"] [--followLog] [--countSimilarRequests] download.access.log*\n";
  exit(1);
}

/* Get options */
$options = getopt("", Array("idSite:", "webUrl:", "filter:", "filterOut:", "piwikUrl:", "tokenAuth:", "followLog", "countSimilarRequests", "skipFailingRequests"));

/* Check options */
$idSite = "";
$webUrl = "";
$piwikUrl = "";
$tokenAuth = "";
$filter = "";
$filterOut = "";
$followLog = false;
$countSimilarRequests = false;
$skipFailingRequests = false;
if (empty($options["idSite"]) || empty($options["webUrl"]) || empty($options["piwikUrl"]) || empty($options["tokenAuth"])) {
  usage();
} else {
  global $idSite, $webUrl, $filter, $filterOut, $piwikUrl, $tokenAuth, $followLog, $countSimilarRequests, $skipFailingRequests;
  $idSite = $options["idSite"];
  $webUrl = $options["webUrl"];
  $piwikUrl = $options["piwikUrl"];
  $tokenAuth = $options["tokenAuth"];
  $filter = array_key_exists("filter", $options) ? $options["filter"] : '';
  $filterOut = array_key_exists("filterOut", $options) ? $options["filterOut"] : '';
  $followLog = array_key_exists("followLog", $options);
  $countSimilarRequests = array_key_exists("countSimilarRequests", $options);
  $skipFailingRequests = array_key_exists("skipFailingRequests", $options);
}
$duplicateHash = Array();
$duplicateDelay = $countSimilarRequests ? 0 : 60 * 60 * 24 * 31;

/* Get files to parse */
echo "Parse command line arguments...\n";
$logFiles = Array();
foreach (array_slice($argv, 1, sizeof($argv)-1) as $arg) {
  if (!preg_match("/^--.*$/i", $arg)) {
    array_push($logFiles, $arg);
  }
}

/* Check if file don't share the same filetime */
echo "Check if we can trust log files timestamps...\n";
$duplicateLogFiles = Array();
foreach ($logFiles as $logFile) {
  $logFileTime = filemtime($logFile);
  if (array_key_exists($logFileTime, $duplicateLogFiles)) {
    array_push($duplicateLogFiles[$logFileTime], $logFile);
  } else {
    $duplicateLogFiles[$logFileTime] = array( $logFile );
  }
}

/* If many files have the same filetime, then try to change it based
 on the last log time */
if (count($duplicateLogFiles) != count($logFiles)) {
  echo "Many files have the same filetime, should I try to reset them based on the last log time (yes/no)?";
  $handle = fopen ("php://stdin","r");
  $line = fgets($handle);
  if(trim($line) != 'yes'){
    echo "Aborting...\n";
    exit(1);
  } else {
    foreach ($duplicateLogFiles as $logFiles) {
      if (count($logFiles) > 1) {
	foreach ($logFiles as $logFile) {
	  $parser = new LogParser();
	  $newFileTime;
	  if ($parser->openLogFile($logFile)) {
	    while ($line = $parser->getLine()) {
	      $logHash = $parser->formatLine($line);
	      if ($logHash["unixtime"]) {
		$newFileTime = $logHash["unixtime"];
	      }
	    }
	  }
	  $parser->closeLogFile();
	  touch($logFile, $newFileTime, $newFileTime);
	  echo "Set new filetime $newFileTime to '$logFile'\n";
	}
      }
    }
  }
}

/* Set Piwik internal timezone */
date_default_timezone_set("UTC");

/* Get last insertion date */
echo "Get last insertion time...\n";
$lastPiwikInsertionTime = getLastPiwikInsertionTime();
if (!$lastPiwikInsertionTime) {
  echo "Script was unable to unable to retrieve the date of last log insertion. Is that normal? Do you want to continue (yes/no)?";
  $handle = fopen ("php://stdin","r");
  $line = fgets($handle);
  if(trim($line) != 'yes') {
    exit(1);
  }
}

/* Sort files and remove the too old ones */
echo "Sort log files and remove old ones from the list...\n";
$sortedLogFiles = Array();
foreach ($logFiles as $logFile) {
  global $duplicateDelay;
  $logFileTime = filemtime($logFile);

  /* Check if the logFile is not too old, we are only interested in
   logs which are 30 days before the lastPiwikiInsertionTime */
  if ($lastPiwikInsertionTime - $logFileTime > $duplicateDelay) {
    echo "File '$logFile' is too old, it will be skiped.\n";
  } else {
    if (array_key_exists($logFileTime, $sortedLogFiles)) {
      echo "File '$logFile' has the same filetime than '$sortedLogFiles[$logFileTime]'. Unable to continue.\n";
      exit(1);
    } else {
      $sortedLogFiles[$logFileTime] = $logFile;
    }
  }
}
ksort($sortedLogFiles);

/* Read files */
echo "Read log files...\n";
foreach ($sortedLogFiles as $logFile) {
  global $filter;
  global $filterOut;
  $parser = new LogParser();

  if ($parser->openLogFile($logFile)) {
    echo "File '$logFile' opened.\n";
    while ($line = $parser->getLine()) {
      $logHash = $parser->formatLine($line);
      if (shouldBeStored($logHash["path"], $filter, $filterOut) && 
	  $logHash["status"] != '404' &&
	  $logHash["status"] != '301' &&
	  $logHash["method"] != 'HEAD' &&
	  ($countSimilarRequests || !isAlreadyStored($logHash)) && 
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