<?php
$file = $HTTP_GET_VARS[file];
header('Content-Type: application/metalink+xml');
header('Content-Disposition: attachment; filename="'.$file.'.metalink"');
readfile("http://www.kiwix.org/index.php?title=Metalink/".$file."&action=raw");
?>