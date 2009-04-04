<?php
include("skins/ImageGalleryOriginal.php");

class ImageGallery extends ImageGalleryOriginal
{
	function toHTML() {
		global $wgLang;

		$sk = $this->getSkin();

		$params = array( 'width' => $this->mWidths, 'height' => $this->mHeights );
		$i = 0;

		$images = array();

		foreach ( $this->mImages as $pair ) {
			$nt = $pair[0];
			$text = $pair[1];
	
			# Give extensions a chance to select the file revision for us
			$time = $descQuery = false;

			$img = wfFindFile( $nt, $time );

			if( $nt->getNamespace() != NS_FILE || !$img ) {
				# We're dealing with a non-image, spit out the name and be done with it.
			} elseif( $this->mHideBadImages && wfIsBadImage( $nt->getDBkey(), $this->getContextTitle() ) ) {
				# The image is blacklisted, just show it as a text link.
			} elseif( $this->mWidths && $this->mHeights && !( $thumb = $img->transform( $params ) ) ) {
				# Error generating thumbnail.
			} elseif( $img->getMediaType() != 'MEDIATYPE_BITMAP' || $img->getMediaType() != 'MEDIATYPE_DRAWING') {
			        # non image, ignore
			} else {
				array_push($images, $pair);
			}
		}

		if (count($images) > 0) {
			$this->mImages = $images;
			$html = ImageGalleryOriginal::toHTML();

			// remove links
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
		
		return "";
	}
}
