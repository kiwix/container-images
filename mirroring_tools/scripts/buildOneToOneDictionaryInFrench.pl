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
my $frenchWordList = "";

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
    'frenchWordList=s' => \$frenchWordList,
    );

# Verify the mandatory arguments
if (!$languageCode || !$languageCategory || (!$languageDictionaryFile && !$secondLanguageDictionaryFile)) {
    print "usage: ./buildOneToOneDictionaryInFrench.pl --languageCode=ses --languageCategory=songhaï_koyraboro_senni --languageDictionaryFile=langDico.xml [--languageWordList=file.lst] [--secondLanguageCode=fr] [--secondLanguageCategory=français] [--secondLanguageWordList=frenchWords.lst] [--secondLanguageDictionaryFile=frenchDico.xml] [--frenchWordList=words.fr.lst]\n";
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
    my $template = shift;
    return [$site->embeddedIn("template:$template", "0")];
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

sub getListIntersection {
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
    my $frenchWord = shift;
    my $nature = shift;
    my $languageCode = shift;
    my $secondLanguageCode = shift;
    my $languageWords = shift;
    my $secondLanguageWords = shift;

    my %translations;

    # Go through all derivatives if possible
    while ($wikiCode =~ /{{(\(|boîte[_|\ ]début)\|(.*?)(\|.*|}})\n(.*?){{(\)|boîte[_|\ ]fin)}}/sgi ) {
	my $derivative = $2;
	my $subContent = $4;
	$derivative =~ s/{{.*?}}//g;
	$derivative =~ s/^[ ]+//g;

	# try to find the translations for the french word
	my $languageDerivativeTranslations = ($languageCode eq "fr" ? [($derivative)] : 
					      extractTranslationsFromWikiCode($subContent, $languageCode));
	my $secondLanguageDerivativeTranslations = ($secondLanguageCode eq "fr" ? [($derivative)] : 
						    extractTranslationsFromWikiCode($subContent, $secondLanguageCode));

	# Save the translations
	if (scalar(@$languageDerivativeTranslations) && scalar(@$secondLanguageDerivativeTranslations)) {
	    $translations{$derivative} = { "nature" => $nature,
					   $languageCode => $languageDerivativeTranslations,
					   $secondLanguageCode => $secondLanguageDerivativeTranslations,
	    };
	    push(@$languageWords, @$languageDerivativeTranslations);
	    push(@$secondLanguageWords, @$secondLanguageDerivativeTranslations);
	}
    }
    
    # Try to find the generic translation
    if ($wikiCode =~ /{{(trad\-trier|\-trad\-)}}(.*?){{\)}}/si ) {
	my $subContent = $2;
	my $languageGenericTranslations = ($languageCode eq "fr" ? [($frenchWord)] : 
					   extractTranslationsFromWikiCode($subContent, $languageCode));
	my $secondLanguageGenericTranslations = ($secondLanguageCode eq "fr" ? [($frenchWord)] : 
						 extractTranslationsFromWikiCode($subContent, $secondLanguageCode));
	
	if (scalar(@$languageGenericTranslations) && scalar(@$secondLanguageGenericTranslations)) {
	    $translations{$frenchWord} = { "nature" => $nature,
					   $languageCode => $languageGenericTranslations,
					   $secondLanguageCode => $secondLanguageGenericTranslations
	    };
	    push(@$languageWords, @$languageGenericTranslations);
	    push(@$secondLanguageWords, @$secondLanguageGenericTranslations);
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

sub buildTranslationTable {
    my $frenchWords = shift;
    my $languageCode = shift;
    my $secondLanguageCode = shift;
    my $languageWords = shift;
    my $secondLanguageWords = shift;
    my %translations;

    # Go through the word list
    foreach my $frenchWord (@$frenchWords) {
	my ($content, $revision) = $site->downloadPage($frenchWord);
	
	# Get the French language paragraph
	$content = extractLanguageParagraphFromWikiCode($content, "fr");
	next unless ($content);

	# Get the nature of the word
	my $natures = extractWordNaturesFromWikiCode($content);
	next unless (scalar(@$natures));

	# Get the translations for both languages
	foreach my $natureHash (@$natures) {
	    my $nature = $natureHash->{"nature"};
	    my $subContent = $natureHash->{"content"};

	    my $frenchWordTranslations = extractAllTranslationsFromWikiCode($subContent, $frenchWord, 
									    $nature, $languageCode, $secondLanguageCode,
									    $languageWords, $secondLanguageWords);	    
	    if (scalar(keys(%$frenchWordTranslations))) {
		$translations{$frenchWord} = $frenchWordTranslations;
	    }
	}
    }

    return \%translations;
}

sub buildDictionary {
    my $words = shift;
    my $languageCode = shift;
    my %dictionary;

    # Go through the word list
    foreach my $word (@$words) {
	my ($content, $revision) = $site->downloadPage($word);
	
	# Get the language paragraph
	$content = extractLanguageParagraphFromWikiCode($content, $languageCode);
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

	    # Add the word to the dictionary
	    $dictionary{$word} = { $word => { "nature" => $nature, "gender" => $gender } };
	}
    }

    return \%dictionary;
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
$logger->info("Getting all words for the language with code $languageCode.");
my $allLanguageWords = $languageWordList ? 
    readFile($languageWordList) : getAllWords($languageCategory);
$logger->info("Getting all words for the language with code $secondLanguageCode.");
my $allSecondLanguageWords = $secondLanguageWordList ? 
    readFile($secondLanguageWordList) : getAllWords($secondLanguageCategory);

# Build the whole list of french words
$logger->info("Getting all words for the french language.");
my $allFrenchWords = $frenchWordList ? 
    readFile($frenchWordList) : getAllWords("français");

# Get the list of wiktionary articles using language templates
$logger->info("Getting all articles using the template:$languageCode.");
my $allLanguageEmbeddedIns = ($languageCode eq "fr" ? $allFrenchWords : getAllEmbeddedIns($languageCode));
$logger->info("Getting all articles using the template:$secondLanguageCode.");
my $allSecondLanguageEmbeddedIns = ($secondLanguageCode eq "fr" ? $allFrenchWords : getAllEmbeddedIns($secondLanguageCode));

# Reduce list of words for both languages
$logger->info("Computing list intersections...");
my $languageWords = getListIntersection($allLanguageEmbeddedIns, $allFrenchWords);
my $secondLanguageWords = getListIntersection($allSecondLanguageEmbeddedIns, $allFrenchWords);
my $frenchWords = getListIntersection($languageWords, $secondLanguageWords);

# Clear the both languages, new words lists will depend on which
# traductions are available in the corresponding french word
$languageWords = [()];
$secondLanguageWords = [()];

# Build the translation table
$logger->info("Building Translation table...");
my $translationTable = buildTranslationTable($frenchWords, $languageCode, $secondLanguageCode, 
					     $languageWords, $secondLanguageWords);

# Remove duplicates
my %languageTmpHash = map { $_, 1 } @$languageWords; $languageWords = [keys(%languageTmpHash)];
my %secondLanguageTmpHash = map { $_, 1 } @$languageWords; $languageWords = [keys(%secondLanguageTmpHash)];

# Build the dictionaries hashes
$logger->info("Building dictionary for the language with code $languageCode.");
my $languageDictionary = buildDictionary($languageWords, $languageCode) if ($languageDictionaryFile);

$logger->info("Building dictionary for the language with code $secondLanguageCode.");
my $secondLanguageDictionary = buildDictionary($secondLanguageWords, $secondLanguageCode)
    if ($secondLanguageDictionaryFile);

# Write the file
$logger->info("Computing and writting final bilingual dictionaries...");
writeDictionary($secondLanguageDictionary, $secondLanguageDictionaryFile, $secondLanguageCode, $languageCode)
    if ($secondLanguageDictionaryFile);
writeDictionary($languageDictionary, $languageDictionaryFile, $languageCode, $secondLanguageCode)
    if ($languageDictionaryFile);

exit;

