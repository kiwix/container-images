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

#ifndef LIST_H_
#define LIST_H_


#ifdef XPCOM_BUILD
#include "prtypes.h"
typedef PRInt16 intIndexArticle;
typedef PRInt32 intOffset;
typedef PRInt32 intIndex;
#else
#include "sys/types.h"
typedef int16_t intIndexArticle;
typedef int32_t intOffset;
typedef int32_t intIndex;
#endif

void *gg_malloc( long size );
void gg_free( void *ptr );
	
class listElements {
	
public:
  listElements( int sz );
  ~listElements();
  listElements( listElements* l1, listElements* l2 );
  listElements( listElements* l1, listElements* l2, int type );
  void intersectWith( listElements* l );
  void insertArray( const intIndex* a, intIndex codeStop );
  void insertArrayArticle( const intIndex* a, intIndex codeStop );
  void insertAllArray( const intIndex* a, intIndex exclude );
  void insertAllArrayArticle( const intIndex* a, intIndex exclude );
  void insertAllArray( const intIndex* a, intIndex exclude, intIndex codeStop );  
  void insert( intIndex e );
  void sortElements();
  void sortCounts();
  void setCount( int i, intIndex c );
  intIndex count( int i );
  intIndex element( int i );
  void cut( int i );
  int  length() const {return maxElement;}
  void fillIndexZero();
  void addCount( int idx, int c );
  void cutZero();
  void debug( const char *text );
  
protected:
  int size;
  int maxElement;
  intIndex *list;
  int *len;
};


#endif /*LIST_H_*/
