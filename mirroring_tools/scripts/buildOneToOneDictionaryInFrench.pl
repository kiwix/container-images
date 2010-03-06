#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use MediaWiki;
use List::Compare;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("buildOneToOneDictionaryInFrench.pl");

# constant
my %natureCodes = (
    "verb" => { "code" => "V", "abbr" => "v.", "label" => "Verbe" },
    "nom" => { "code" =>  "N", "abbr" => "n.", "label" => "Nom" },
    "loc-phr" => { "code" =>  "LOC", "abbr" => "loc.", "label" => "Locution" },
    "adj" => { "code" =>  "A", "abbr" => "adj.", "label" => "Adjectif" },
);

# get the params
my $host = "fr.wiktionary.org";
my $path = "w";
my $category = "";
my $code = "";
my $allFrenchWordsFile = "";
my $frenchDictionaryFile = "";
my $langDictionaryFile = "";

# words
my $allFrenchWords;
my $allLangWords;
my $allEmbeddedIns;
my $frenchWords;
my $langWords;
my %frenchDictionary;
my %langDictionary;

# get console line arguments
GetOptions('code=s' => \$code, 
	   'category=s' => \$category,
	   'allFrenchWordsFile=s' => \$allFrenchWordsFile,
	   'frenchDictionaryFile=s' =>  \$frenchDictionaryFile,
	   'langDictionaryFile=s' => \$langDictionaryFile
    );

if (!$code || !$category || (!$frenchDictionaryFile && !$langDictionaryFile)) {
    print "usage: ./buildFrenchBilingualDictionary.pl --code=ses --category=songhaï_koyraboro_senni [--allFrenchWordsFile=file.lst] [--frenchDictionaryFile=frenchdico.xml] [--langDictionaryFile=langdico.xml]\n";
    if (!$frenchDictionaryFile && !$langDictionaryFile) {
	print "You have to choose one of the following options : --frenchDictionaryFile or/and --langDictionaryFile\n";
    }
    exit;
}

my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

sub getAllFrenchWords() {
    $allFrenchWords = [$site->listCategoryEntries("français", 1, "0")];
}

sub getAllLangWords() {
    $allLangWords = [$site->listCategoryEntries($category, 1, "0")];
}

sub getAllEmbeddedIns() {
    $allEmbeddedIns = [$site->embeddedIn("template:$code", "0")];
}

sub write_file {
    my $file = shift;
    my $data = shift;

    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub read_file {
    my $file = shift;
    my @list;
 
    open(FILE, '<:utf8', $file);
    while (my $page = <FILE>) {
	$page =~ s/\n//;
	push(@list, $page);
    }
 
    return \@list;
}

sub getFrenchWords() {
    my $lc = List::Compare->new(
	$allFrenchWords, 
	$allEmbeddedIns
	);
    $frenchWords = [$lc->get_intersection()];
}

sub getLangWords() {
    my $lc = List::Compare->new(
	$allLangWords, 
	$allEmbeddedIns
	);
    $langWords = [$lc->get_intersection()];
}

sub extractTranslationsFromWikiCode {
    my $code = shift;
    my $lang = shift;
    my @translations;

    while ($code =~ /\{\{trad(\+|\-|)\|$lang\|([^\}]*)\}\}/ig ) {
	push (@translations, $2);
    }

    return \@translations;
}

sub extractAllTranslationsFromWikiCode {
    my $code = shift;
    my $lang = shift;
    my $word = shift;
    my $nature = shift;
    my %translations;

    # Go through all translation derivates
    while ($code =~ /{{(\(|boîte[_|\ ]début)\|(.*?)(\|.*|}})\n(.*?){{(\)|boîte[_|\ ]fin)}}/sgi ) {
	my $derivative = $2;
	my $subContent = $4;
	$derivative =~ s/{{.*?}}//g;
	$derivative =~ s/^[ ]+//g;
	$langWords = extractTranslationsFromWikiCode($subContent, $lang);
	if (scalar(@$langWords)) {
	    $translations{$derivative} = { "nature" => $nature, "translations" => $langWords };
	}
    }
    
    # Try to find the generic translation
    if ($code =~ /{{(trad\-trier|\-trad\-)}}(.*?){{\)}}/si ) {
	my $subContent = $2;
	$langWords = extractTranslationsFromWikiCode($subContent, $lang);
	if (scalar(@$langWords)) {
	    $translations{$word} = { "nature" => $nature, "translations" => $langWords };
	}
    }
    
    return \%translations;
}

