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

# Start the log system
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("buildOneToOneDictionaryInFrench.pl");

# Hash containing all possible word natures
my %natureCodes = (
    "verb" => { "code" => "V", "abbr" => "v.", "label" => "Verbe" },
    "nom" => { "code" =>  "N", "abbr" => "n.", "label" => "Nom" },
    "loc-phr" => { "code" =>  "LOC", "abbr" => "loc.", "label" => "Locution" },
    "adj" => { "code" =>  "A", "abbr" => "adj.", "label" => "Adjectif" },
);
my $supportedNaturesRegex = join("|", keys(%natureCodes));

# Declare the console argument variables
my $host = "fr.wiktionary.org";
my $path = "w";
my $languageCategory = "";
my $languageCode = "";
my $languageWordList = "";
my $languageDictionaryFile = "";
my $secondLanguageCategory = "français";
my $secondLanguageCode = "fr";
my $secondLanguageWordList = "";
my $secondLanguageDictionaryFile = "";

# Declare necessary variables
my $allLanguageWords;
my $allSecondLanguageWords;
my $allEmbeddedIns;
my $languageWords;
my $secondLanguageWords;
my %languageDictionary;
my %secondLanguageDictionary;

# Get console line arguments
GetOptions(
    'languageCode=s' => \$languageCode, 
    'languageCategory=s' => \$languageCategory,
    'languageWordList=s' => \$languageWordList,
    'languageDictionaryFile=s' => \$languageDictionaryFile,
    'secondLanguageCode=s' => \$secondLanguageCode, 
    'secondLanguageCategory=s' => \$secondLanguageCategory,
    'secondLanguageWordList=s' => \$secondLanguageWordList,
    'secondLanguageDictionaryFile=s' => \$secondLanguageDictionaryFile,
    );

# Verify the mandatory arguments
if (!$languageCode || !$languageCategory || (!$languageDictionaryFile && !$secondLanguageDictionaryFile)) {
    print "usage: ./buildOneToOneDictionaryInFrench.pl --languageCode=ses --languageCategory=songhaï_koyraboro_senni --languageDictionaryFile=langDico.xml [--languageWordList=file.lst] [--secondLanguageCode=fr] [--secondLanguageCategory=français] [--secondLanguageWordList=frenchWords.lst] [--secondLanguageDictionaryFile=frenchDico.xml]\n";
    if (!$languageDictionaryFile && !$secondLanguageDictionaryFile) {
	print "You have to choose at least one of the following options : --languageDictionaryFile or/and --secondLanguageDictionaryFile\n";
    }
    exit;
}

# Create the mediawiki accessor
my $site = MediaWiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

sub getAllWords {
    my $category = shift;
    return [$site->listCategoryEntries($category, 1, "0")];
}

sub getAllEmbeddedIns {
    return [$site->embeddedIn("template:$languageCode", "0")];
}

sub writeFile {
    my $file = shift;
    my $data = shift;

    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    my @list;
 
    open(FILE, '<:utf8', $file);
    while (my $page = <FILE>) {
	$page =~ s/\n//;
	push(@list, $page);
    }
 
    return \@list;
}

sub getListsIntersection {
    my $l1 = shift;
    my $l2 = shift;

    my $lc = List::Compare->new($l1, $l2);

    return [$lc->get_intersection()];
}

sub extractTranslationsFromWikiCode {
    my $wikiCode = shift;
    my $languageCode = shift;
    my @translations;

    while ($wikiCode =~ /\{\{trad(\+|\-|)\|$languageCode\|([^\}]*)\}\}/ig ) {
	push (@translations, $2);
    }

    return \@translations;
}

sub extractAllTranslationsFromWikiCode {
    my $wikiCode = shift;
    my $languageCode = shift;
    my $word = shift;
    my $nature = shift;
    my $gender = shift;

    my %translations;

    # Go through all derivatives if possible
    while ($wikiCode =~ /{{(\(|boîte[_|\ ]début)\|(.*?)(\|.*|}})\n(.*?){{(\)|boîte[_|\ ]fin)}}/sgi ) {
	my $derivative = $2;
	my $subContent = $4;
	$derivative =~ s/{{.*?}}//g;
	$derivative =~ s/^[ ]+//g;
	my $derivativeTranslations = extractTranslationsFromWikiCode($subContent, $languageCode);
	if (scalar(@$derivativeTranslations)) {
	    $translations{$derivative} = { "nature" => $nature, "gender" => $gender,
					   "translations" => $derivativeTranslations };
	}
    }
    
    # Try to find the generic translation
    if ($wikiCode =~ /{{(trad\-trier|\-trad\-)}}(.*?){{\)}}/si ) {
	my $subContent = $2;
	my $genericTranslations = extractTranslationsFromWikiCode($subContent, $languageCode);
	if (scalar(@$genericTranslations)) {
	    $translations{$word} = { "nature" => $nature, "gender" => $gender, "translations" => $genericTranslations };
	}
    }
    
    return \%translations;
}

