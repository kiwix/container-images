<?php
class KiwixBaseSkin extends SkinTemplate {
	/** Using kiwix. */
	function initPage( OutputPage $out ) {
		parent::initPage( $out );
		$this->skinname  = 'KiwixBaseSkin';
		$this->stylename = 'KiwixBaseSkin';
		$this->template  = 'KiwixBaseSkin';
	}

	function setupSkinUserCss( OutputPage $out ) {
		global $wgHandheldStyle;

		parent::setupSkinUserCss( $out );

		// Append to the default screen common & print styles...
		$out->addStyle( 'monobook/main.css', 'screen' );
		if( $wgHandheldStyle ) {
			// Currently in testing... try 'chick/main.css'
			$out->addStyle( $wgHandheldStyle, 'handheld' );
		}
		$out->addStyle( 'monobook/rtl.css', 'screen', '', 'rtl' );
	}

	// responsible for avoiding the red links
	function makeBrokenLinkObj( &$nt, $text = '', $query = '', $trail = '', $prefix = '' ) {
		if ( !isset( $nt ) ) {
			return "";
		}

		// return empty string if it a template inclusion/link
		if ( $nt->getNamespace() == NS_TEMPLATE ) {
		         return "";    
		}

		if ( $nt->getNamespace() == NS_CATEGORY ) {
			# Determine if the category has any articles in it
			$dbr = wfGetDB( DB_SLAVE );
			$hasMembers = $dbr->selectField( 'categorylinks', '1', 
				array( 'cl_to' => $nt->getDBkey() ), __METHOD__ );
			if ( $hasMembers ) {
				return $this->makeKnownLinkObj( $nt, $text, $query, $trail, $prefix );
			}
		}

		if ( $text == '' ) {
			$text = $nt->getPrefixedText();
		}
		return $prefix . $text . $trail;
	}

	// reponsible to avoid media links
	function makeMediaLinkObj( $title, $text = '', $time = false ) {
	  return $text;
	}

	// responsible for removing failing pictures
	function makeImageLink2( Title $title, $file, $frameParams = array(), $handlerParams = array(), $time = false, $query = "" ) {
                if (!$file || !$file->exists()) {
                   return "";
		}

		$html = Linker::makeImageLink2($title, $file, $frameParams, $handlerParams, $time, $query);

		// remove image links, the test is a trick to avoid doing that for imagemap pictures
		$trace=debug_backtrace();
		$caller=$trace[2];

		if ($caller['class'] == 'ParserOriginal' || $caller['class'] == 'Parser' ) {
		  preg_match_all('/<a [^>]*>(.*?<img.*?)<\/a>/s', $html, $matches);
		  if (count($matches)) {
		    $html = str_replace($matches[0], $matches[1], $html);
		  }
		}

		return $html;
        }

	// remove zoomicon in thumbs
	function makeThumbLink2( Title $title, $file, $frameParams = array(), $handlerParams = array(), $time = false, $query = "" ) {
	        $html = Linker::makeThumbLink2($title, $file, $frameParams, $handlerParams, $time, $query );

		// remove zoomicon
		preg_match_all('/<div class="magnify">.*?<\/div>/s', $html, $matches);
		foreach ($matches[0] as $match) {
		  $html = str_replace($match, "", $html);
		}
		
		return $html;
	}

	// rewrite finale html output
	function outputPage( OutputPage $out )  {
		 $content = $out->mBodytext;

		 // remove links to disemb. and other (if no link inside)
		 preg_match_all('/<dd>.*?<\/dd>|<div class="dablink">.*?<\/div>/s', $content, $matches);
		 foreach ($matches[0] as $match) {
		   
		   // remove only html code without links or latex generated mathematics images
		   if (!preg_match("/.*?<a.*?/s", $match) && !preg_match("/.*?<img class=\"tex\".*?/s", $match)) {
		     $content = str_replace($match, "", $content);
		   }

		 }

		 // remove return cariage after (sub-)title
		 $content = str_replace("<p><br />", "<p>", $content);
		 
		 // remove empty paragraph
		 $content = str_replace("<p><br /></p>", "", $content);

		 // other type of useless html
		 $content = str_replace('<p><font class="metadata"><br /></font></p>', "", $content);

		 // remove empty chapter/paragraph/...

		 // <p><a name="Monotonicity" id="Monotonicity"></a></p>
		 // <h3><span class="mw-headline">Monotonicity</span></h3>
		 // <p><a name="Conservativity" id="Conservativity"></a></p>
		 // <h3><span class="mw-headline">Conservativity</span></h3>

		 do {
		   preg_match('/(<p><a name=\"[^\"]*\" id=\"[^\"]*\"><\/a><\/p>[\n\r\t]<h[\d]><span class=\"[^\"]*\">.*?<\/span><\/h[\d]>[\n\r\t])<p><a name=\"[^\"]*\" id=\"[^\"]*\"><\/a><\/p>[\n\r\t]<h[\d]><span class=\"[^\"]*\">.*?<\/span><\/h[\d]>/', $content, $matches);

		   // remove the empty paragraph
		   $toRemove = $matches[1];
		   $content = str_replace($toRemove, "", $content);

		   // remove the index entry
		   preg_match('/<p><a name=\"([^\"]*)\"/', $toRemove, $match);
		   $anchorName = $match[1];

		   // get sumary index number
		   preg_match("/<li.*?#$anchorName.*?<span class=\"tocnumber\">([\d\.]*)<\/span>.*?<\/li>/", $content, $match);
		   $indexNumber = $match[1];

		   // remove index line
		   $content = str_replace($match[0], "", $content);

		   // update following summary indexes
		   $indexNumbers = split('[.]', $indexNumber);
		   $last = $indexNumbers[count($indexNumbers) - 1];
		   $prefix = substr($indexNumber, 0, strlen($indexNumber) - strlen($last));

		   $last++;
		   while ( preg_match("/(<span class=\"tocnumber\">$prefix)($last)(<\/span>)/", $content, $match) ) {
		     $content = str_replace($match[0], $match[1].($last-1).$match[3], $content);
		     $last++;
		   };

		 } while (count($matches));

		 // print out
		 $out->mBodytext = $content;
		 SkinTemplate::outputPage($out);
	}
}

global $wgHooks;

// avoid links to category
$wgHooks['LinkBegin'][] = 'KiwixLinkBegin';

function KiwixLinkBegin($skin, $target, &$text, &$customAttribs, &$query, &$options, &$ret) {
  if( $target->getNamespace() == NS_CATEGORY ) {
    return false;
  }
  return true;
}

// remove the footer
$wgHooks['SkinTemplateOutputPageBeforeExec'][] = 'KiwixSkinTemplateOutputPageBeforeExec';

function KiwixSkinTemplateOutputPageBeforeExec(&$template, &$templateEngine) {
  $content =& $templateEngine->data["bodytext"];

  // remove the footer
  preg_match_all('/<div class="printfooter">.*?<\/div>/s', $content, $matches);
  foreach ($matches[0] as $match) {
    $content = str_replace($match, "", $content);
  }

  // remove comments
  preg_match_all('/<\!\-\- [^>]*?\-\->/s', $content, $matches);
  foreach ($matches[0] as $match) {
    $content = str_replace($match, "", $content);
  }

  return true;
}
