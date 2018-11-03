#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../classes/";
use lib "$FindBin::Bin/../../dumping_tools/classes/";

use utf8;
use strict;
use warnings;
use Kiwix::PathExplorer;
use Getopt::Long;
use Locale::Language;
use Data::Dumper;
use Storable qw(dclone);
use File::stat;
use Time::localtime;
use DateTime;
use Locales;
use Number::Bytes::Human qw(format_bytes);
use Mediawiki::Mediawiki;

my %content;

# Configuration variables
my $contentDirectory = "/var/www/download.kiwix.org";
my $zimDirectoryName = "zim";
my $zimDirectory = $contentDirectory."/".$zimDirectoryName;
my $portableDirectoryName = "portable";
my $portableDirectory = $contentDirectory."/".$portableDirectoryName;
my $binDirectoryName = "bin";
my $srcDirectoryName = "src";
my $devDirectoryName = "dev";
my $htaccessPath = $contentDirectory."/.htaccess";
my $libraryDirectoryName = "library";
my $libraryDirectory = $contentDirectory."/".$libraryDirectoryName;
my $libraryName = "library";
my $tmpDirectory = "/tmp";
my $maxOutdatedVersions = 1;

# Task
my $writeHtaccess = 0;
my $writeWiki = 0;
my $writeLibrary = 0;
my $showHelp = 0;
my $wikiPassword = "";
my $deleteOutdatedFiles = 0;
my $checkPortableFiles = 0;
my $onlyCheck = 0;

# Language lookup
my %locale_lookup;
my $locale = Locales->new('en_US');
for my $code ($locale->get_language_codes) {
    my $locale = Locales->new($code) // next; # ignore codes w/o locale
    $locale_lookup{$code} = $locale->get_language_from_code
}

sub usage() {
    print "manageContentRepository\n";
    print "\t--help\n";
    print "\t--writeHtaccess\n";
    print "\t--writeLibrary\n";
    print "\t--deleteOutdatedFiles\n";
    print "\t--htaccessPath=/var/www/download.kiwix.org/.htaccess\n";
    print "\t--writeWiki\n";
    print "\t--wikiPassword=foobar\n";
    print "\t--checkPortableFiles\n";
}

# Parse command line
if (scalar(@ARGV) == 0) {
    $writeHtaccess = 1;
    $writeWiki = 1;
    $writeLibrary = 1;
}

GetOptions(
    'writeHtaccess' => \$writeHtaccess,
    'writeWiki' => \$writeWiki,
    'writeLibrary' => \$writeLibrary,
    'deleteOutdatedFiles' => \$deleteOutdatedFiles,
    'help' => \$showHelp,
    'onlyCheck' => \$onlyCheck,
    'checkPortableFiles' => \$checkPortableFiles,
    'wikiPassword=s' => \$wikiPassword,
    'htaccessPath=s' => \$htaccessPath,
);

if ($showHelp) {
    usage();
    exit 0;
}

# Parse the "zim" directories
my $explorer = new Kiwix::PathExplorer();
$explorer->path($zimDirectory);
while (my $file = $explorer->getNext()) {
    if ($file =~ /^.*\/([^\/]+)\.zim$/i) {
	my $basename = $1;
	my $core = $basename;
	my $month;
	my $year;
	my $lang;
	my $project;
	my $option;

	# Old/new date format
	if ($basename =~ /^(.+?_)([a-z\-]{2,10}?_|)(.+_|)([\d]{2}|)_([\d]{4})$/i) {
	    $project = substr($1, 0, length($1)-1);
	    $option = $3 ? substr($3, 0, length($3)-1) : "";
	    $core = substr($1.$2.$3, 0, length($1.$2.$3)-1);
	    $lang = $2 ? substr($2, 0, length($2)-1) : "en";
	    $month = $4;
	    $year = $5;
	} elsif ($basename =~ /^(.+?_)([a-z\-]{2,10}?_|)(.+_|)([\d]{4}|)\-([\d]{2})$/i) {
	    $project = substr($1, 0, length($1)-1);
	    $option = $3 ? substr($3, 0, length($3)-1) : "";
	    $core = substr($1.$2.$3, 0, length($1.$2.$3)-1);
	    $lang = $2 ? substr($2, 0, length($2)-1) : "en";
	    $year = $4;
	    $month = $5;
	} else {
	    print STDERR "This ZIM file name is not standard: $file\n";
	}

	$content{$basename} = {
	    size => -s "$file",
	    lang => $lang,
	    option => $option,
	    project => $project,
	    zim => $file,
	    basename => $basename,
	    core => $core,
	    month => $month,
	    year => $year,
	};
    }
}