sub extractLanguageParagraphFromWikiCode {
    my $wikiCode = shift;
    my $languageCode = shift;
    my $paragraph;

    if ($wikiCode =~ /.*\=\=(\ |)\{\{\=$languageCode\=\}\}(\ |)\=\=(.*?)(\=\=\ \{\{\=|$)/s ) {
	$paragraph = $3;
    }

    return $paragraph;
}

sub extractWordNaturesFromWikiCode {
    my $wikiCode = shift;
    my @natures;
    
    while ($wikiCode =~ /({{\-)($supportedNaturesRegex)(\-)(.*?)({{\-($supportedNaturesRegex)\-|$)/si) {
	my $nature = $2;
	my $subContent = $4;
	push(@natures, { "nature" => $nature, "content" => $subContent});
	$wikiCode =~ s/\Q$1$2$3$4\E//;
    }

    return \@natures;
}

sub extractGenderFromWikiCode {
    my $wikiCode = shift;
    if ($wikiCode =~ /{{(m|f)}}/i ) {
	return $1;
    }
}

sub buildSecondLanguageDictionary {

    # Find the translation(s) for each second language word
    foreach my $secondLanguageWord (@$secondLanguageWords) {
	my ($content, $revision) = $site->downloadPage($secondLanguageWord);
	
	# Get the "second language" paragraph
	$content = extractLanguageParagraphFromWikiCode($content, $secondLanguageCode);
	next unless ($content);

	# Get the nature of the word
	my $natures = extractWordNaturesFromWikiCode($content);
	next unless (scalar(@$natures));

	# Save the translations
	foreach my $natureHash (@$natures) {
	    my $nature = $natureHash->{"nature"};
	    my $subContent = $natureHash->{"content"};
	    my $gender;

	    # Get the name gender if the word is a name
	    if ($nature eq "nom") {
		$gender = extractGenderFromWikiCode($subContent);
	    }

	    my $translations = extractAllTranslationsFromWikiCode($subContent, $languageCode, 
								  $secondLanguageWord, $nature, $gender);	    
	    if (scalar(keys(%$translations))) {
		$secondLanguageDictionary{$secondLanguageWord} = $translations;
	    }
	}
    }
}

sub buildLanguageDictionary {
}

sub writeDictionary {
    my $dictionary = shift;
    my $path = shift;
    my $source = shift;
    my $target = shift;

    my $xml = "<OneToOneDictionary source=\"$source\" target=\"$target\">\n";

    # Codes
    $xml .= "\t<codes>\n";
    foreach my $natureCode (keys(%natureCodes)) {
	$xml .= "\t\t<code value=\"".$natureCodes{$natureCode}{"code"}."\" abbr=\"".$natureCodes{$natureCode}{"abbr"}."\">".$natureCodes{$natureCode}{"label"}."</code>\n"
    }
    $xml .= "\t</codes>\n";

    # words
    $xml .="\t<words>\n";
    foreach my $word (keys(%$dictionary)) {
	$xml .= "\t\t<word>\n";
	$xml .= "\t\t\t<value>$word</value>\n";

	my $wordHash = $dictionary->{$word};
	foreach my $derivative (keys(%$wordHash)) {
	    my $derivativeHash = $wordHash->{$derivative};
	    $xml .= "\t\t\t<derivative type=\"".$natureCodes{$derivativeHash->{"nature"}}{"code"}."\"".
		($derivativeHash->{"gender"} ? " gender=\"".$derivativeHash->{"gender"}."\"" : "").">\n";
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
    
    writeFile($path, $xml);
}

# Build whole list of words for both languages
$allLanguageWords = $languageWordList ? 
    readFile($languageWordList) : getAllWords($languageCategory);
$allSecondLanguageWords = $secondLanguageWordList ? 
    readFile($secondLanguageWordList) : getAllWords($secondLanguageCategory);

# Get the list of wiktionary articles using the template:$languageCode
$allEmbeddedIns = getAllEmbeddedIns();

# Reduce list of words for both languages
$languageWords = getListsIntersection($allEmbeddedIns, $allLanguageWords);
$secondLanguageWords = getListsIntersection($allEmbeddedIns, $allSecondLanguageWords);

#$secondLanguageWords = [("religion")];

# Build the dictionaries hashes
buildSecondLanguageDictionary();
buildLanguageDictionary() if ($languageDictionaryFile);

# Write the file
writeDictionary(\%secondLanguageDictionary, $secondLanguageDictionaryFile, $secondLanguageCode, $languageCode);
writeDictionary(\%languageDictionary, $languageDictionaryFile, $languageCode, $secondLanguageCode)
    if ($languageDictionaryFile);

exit;

