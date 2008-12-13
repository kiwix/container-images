<?php
if ( ! defined( 'MEDIAWIKI' ) )
	die( 1 );

/**
 * Image gallery
 *
 * Add images to the gallery using add(), then render that list to HTML using toHTML().
 *
 * @ingroup Media
 */

include("skins/ImageGallery.php.original");

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
			} elseif( !( $thumb = $img->transform( $params ) ) ) {
				# Error generating thumbnail.
			} else {
				array_push($images, $pair);
			}
		}

		if (count($images) > 0) {
			$this->mImages = $images;
			return ImageGalleryOriginal::toHTML();
		}
		
		return "";
	}
} //class
