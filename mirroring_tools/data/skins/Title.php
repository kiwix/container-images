<?php

include("skins/TitleOriginal.php");

class Title extends TitleOriginal
{
	public function getLocalURL( $query = '', $variant = false ) {	
		$trace=debug_backtrace();
        	$caller=$trace[2];

		if ($caller['class'] == 'ImageMap' && !$this->exists()) {
		   return "";
		}

	       return parent::getLocalURL($query, $variant);
	}
}

?>
