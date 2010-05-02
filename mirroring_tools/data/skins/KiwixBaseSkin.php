<?php
class KiwixBaseSkin extends SkinTemplate {
	/** Using kiwix. */
	function initPage( OutputPage $out ) {
		parent::initPage( $out );
		$this->skinname = 'Monobook';
		$this->stylename = 'Monobook';
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

		// This seems not being necessary 
		/*
		if ( $nt->getNamespace() == NS_CATEGORY ) {
			# Determine if the category has any articles in it
			$dbr = wfGetDB( DB_SLAVE );
			$hasMembers = $dbr->selectField( 'categorylinks', '1', 
				array( 'cl_to' => $nt->getDBkey() ), __METHOD__ );
			if ( $hasMembers ) {
				return $this->makeKnownLinkObj( $nt, $text, $query, $trail, $prefix );
			}
		}
		*/

		if ( $text == '' ) {
			$text = $nt->getPrefixedText();
		}
		return $prefix . $text . $trail;
	}

	// reponsible to avoid media links
	function makeMediaLinkObj( $title, $text = '', $time = false ) {
	  return $text;
	}

	/* Should also remove red links */
	public function link( $target, $text = null, $customAttribs = array(), $query = array(), $options = array() ) {
		wfProfileIn( __METHOD__ );
		if( !$target instanceof Title ) {
			return "<!-- ERROR -->$text";
		}
		$options = (array)$options;

		$ret = null;
		if( !wfRunHooks( 'LinkBegin', array( $this, $target, &$text,
		&$customAttribs, &$query, &$options, &$ret ) ) ) {
			wfProfileOut( __METHOD__ );
			return $ret;
		}

		# Normalize the Title if it's a special page
		$target = $this->normaliseSpecialPage( $target );

		# If we don't know whether the page exists, let's find out.
		wfProfileIn( __METHOD__ . '-checkPageExistence' );
		if( !in_array( 'known', $options ) and !in_array( 'broken', $options ) ) {
			if( $target->isKnown() ) {
				$options []= 'known';
			} else {
				$options []= 'broken';
			}
		}
		
		if (in_array( 'broken', $options )) {
		   return $text;
		}

		return Linker::link($target, $text, $customAttribs, $query, $options);
	}