# Parse the "portable" directories
$explorer->reset();
$explorer->path($portableDirectory);
while (my $file = $explorer->getNext()) {
    if ($file =~ /^.*?\+([^\/]+)\.zip$/i) {
	my $basename = $1;
	if (exists($content{$basename})) {
	    if ((exists($content{$basename}->{portable}) && 
		 getFileCreationDate($file) > getFileCreationDate($content{$basename}->{portable})) ||
		!exists($content{$basename}->{portable})
		) {

		my $file_size = -s "$file";
		if ($content{$basename}->{size} > $file_size * (1.1 + $content{$basename}->{size} / (1024 * 1024 * 1024 * 10))) {
		    print STDERR "Portable file $file (".format_bytes($file_size).") is smaller than ZIM (".format_bytes($content{$basename}->{size}).")\n";
		} else {
		    $content{$basename}->{portable} = $file;
		} 
	    }
	} else {
	    print STDERR "Unable to find corresponding ZIM file to $file\n";
	}
    }
}

# Sort content
my %sortedContent;
for (keys(%content)) {
    my $entry = $content{$_};
    my $core = $entry->{core};

    if ($entry->{year} && $entry->{month}) {
	if (exists($sortedContent{$core})) {
	    my $entryDate = DateTime->new(year => $entry->{year}, month => $entry->{month});
	    my $i;
	    for ($i = 0; $i < scalar(@{$sortedContent{$core}}); $i++) {
		my $otherEntry = $sortedContent{$core}->[$i];
		my $otherEntryDate = DateTime->new(year => $otherEntry->{year}, month => $otherEntry->{month});
		last if (DateTime->compare($entryDate, $otherEntryDate) > 0);
	    }
	    splice(@{$sortedContent{$core}}, $i, 0, $entry);
	} else {
	    $sortedContent{$core} = [$entry];
	}
    } else {
	print STDERR "Unable to find publication date for ZIM ".$entry->{zim}."\n";
    }
}

# Check if portable files have ZIM files
if ($checkPortableFiles || $onlyCheck) {
    for (keys(%sortedContent)) {
	my $entry = $sortedContent{$_}->[0];
	if ($entry->{portable}) {
	    my $cmd = "unzip -l '".$entry->{portable}."' | egrep '*.zim(aa|)\$'"; `$cmd`;
	    if ($?) {
		print STDERR $entry->{portable}." has no ZIM file in it.\n";
		$entry->{portable_without_zim} = 1;
	    }
	}
    }
}

# Stop here if we only want to make a check
exit if ($onlyCheck);

# Delete empty portable files (without ZIM files)
for (keys(%sortedContent)) {
    my $entry = $sortedContent{$_}->[0];
    if ($entry->{portable_without_zim}) {
	my $cmd = "rm '".$entry->{portable}."'"; `$cmd`;
	delete($entry->{portable});
    }
}

# Apply to the multiple outputs
if ($deleteOutdatedFiles) {
    deleteOutdatedFiles();
}

if ($writeHtaccess) {
    writeHtaccess();
}

if ($writeWiki) {
    if (!$wikiPassword) {
	print STDERR "If you want to update the library on wiki.kiwix.org, you need to put a wiki password.\n";
	exit 1;
    }
    writeWiki();
}

if ($writeLibrary) {
    writeLibrary();
}

# Remove old files
sub deleteOutdatedFiles {
    for (keys(%sortedContent)) {
	my $contents = $sortedContent{$_};
	for (my $i = $maxOutdatedVersions+1; $i < scalar(@$contents); $i++) {
	    my $entry = $contents->[$i];
	    print "Deleting ".$entry->{zim}."...\n";
	    my $cmd = "rm '".$entry->{zim}."'"; `$cmd`;
	    if ($entry->{portable}) {
		my $cmd = "rm '".$entry->{portable}."'"; `$cmd`;
	    }
	} 
    }
}

# Update wiki.kiwix.org page listing all the content available
sub beautifyZimOptions {
    my $result = "";
    my @options = split("_", shift || "");
    my $optionsLength = scalar(@options);
    for (my$i=0; $i<$optionsLength; $i++) {
	my $option = $options[$i];
	$result .= $option.($i+1<$optionsLength ? " " : "");
    }
    return $result;
}

