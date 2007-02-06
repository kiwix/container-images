/*  KiwixComponent - XP-COM component for Kiwix, offline reader of Wikipedia
    Copyright (C) 2007, Fabien Coulon for LinterWeb (France)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA */

#include "engine.h"
#include <string.h>
#include <stdlib.h>

void engine::load( const char *root ) {

  char rootedfilename[512];
  char *path;

//  printf( "root = %s\n", root );
  bValid = 0;
  strcpy( rootedfilename, root );
  path = rootedfilename + strlen( rootedfilename );
  (*path++)=SLASH_CHAR;

  strcpy( path, WORD_MAP_FILENAME );
  FILE *wmf = fopen( rootedfilename, "rb" );
  if ( !wmf ) return; 
  wm.load( wmf );
  fclose(wmf);

  strcpy( path, WORD_INDEX_FILENAME );
  FILE *wif = fopen( rootedfilename, "rb" );
  if ( !wif ) return; 
  wi.load(wif);
  fclose(wif);

  strcpy( path, ARTICLE_MAP_FILENAME );
  FILE *amf = fopen( rootedfilename, "rb" );
  if ( !amf ) return; 
  am.load(amf);
  fclose(amf);

  strcpy( path, ARTICLE_INDEX_FILENAME );
  FILE *aif = fopen( rootedfilename, "rb" );
  if ( !aif ) return; 
  ai.load(aif);
  fclose(aif);

  vocSpe = NULL;  
  bValid = 1;
}
 
static void Utf8toAscii( unsigned char *c ) {

  unsigned char *s = c, *d = c;

  while ( *s ) {
    
    if ( *s <= 127 ) { 
      if (( 'A' <= *s )&&( *s <= 'Z' )) *(d++) = 'a'-'A' + *s;
      else *(d++) = *s;
      s++;
    }
    else if (( 192 <= *s )&&( *s <= 223 )) {
      if ( !*(s+1) ) break;
      int car = (*s-192)*64+(*(s+1)-128);
      if (( 0xE0 <= car )&&( car <= 0xE5 )) *(d++) = 'a';
      if (( 0xE7 == car )) *(d++) = 'c';
      if (( 0xE8 <= car )&&( car <= 0xEB )) *(d++) = 'e';
      if (( 0xEC <= car )&&( car <= 0xEF )) *(d++) = 'i';
      if (( 0xF2 <= car )&&( car <= 0xF6 )) *(d++) = 'o';
      if (( 0xF9 <= car )&&( car <= 0xFC )) *(d++) = 'u';
      s+=2;
    } else s++;
  }
  *d=0;
}

listElements * engine::search( const char *query ) {

  char word[128];
  const char *curs = query;
  intIndex  wQuery[50];
  int       wQueryMax = 0;
  listElements *allArticles = NULL;

  if ( vocSpe ) delete vocSpe;
  vocSpe = NULL;
  Utf8toAscii( (unsigned char *)query );

  while ( *curs ) {

    while ( *curs == ' ' ) curs++;
    int len;
    for ( len = 0 ; curs[len] && (curs[len]!=' ') ; len++ ) ;;
    if ( len > 128 ) len = 128;
    strncpy( word, curs, len );
    word[len]=0;
    curs +=len;

    int wordIndex = wm.getIndex( word );
    if (( wordIndex < 0 )&&( word[len-1] == 's' )) {

      word[len-1]=0;
      wordIndex = wm.getIndex( word );
    }
    if ( (wordIndex >= 0)&&(wQueryMax<50) ) {

      wQuery[wQueryMax++] = wordIndex;

      listElements *vocSpeWord = NULL;
//      printf( "word %d : %s : \n", wordIndex, word );
      listElements *articles = wi.getArticles( wordIndex );
      for ( int i = 0 ; i < articles->length() ; i++ ) {
//        printf( "article %d : %s\n", articles->element(i), am.getName( articles->element(i) ) );
        if ( vocSpeWord ) 
          vocSpeWord = new listElements( vocSpeWord, ai.getWords( articles->element(i) ) );
        else vocSpeWord = ai.getWords( articles->element(i) );
      }
      if ( allArticles ) allArticles = new listElements( allArticles, articles );
      else allArticles = articles;
      if ( vocSpe ) vocSpe = new listElements( vocSpe, vocSpeWord, 1 );
      else vocSpe = vocSpeWord;
    }
    while ( *curs == ' ' ) curs++;
  }
  if ( !vocSpe ) return new listElements(0);
  vocSpe->sortCounts();
  vocSpe->cut(SPECIFIC_VOCAB_SIZE);
  vocSpe->debug( "voc spé" );

  listElements * scores = new listElements( ai.length() );
  scores->fillIndexZero();

  int i;
  for ( i = 0 ; i < vocSpe->length() ; i++ ) {
    listElements * articles = wi.getArticles(vocSpe->element(i));
    articles->intersectWith( allArticles );
    for ( int j = 0 ; j < articles->length() ; j++ ) {
      scores->addCount( articles->element(j), 1 );
    }
    delete articles;
  }
  
  for ( i = 0 ; i < wQueryMax ; i++ ) {
  	
  	listElements *articles = wi.getTitles( wQuery[i] );
  	for ( int j = 0 ; j < articles->length() ; j++ ) {
  	
  	  scores->addCount( articles->element(j), INTITLE_BONUS );
	  if ( !strcmp( query, am.getTitle(articles->element(j) ) ))
  	    scores->addCount( articles->element(j), EXACT_TITLE_BONUS );
  	}
  	delete articles;
  }
  
  scores->sortCounts();

  scores->cutZero();  
  return scores;
}


void engine::wordCompletion( const char *word, char *buf, int maxlen ) {

  wm.wordCompletion( word, buf, maxlen );
}

const char * engine::getArticleName( listElements *res, int pos ) {

  return am.getName(res->element(pos));
}

const char * engine::getArticleTitle( listElements *res, int pos ) {

  return am.getTitle(res->element(pos));
}

const char * engine::getVocSpe( int pos ) {

  if ( !vocSpe ) return NULL;
  if ( pos < vocSpe->length() ) 
    return wm.getWord( vocSpe->element(pos) );
  else return NULL;
}

int  engine::getScore( listElements *res, int pos ) {

  return res->count(pos);	
}

void engine::debugWords() {

  wm.debug();
}