sub extractLanguageParagraphFromWikiCode {
    my $code = shift;
    my $lang = shift;

    if ($code =~ /.*\=\=(\ |)\{\{\=$lang\=\}\}(\ |)\=\=(.*?)(\=\=\ \{\{\=|$)/s ) {
	return $3;
    }     
}

sub extractWordNaturesFromWikiCode {
    my $code = shift;
    my $supportedNatures = join("|", keys(%natureCodes));
    my @natures;
    
    while ($code =~ /({{\-)($supportedNatures)(\-)(.*?)({{\-($supportedNatures)\-|$)/si) {
	my $nature = $2;
	my $subContent = $4;
	push(@natures, { "nature" => $nature, "content" => $subContent});
	$code =~ s/\Q$1$2$3$4\E//;
    }

    return \@natures;
}

sub buildFrenchDictionary() {

    # Find the translation(s) for each french word
    foreach my $frenchWord (@$frenchWords) {
	my ($content, $revision) = $site->downloadPage($frenchWord);
	
	# Get the "French" paragraph
	$content = extractLanguageParagraphFromWikiCode($content, "fr");
	next unless ($content);

	# Get the nature of the word
	my $natures = extractWordNaturesFromWikiCode($content);
	next unless (scalar(@$natures));

	# Save the translations
	foreach my $natureHash (@$natures) {
	    my $nature = $natureHash->{"nature"};
	    my $subContent = $natureHash->{"content"};
	    my $translations = extractAllTranslationsFromWikiCode($subContent, $code, $frenchWord, $nature);	    
	    if (scalar(keys(%$translations))) {
		$frenchDictionary{$frenchWord} = $translations;
	    }
	}
    }
}

sub writeFrenchDictionary {
    my $xml = "<OneToOneDictionary source=\"fr\" target=\"$code\" source_name=\"français\" target_name=\"$category\">\n";

    # Codes
    $xml .= "\t<codes>\n";
    foreach my $natureCode (keys(%natureCodes)) {
	$xml .= "\t\t<code value=\"".$natureCodes{$natureCode}{"code"}."\" abbr=\"".$natureCodes{$natureCode}{"abbr"}."\">".$natureCodes{$natureCode}{"label"}."</code>\n"
    }
    $xml .= "\t</codes>\n";

    # words
    $xml .="\t<words>\n";
    foreach my $word (keys(%frenchDictionary)) {
	$xml .= "\t\t<word>\n";
	$xml .= "\t\t\t<value>$word</value>\n";

	my $wordHash = $frenchDictionary{$word};
	foreach my $derivative (keys(%$wordHash)) {
	    my $derivativeHash = $wordHash->{$derivative};
	    $xml .= "\t\t\t<derivative type=\"".$natureCodes{$derivativeHash->{"nature"}}{"code"}."\">\n";
	    $xml .= "\t\t\t\t<value>".$derivative."</value>\n";
	    
	    foreach my $translation (@{$derivativeHash->{"translations"}}) {
		$xml .= "\t\t\t\t<translation>".$translation."</translation>\n";
	    }

	    $xml .= "\t\t\t</derivative>\n";
	}

	$xml .= "\t\t</word>\n";
    }
    $xml .= "\t</words>\n";

    $xml .= "</OneToOneDictionary>\n";
    
    write_file($frenchDictionaryFile, $xml);
}

if ($allFrenchWordsFile) {
    $allFrenchWords = read_file($allFrenchWordsFile);
} else {
    getAllFrenchWords();
}

getAllLangWords();
getAllEmbeddedIns();
getFrenchWords();
getLangWords();
#$frenchWords = [("chaleur")];
buildFrenchDictionary();
writeFrenchDictionary();

print Dumper(%frenchDictionary);

exit;