sub writeWiki {
    my @lines;
    for (sortKeys(keys(%sortedContent))) {
	my $entries = $sortedContent{$_};
	my $entry = $entries->[0];

	my $lang_name = $locale_lookup{$entry->{lang}} || $entry->{lang};
	utf8::decode($lang_name);
	my $line = "{{ZIMdumps/row|{{{2|}}}|{{{3|}}}|".
	    $entry->{project}." (".$lang_name.") |".
	    $entry->{lang}."|".format_bytes($entry->{size})."|".
	    $entry->{year}."-".$entry->{month}."|".(beautifyZimOptions($entry->{option} || "all"))."|8={{DownloadLink|".
	    $entry->{core}."|{{{1}}}|".$zimDirectoryName."/}} }}\n";
	push(@lines, $line);
    }

    my $content = "<!-- THIS PAGE IS AUTOMATICALLY, PLEASE DON'T MODIFY IT MANUALLY -->";
    for (@lines) {
	$content .= $_;
    }

    # Get the connection to kiwix.org
    my $site = Mediawiki::Mediawiki->new();
    $site->hostname("wiki.kiwix.org");
    $site->path("w");
    $site->user("LibraryBot");
    $site->password($wikiPassword);
    $site->setup();
    $site->uploadPage("Template:ZIMdumps/content", $content, "Automatic update of the ZIM library");
    $site->logout();
}

