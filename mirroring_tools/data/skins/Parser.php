<?php
include("skins/ParserOriginal.php");

class Parser extends ParserOriginal
{
	function doMagicLinks( $text ) {
	  return $text;
	}
}