	// responsible for removing failing pictures
	function makeImageLink2( Title $title, $file, $frameParams = array(), $handlerParams = array(), $time = false, $query = "" ) {
                if (!$file || !$file->exists()) {
                   return "";
		}

		// remove none bitmap links
		if ($file->getMediaType() != "BITMAP" && $file->getMediaType() != "DRAWING" 
		   			     || preg_match('/\.djvu$/', $title) ) {
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
		 preg_match_all('/<div class="(detail|homonymie|dablink|detail principal)".*?<\/div>/s', $content, $matches);
		 foreach ($matches[0] as $match) {
		   
		   // remove only html code without links or latex generated mathematics images
		   if (!preg_match("/.*?<a.*?/s", $match) && 
		       !preg_match("/.*?<img class=\"tex\".*?/s", $match) && 
		       !preg_match("/.*?texhtml.*?/s", $match)) {
		     $content = str_replace($match, "", $content);
		   }

		 }

		 // remove return cariage after (sub-)title
		 $content = str_replace("<p><br />", "<p>", $content);
		 
		 // remove empty paragraph
		 $content = str_replace("<p><br /></p>", "", $content);
		 $content = str_replace("<p></p>", "", $content);

		 // other type of useless html
		 $content = str_replace('<p><font class="metadata"><br /></font></p>', "", $content);

		 // remove empty chapter/paragraph/...

		 // <p><a name="Monotonicity" id="Monotonicity"></a></p>
		 // <h3><span class="mw-headline">Monotonicity</span></h3>
		 // <p><a name="Conservativity" id="Conservativity"></a></p>
		 // <h3><span class="mw-headline">Conservativity</span></h3>

		 // <h2 id="Altri_progetti"> <span class="mw-headline">Altri progetti</span></h2>
		 // <h2 id="Collegamenti_esterni"> <span class="mw-headline">Collegamenti esterni</span></h2>

		 $offset = 0;

		 while ( preg_match('/(<p><a name=\"[^\"]*\" id=\"[^\"]*\"><\/a><\/p>[\n\r\t]<h|<h)([\d])([^>]*>[ ]*<span class=\"[^\"]*\">.*?<\/span><\/h[\d]>[\n\r\t]*)(<p><a name=\"[^\"]*\" id=\"[^\"]*\"><\/a><\/p>[\n\r\t]<h|<h)([\d])([^>]*>[ ]*<span class=\"[^\"]*\">.*?<\/span><\/h[\d]>)/', $content, $matches, PREG_OFFSET_CAPTURE, $offset) && count($matches)) {

		   // set the offset for the future
		   $offset = $matches[0][1] + 1 ;

		   // exlude the case of under chapter
		   if ($matches[2][0] >= $matches[5][0]) {

		     // remove the empty paragraph
		     $toRemove = $matches[1][0].$matches[2][0].$matches[3][0];
		     $content = str_replace($toRemove, "", $content);
		     
		     // remove the index entry
		     preg_match('/<p><a name=\"([^\"]*)\"/', $toRemove, $match);
		     $anchorName = $match[1];

		     // new by it.mirror.kiwix.org
		     if ($anchorName == "") {
		       preg_match('/id=\"([^\"]*)\"/', $toRemove, $match);
		       $anchorName = $match[1];
		     }		     		 
		     
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
		   }

		 };

		 // remove last empty chapter/paragraph/...

		 // <h2> <span class="mw-headline">Enlaces externos</span></h2>
		 //  <!-- end content -->
		 $offset = 0;

		 if ( preg_match('/(<p><a name=\"[^\"]*\" id=\"[^\"]*\"><\/a><\/p>[\n\r\t]<h|<h)([\d])(>[ ]*<span class=\"[^\"]*\">.*?<\/span><\/h[\d]>[\n\r\t]*)(\<\!\-\-\ |\<br\/\>\<div\ class\=\"kf\"|\<div\ class\=\"kf\")/', $content, $matches, PREG_OFFSET_CAPTURE, $offset) && count($matches)) {

		   // set the offset for the future
		   $offset = $matches[0][2] + 1 ;

		   // exlude the case of under chapter
		   if ($matches[2][0] >= $matches[5][0]) {

		     // remove the empty paragraph
		     $toRemove = $matches[1][0].$matches[2][0].$matches[3][0];
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
		   }

		 };

		 // remove timeline image map <img usemap="#1e85951432e89de2bc508a5b1c7eb174" src="/images/timeline/1e85951432e89de2bc508a5b1c7eb174.png">
		 while ( preg_match("/(<img )(usemap=\"\#)([^\"]+)(\" )(src=\".*timeline.*\")/", $content, $match) ) {
		   
		   // remove map call in img tag
		   $content = str_replace($match[0], "<br/>".$match[1].$match[5], $content);
		   $mapId = $match[3];

		   // remove map itself
		   if (preg_match("/<map name=\"$mapId\">.*?<\/map>/s", $content, $match2)) {
		     $content = str_replace($match2[0], "", $content);
		   }
		 };
		 
		 // remove <strong class="selflink">*</strong>
		 while ( preg_match("/(<strong class=\"selflink\">)(.*?)(<\/strong>)/", $content, $match) ) {
		   $content = str_replace($match[0], $match[2], $content);
		   $last++;
		 };

		 // remove imagemap "magnify link", for example:
		 // <a href="../../../../articles/l/i/m/File%7ELimburg-Position.png_b699.html" style="position: absolute; top: 0px; left: 0px;">
		 // <img alt="About this image" src="../../../../../extensions/ImageMap/desc-20.png" style="border: medium none ;"></a>
		 while ( preg_match("/<a href=[^>]*><img[^>]*About this image[^>]*><\/a>/", $content, $match) ) {
                   $content = str_replace($match[0], "", $content);
                   $last++;
                 };

		 // remove edit sections
		 while ( preg_match("/<span class=\"editsection\">\[<a.*<\/a>\]<\/span>/", $content, $match) ) {
                   $content = str_replace($match[0], "", $content);
                   $last++;
                 };

		 // Remove empty links (red links) in imagemaps
		 while ( preg_match("/<area\ .*href=\"\".*\/>/", $content, $match) ) {
                   $content = str_replace($match[0], "", $content);
                   $last++;
                 };

                 // Really strange new bugs... img src which starts with http://localhost
		 while ( preg_match("/http\:\/\/localhost/", $content, $match) ) {
                   $content = str_replace($match[0], "", $content);
                   $last++;
                 };

		 // print out
		 $out->mBodytext = $content;
		 SkinTemplate::outputPage($out);
	}
}

global $wgHooks;
global $wgParser;

// shortcut the imagemap extension and output empty string if any error occurs
$wgParser->setHook( 'imagemap', 'KiwixImageMap' );
function KiwixImageMap($content, $attributes, $object) {
	 ini_set('display_errors', 0);
	 $output = call_user_func_array( array( 'ImageMap', 'render' ), array( $content, $attributes, $object ) );
	 ini_set('display_errors', 1);
	 if (preg_match('/"error"/', $output)) {
	    return "";
	 }
	 
	 // (deprecated) remove if default link (one link for the whole image)
	 // if (preg_match('/<a [^>]*>.*?<img.*?<\/a>/s', $output)) {
	 //   return "";
	 // }

	 // Only remove the link
	 if (preg_match('/<a [^>]*>.*?(<img.*?)<\/a>/s', $output, $matches)) {
	    $output = str_replace($matches[0], $matches[1], $output);
	 }

	 return $output;
}

// avoid links to category
$wgHooks['LinkBegin'][] = 'KiwixLinkBegin';

function KiwixLinkBegin($skin, $target, &$text, &$customAttribs, &$query, &$options, &$ret) {
  if( $target->getNamespace() != NS_MAIN && $target->getNamespace() != NS_WIKIPEDIA ) {
    $options = Array('broken');
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
