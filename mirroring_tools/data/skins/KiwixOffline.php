<?php
include "KiwixBaseSkin.php";

class SkinKiwixOffline extends KiwixBaseSkin {
        function initPage( &$out ) {
		SkinTemplate::initPage( $out );
		$this->skinname = 'KiwixOffline';
		$this->stylename = 'KiwixOffline';
		$this->template = 'KiwixOfflineTemplate';
	}

	function setupTemplate( $className, $repository = false, $cache_dir = false ) {
		global $wgFavicon;
		$tpl = parent::setupTemplate( $className, $repository, $cache_dir );
		$tpl->set( 'skinpath', $this->skinpath );
		return $tpl;
	}
}

/**
 * @todo document
 * @ingroup Skins
 */
class KiwixOfflineTemplate extends QuickTemplate {
	var $skin;

	function execute() {
		global $wgRequest;
		$this->skin = $skin = $this->data['skin'];
		$action = $wgRequest->getText( 'action' );

		//
		$links = $this->data['csslinks'];
		$links = str_replace("../../../../skins/../", "../", $links);
		$this->data['csslinks'] = $links;     

		// Suppress warnings to prevent notices about missing indexes in $this->data
		wfSuppressWarnings();

?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="<?php $this->text('xhtmldefaultnamespace') ?>" <?php
	foreach($this->data['xhtmlnamespaces'] as $tag => $ns) {
		?>xmlns:<?php echo "{$tag}=\"{$ns}\" ";
	} ?>xml:lang="<?php $this->text('lang') ?>" lang="<?php $this->text('lang') ?>" dir="<?php $this->text('dir') ?>">
	<head>
		<meta http-equiv="Content-Type" content="<?php $this->text('mimetype') ?>; charset=<?php $this->text('charset') ?>" />
		<?php $this->html('headlinks') ?>
		<title><?php $this->text('pagetitle') ?></title>
		<?php $this->html('csslinks') ?>

		<?php print Skin::makeGlobalVariablesScript( $this->data ); ?>

		<script type="<?php $this->text('jsmimetype') ?>" src="<?php $this->text('stylepath' ) ?>/common/wikibits.js?<?php echo $GLOBALS['wgStyleVersion'] ?>"></script>
<?php $this->html('headscripts') ?>
<?php	if($this->data['jsvarurl']) { ?>
		<script type="<?php $this->text('jsmimetype') ?>" src="<?php $this->text('jsvarurl') ?>"></script>
<?php	} ?>
<?php	if($this->data['pagecss']) { ?>
		<style type="text/css"><?php $this->html('pagecss') ?></style>
<?php	}
		if($this->data['usercss']) { ?>
		<style type="text/css"><?php $this->html('usercss') ?></style>
<?php	}
		if($this->data['userjs']) { ?>
		<script type="<?php $this->text('jsmimetype') ?>" src="<?php $this->text('userjs' ) ?>"></script>
<?php	}
		if($this->data['userjsprev']) { ?>
		<script type="<?php $this->text('jsmimetype') ?>"><?php $this->html('userjsprev') ?></script>
<?php	}
		if($this->data['trackbackhtml']) print $this->data['trackbackhtml']; ?>
	</head>
<body style="margin: 0 1em 1em 1em;" >
	<div id="globalWrapper">
		<a name="top" id="top"></a>
		<h1 class="firstHeading"><?php $this->html('title'); ?></h1>
			<?php $this->html('bodytext') ?>

</div>
<?php $this->html('bottomscripts'); /* JS call to runBodyOnloadHook */ ?>
</body></html>
<?php
	wfRestoreWarnings();
	} // end of execute() method

} // end of class