# Write http://dwonload.kiwix.org .htaccess for better html page
# descriptions of permalinks (pointing always to the last up2date
# content)
sub writeHtaccess {
    my $content = "#\n";
    $content .= "# Please do not edit this file manually\n";
    $content .= "#\n\n";
    $content .= "RewriteEngine On\n\n";
    
    # Bin redirects
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix.apk /".$binDirectoryName."/android/kiwix-2.2.apk\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-installer.exe /".$binDirectoryName."/0.9/kiwix-0.9-installer.exe\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-linux-i686.tar.bz2 /".$binDirectoryName."/0.9/kiwix-0.9-linux-i686.tar.bz2\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-linux-x86_64.tar.bz2 /".$binDirectoryName."/0.9/kiwix-0.9-linux-x86_64.tar.bz2\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-win.zip /".$binDirectoryName."/0.9/kiwix-0.9-win.zip\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix.dmg /".$binDirectoryName."/0.9/kiwix-0.9.dmg\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix.xo /".$binDirectoryName."/0.9/kiwix-0.9.xo\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-server-arm.tar.bz2 /".$binDirectoryName."/0.9/kiwix-server-0.9-linux-armv5tejl.tar.bz2\n";
    $content .= "RedirectPermanent /".$srcDirectoryName."/kiwix-src.tar.xz /".$srcDirectoryName."/kiwix-0.9-src.tar.xz\n";

    # Dev redirects
    $content .= "RedirectPermanent /".$devDirectoryName."/ZIMmaker.ova /".$devDirectoryName."/ZIMmakerVMv6.ova\n";
    $content .= "RedirectPermanent /".$devDirectoryName."/ZIMmaker.ova.torrent /".$devDirectoryName."/ZIMmakerVMv5.ova.torrent\n";
    $content .= "RedirectPermanent /".$devDirectoryName."/KiwixDev.ova /".$devDirectoryName."/KiwixDevVMv4.ova\n";
    $content .= "RedirectPermanent /".$devDirectoryName."/KiwixDev.ova.torrent /".$devDirectoryName."/KiwixDevVMv4.ova.torrent\n";

    # Wikifundi
    $content .= "RedirectPermanent /other/wikifundi http://download.openzim.org/wikifundi\n";

    # Backward compatibility redirects
    # To get the list of failing requests: cat /var/log/nginx/download.kiwix.org.access.log | grep " 404 " | cut -d ' ' -f 7 | grep -v nightly | grep -v favicon | grep -v robots | sort | uniq -c | sort -b -n -r
    $content .= "RedirectPermanent /zim/0.9/ /zim/wikipedia/\n";
    $content .= "RedirectPermanent /install/ /bin/\n";
    $content .= "RedirectPermanent /zim/0.9/wikipedia_en_ray_charles_03_2013.zim /zim/wikipedia/wikipedia_en_ray_charles_2015-06.zim\n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_en_ray_charles_03_2013.zim /zim/wikipedia/wikipedia_en_ray_charles_2015-06.zim\n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_en_all_nopic_01_2012.zim.torrent /zim/wikipedia_en_all_nopic.zim.torrent\n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_fa_all_nopic_2015-01.zim /zim/wikipedia_fa_all_nopic.zim \n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_fa_all_05_2014.zim /zim/wikipedia_fa_all.zim\n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_en_for_schools_2013.zim /zim/wikipedia_en_for-schools.zim\n";
    $content .= "RedirectPermanent /kiwix/kiwix-0.5.iso /portable/wikipedia_en_wp1-0.5.zip\n";
    $content .= "RedirectPermanent /portable/wikipedia/kiwix-0.9+wikipedia_en_all_07_2014.zip /portable/wikipedia_en_all.zip\n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_es_all_03_2012.zim /zim/wikipedia_es_all.zim\n";
    $content .= "\n\n";

    # Folder description
    $content .= "AddDescription \"Deprectated stuff kept only for historical purpose\" archive\n";
    $content .= "AddDescription \"All versions of Kiwix, the software (no content is in there)\" bin\n";
    $content .= "AddDescription \"Development stuff (tools & dependencies), for developers\" dev\n";
    $content .= "AddDescription \"Binaries and source code tarballs compiled auto. one time a day, for developers\" nightly\n";
    $content .= "AddDescription \"Random stuff, mostly mirrored for third party projects\" other\n";
    $content .= "AddDescription \"Kiwix-Plug Raspberry Pi images\" plug\n";
    $content .= "AddDescription \"Portable packages (Kiwix+content), mostly for end-users\" portable\n";
    $content .= "AddDescription \"XML files describing all the content available, for developers\" library\n";
    $content .= "AddDescription \"Kiwix source code tarballs, for developers only\" src\n";
    $content .= "AddDescription \"Wikipedia articles key indicators for the WP.10 project\" wp1\n";
    $content .= "AddDescription \"ZIM files, content dumps for offline usage (to be read with Kiwix)\" zim\n";

    sub writeEntryHtaccess {
	my ($entry, $entries) = @_;
	my $core = $entry->{core};
	
	my $content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim ".substr($entry->{zim}, length($contentDirectory))."\n";
	$content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim.torrent ".substr($entry->{zim}, length($contentDirectory)).".torrent\n";
	$content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim.magnet ".substr($entry->{zim}, length($contentDirectory)).".magnet\n";
	$content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim.md5 ".substr($entry->{zim}, length($contentDirectory)).".md5\n";

	for (@$entries) {
	    if ($_->{portable}) {
		$entry = $_;
		last;
	    }
	}

	if ($entry->{portable}) {
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$core.".zip ".substr($entry->{portable}, length($contentDirectory))."\n";
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$core.".zip.torrent ".substr($entry->{portable}, length($contentDirectory)).".torrent\n";
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$core.".zip.magnet ".substr($entry->{portable}, length($contentDirectory)).".magnet\n";
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$core.".zip.md5 ".substr($entry->{portable}, length($contentDirectory)).".md5\n";
	}

	$content .= "\n";
    }

    # Content redirects
    for (keys(%sortedContent)) {
	my $key = $_;
	my $entries = $sortedContent{$key};
	my $entry = $entries->[0];

	# Write normal entry
	$content .= writeEntryHtaccess($entry, $entries);

	# Redirect _all to _all_novid if _all does not exist
	if ($key =~ /_novid/) {
	    my $all_key = $key =~ s/_novid//gr;
	    unless (exists($sortedContent{$all_key})) {
		my $all_entry = dclone($entry);
		$all_entry->{core} =~ s/_novid//g;
		$content .= writeEntryHtaccess($all_entry, $entries);
	    }
	}

    }
    writeFile($htaccessPath, $content);

    # Write a few .htaccess files in sub-directories
    $content = "AddDescription \" \" *\n";
    foreach my $subDirectory ("archive", "bin", "dev", "nightly", "other", "portable", "src", "zim", "library") {
	my $htaccessPath = $contentDirectory."/".$subDirectory."/.htaccess";
	writeFile($htaccessPath, $content);
    }
}

