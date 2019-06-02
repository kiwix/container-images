#!/usr/bin/perl
use utf8;
use strict;
use warnings;

use FindBin;
use Getopt::Long;
use Locale::Language;
use Data::Dumper;
use Storable qw(dclone);
use File::stat;
use Time::localtime;
use DateTime;
use Locales;
use Number::Bytes::Human qw(format_bytes);

my %content;

# Configuration variables
my $contentDirectory = "/var/www/download.kiwix.org";

my $wp1DirectoryName = "wp1";
my $wp1Directory = $contentDirectory."/".$wp1DirectoryName;
my $zimDirectoryName = "zim";
my $zimDirectory = $contentDirectory."/".$zimDirectoryName;
my $releaseDirectoryName = "release";
my $releaseDirectory = $contentDirectory."/".$releaseDirectoryName;
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
my $deleteOutdatedFiles = 0;
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
    'htaccessPath=s' => \$htaccessPath,
);

if ($showHelp) {
    usage();
    exit 0;
}

# Parse the "zim" directories
my @files = split /\n/, `find "$zimDirectory" -name "*.zim"`;
for my $file (@files) {
    print "$file\n";
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

# Stop here if we only want to make a check
exit if ($onlyCheck);

# Apply to the multiple outputs
if ($deleteOutdatedFiles) {
    deleteOutdatedFiles();
}

if ($writeHtaccess) {
    writeHtaccess();
}

if ($writeWiki) {
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

    writeFile($zimDirectory."/.contentPage.wiki", $content);
}

# Write http://dwonload.kiwix.org .htaccess for better html page
# descriptions of permalinks (pointing always to the last up2date
# content)
sub writeHtaccess {
    my $content = "#\n";
    $content .= "# Please do not edit this file manually\n";
    $content .= "#\n\n";
    $content .= "RewriteEngine On\n\n";

    # Release redirects
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-tools/kiwix-tools.tar.xz ".getLastRelease($releaseDirectory, "kiwix-tools-*.tar.xz")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-tools/kiwix-tools_linux-armhf.tar.gz ".getLastRelease($releaseDirectory, "kiwix-tools_linux-armhf-*.tar.gz")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-tools/kiwix-tools_linux-i586.tar.gz ".getLastRelease($releaseDirectory, "kiwix-tools_linux-i586-*.tar.gz")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-tools/kiwix-tools_linux-x86_64.tar.gz ".getLastRelease($releaseDirectory, "kiwix-tools_linux-x86_64-*.tar.gz")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-tools/kiwix-tools_win-i686.zip ".getLastRelease($releaseDirectory, "kiwix-tools_win-i686-*.zip")."\n";

    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-desktop/kiwix-desktop.tar.gz ".getLastRelease($releaseDirectory, "kiwix-desktop-*.tar.gz")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-desktop/kiwix-desktop_windows_x64.zip ".getLastRelease($releaseDirectory, "kiwix-desktop_windows_x64_*.zip")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-dekstop/kiwix-desktop_x86_64.appimage ".getLastRelease($releaseDirectory, "kiwix-desktop_x86_64_*.appimage")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-dekstop/org.kiwix.desktop.flatpak ".getLastRelease($releaseDirectory, "org.kiwix.desktop.*.flatpak")."\n";

    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-dekstop-macos/kiwix-desktop-macos.dmg ".getLastRelease($releaseDirectory, "kiwix-desktop-macos_*.dmg")."\n";

    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-hotspot/kiwix-hotspot-linux.tar.gz ".getLastRelease($releaseDirectory, "kiwix-hotspot-linux.tar.gz")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-hotspot/kiwix-hotspot-macos.dmg ".getLastRelease($releaseDirectory, "kiwix-hotspot-macos.dmg")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-hotspot/kiwix-hotspot-win32.exe ".getLastRelease($releaseDirectory, "kiwix-hotspot-win32.exe")."\n";
    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-hotspot/kiwix-hotspot-win64.exe ".getLastRelease($releaseDirectory, "kiwix-hotspot-win64.exe")."\n";

    $content .= "RedirectPermanent /".$releaseDirectoryName."/kiwix-android/kiwix.apk ".getLastRelease($releaseDirectory, "kiwix-*.apk")."\n";

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
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_es_all_03_2012.zim /zim/wikipedia_es_all.zim\n";
    $content .= "\n\n";

    # Folder description
    $content .= "AddDescription \"Deprectated stuff kept only for historical purpose\" archive\n";
    $content .= "AddDescription \"All versions of Kiwix, the software (no content is in there)\" release\n";
    $content .= "AddDescription \"Development stuff (tools & dependencies), for developers\" dev\n";
    $content .= "AddDescription \"Binaries and source code tarballs compiled auto. one time a day, for developers\" nightly\n";
    $content .= "AddDescription \"Random stuff, mostly mirrored for third party projects\" other\n";
    $content .= "AddDescription \"Kiwix-Plug Raspberry Pi images\" plug\n";
    $content .= "AddDescription \"XML files describing all the content available, for developers\" library\n";
    $content .= "AddDescription \"Kiwix source code tarballs, for developers only\" src\n";
    $content .= "AddDescription \"Wikipedia articles key indicators for the WP.10 project\" wp1\n";
    $content .= "AddDescription \"ZIM files, content dumps for offline usage (to be read with Kiwix)\" zim\n";

    # WP1 redirects
    my @wp1s = split /\n/, `find $wp1Directory -maxdepth 1 -type d | sort -r`;
    my %wp1_done;
    for my $wp1 (@wp1s) {
        if ($wp1 =~ /^.*\/([^\/]+)(_\d{4}-\d{2})$/) {
            my $core = $1;
            my $dir = $1.$2;
            next if $wp1_done{$core};
            $wp1_done{$core} = $dir;
            $content .= "RedirectPermanent /".$wp1DirectoryName."/".$core." /".$wp1DirectoryName."/".$dir."\n";
        }
    }

    sub writeEntryHtaccess {
        my ($entry, $entries) = @_;
        my $core = $entry->{core};

        my $content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim ".substr($entry->{zim}, length($contentDirectory))."\n";
        $content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim.torrent ".substr($entry->{zim}, length($contentDirectory)).".torrent\n";
        $content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim.magnet ".substr($entry->{zim}, length($contentDirectory)).".magnet\n";
        $content .= "RedirectPermanent /".$zimDirectoryName."/".$core.".zim.md5 ".substr($entry->{zim}, length($contentDirectory)).".md5\n";
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
    foreach my $subDirectory ("archive", "release", "dev", "nightly", "other", "src", "zim", "library") {
        my $htaccessPath = $contentDirectory."/".$subDirectory."/.htaccess";
        writeFile($htaccessPath, $content);
    }
}

# Sort the key in user friendly way
sub sortKeysMethod {
    my %coefs = (
        "wikipedia"   => 11,
        "wiktionary"  => 10,
        "wikivoyage"  => 9,
        "wikiversity" => 8,
        "wikibooks"   => 7,
        "wikisource"  => 6,
        "wikiquote"   => 5,
        "wikinews"    => 4,
        "wikispecies" => 3,
        "ted"         => 2,
        "phet"        => 1
    );
    my $ac = $coefs{(split("_", $a))[0]} || 0;
    my $bc = $coefs{(split("_", $b))[0]} || 0;

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
    }

    # Move the XML files to its final destination
    if (checkXmlIntegrity($tmpZimLibraryPath)) {
        my $cmd = "mv $tmpZimLibraryPath $libraryDirectory/${libraryName}_zim.xml"; `$cmd`;
    }

    # Generate the Ideascube library
    my $ideascube_converter = "/usr/local/bin/library-to-catalog/library-to-catalog.py";
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

sub getLastRelease {
    my ($directory, $regex) = @_;
    my @files = split /\n/, `find "$directory" -name "$regex"`;
    my $file = (sort @files)[-1];
    substr($file, length($contentDirectory))
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

