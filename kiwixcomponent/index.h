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

#ifndef INDEX_H_
#define INDEX_H_

#include <stdio.h>
#include "list.h"
#include "common.h"

#ifdef _POSIX_
#define SLASH_CHAR '/'
#define SLASH_HTML "/html"
#else
#define SLASH_CHAR '\\'
#define SLASH_HTML "\\html"
#endif

class wordMap {
	
public:
  wordMap();
  ~wordMap();
  void load( FILE* in );
  intIndex  getIndex( const char *word );
  const char *getWord( intIndex idx );
  void wordCompletion( const char *word, char *result, int maxlen );
  int  getHack( const char *word );
  void debug();
  int  bValid;
  
protected:
  int  parseWord( const char* word );

  char *name;
  intOffset  offset[WORD_HACK_SIZE];
  char *map, *curs;
};

class articleMap {
	
public:
  articleMap();
  ~articleMap();
  void load( FILE* in );
  const char* getName( intIndex idx );
  const char* getTitle( intIndex idx );
  int  bValid;
  
protected:
  intOffset  *offset;
  char *map;
  int  size;
};

class wordIndex {
	
public:
  wordIndex();
  ~wordIndex();
  void load( FILE* in );
  listElements* getArticles( intIndex idx );
  listElements* getTitles( intIndex idx );
  void  debug();
  int  bValid;
    
protected:
  intIndex*  entry( int idx );
  int  size;
  intOffset  *offset;
  intIndex   *index;
};

class articleIndex {
	
public:
  articleIndex();
  ~articleIndex();
  void load( FILE* in );
  listElements* getWords( intIndex idx );
  listElements* getTitles( intIndex idx );
  int length() {return size;}
  int  bValid;
    
protected:
  intOffset  size;
  intIndex   *index;
  int        *len;
};

#endif /*INDEX_H_*/