# Sort the key in user friendly way
sub sortKeysMethod {
    my %coefs = (
	"wikipedia"  => 11,
	"wiktionary" => 10,
	"wikivoyage" => 9,
	"wikiversity" => 8,
	"wikibooks" => 7,
	"wikisource" => 6,
	"wikiquote" => 5,
	"wikinews" => 4,
	"wikispecies" => 3,
	"ted" => 2,
        "phet" => 1
    );
    my $ac = $coefs{shift([split("_", $a)])} || 0;
    my $bc = $coefs{shift([split("_", $b)])} || 0;

    if ($ac < $bc) {
	return 1;
    } elsif ($ac > $bc) {
	return -1;
    }

    # else
    return $a cmp $b;
}

sub sortKeys {
    return sort sortKeysMethod @_;
}

# Write the library.xml file which is used as content catalog by Kiwix
# software internal library
sub writeLibrary {
    my $kiwixManagePath;

    # Get kiwix-manage full path
    if ($writeLibrary) {
	$kiwixManagePath = `which kiwix-manage`;
	$kiwixManagePath =~ s/\n//g;
	if ($? != 0 || !$kiwixManagePath) {
	    print STDERR "Unable to find kiwix-manage. You need it to write the library.\n";
	    exit 1;
	}
    }

    # Generate random tmp library name
    my @chars = ("A".."Z", "a".."z");
    my $randomString;
    $randomString .= $chars[rand @chars] for 1..8;
    my $tmpLibraryPath = $tmpDirectory."/".$libraryName.".".$randomString.".xml";
    my $tmpZimLibraryPath = $tmpDirectory."/".$libraryName."_zim.".$randomString.".xml";

    # Create the library.xml file for the most recent files
    for (sortKeys(keys(%sortedContent))) {
	my $i = 0;
	my $core = $_;
	my $entry = $sortedContent{$core}->[$i];
	my $zimPath = $entry->{zim};
	my $permalink = "http://download.kiwix.org".substr($entry->{zim}, length($contentDirectory)).".meta4";
	my $cmd = "$kiwixManagePath $tmpZimLibraryPath add $zimPath --zimPathToSave=\"\" --url=$permalink";
	system($cmd) == 0
	    or print STDERR "Unable to put $zimPath to XML library";

        # Searching for a recent content with portable version
        do {
	    $entry = $sortedContent{$core}->[$i];
	    if ($entry->{portable}) {
		$zimPath = $entry->{zim};
		$permalink = "http://download.kiwix.org".substr($entry->{zim}, length($contentDirectory)).".meta4";
		$cmd = "$kiwixManagePath $tmpLibraryPath add $zimPath --zimPathToSave=\"\" --url=$permalink";
		system($cmd) == 0
		    or print STDERR "Unable to put $zimPath to XML library";
	    }
	    $i++;
	} while ($i<scalar(@{$sortedContent{$core}}) && !($entry->{portable}));
    }

    # Move the XML files to its final destination
    if (checkXmlIntegrity($tmpLibraryPath) && checkXmlIntegrity($tmpZimLibraryPath)) {
	my $cmd = "mv $tmpLibraryPath $libraryDirectory/$libraryName.xml"; `$cmd`;
	$cmd = "mv $tmpZimLibraryPath $libraryDirectory/${libraryName}_zim.xml"; `$cmd`;
    }

    # Generate the Ideascube library
    my $ideascube_converter = "/var/www/kiwix/maintenance/library-to-catalog/library-to-catalog.sh";
    my $ideascube_source    = "$libraryDirectory/${libraryName}_zim.xml";
    my $ideascube_target    = "/var/www/download.kiwix.org/library/ideascube.yml";
    if (-e $ideascube_converter) {
	my $cmd = "$ideascube_converter '$ideascube_source' '$ideascube_target'"; `$cmd`;
    } else {
	print STDERR "Unable to find $ideascube_converter";
    }
}

sub checkXmlIntegrity {
    my $xml = shift;
    my $xmllint = findBinary("xmllint");
    my $cmd = "$xmllint --noout $xml";
    system($cmd);
    $? == 0 or die "$xml is not a valid XML file says '$cmd'";
    1
}

sub findBinary {
    my $binary = shift;
    my $path = `which $binary`;
    $path =~ s/\n//g;
    if ($? != 0 || !$path) {
	print STDERR "Unable to find $binary.\n";
	exit 1;
    }
    $path
}

# fs functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    utf8::encode($data);
    utf8::encode($file);
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    utf8::encode($file);
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    utf8::decode($data);
    return $buf;
}

sub getFileCreationDate {
    return stat(shift)->ctime;
}

exit 0;

