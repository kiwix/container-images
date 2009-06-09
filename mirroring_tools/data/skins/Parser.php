<?php
include("skins/ParserOriginal.php");

class Parser extends ParserOriginal
{
       function magicLinkCallback( $m ) {
          # Free external link
	  if ( isset( $m[3] ) && strval( $m[3] ) !== '' ) {
	    return $this->makeFreeExternalLink( $m[0] );
	  }
	  return $m[0];
	}

	/* Necessary to avoid overwriting from the extensions */
	function setHook( $tag, $callback ) {
	  if ($tag == 'imagemap' && $this->mTagHooks[$tag])
	    return;
	  
	  return parent::setHook($tag, $callback);
	}
}

?>