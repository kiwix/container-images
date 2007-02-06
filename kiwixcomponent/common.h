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

#ifndef _COMMON_H_
#define _COMMON_H_

#define WORD_HACK_SIZE 1024

/* Bonus points to a word for being in the title */
#define INTITLE_BONUS 100
#define EXACT_TITLE_BONUS 500

/* 1: remove words ending with a s if the occurence without s exists */
#define PLURAL_REMOVE 1

/* Number of words indexed for one article */
#define WORD_MAX_ARTICLE_VOCAB 300

/* Maximal ratio of words indexed for one article */
#define WORD_MAX_ARTICLE_VOCAB_RATIO 2

/* Maximal number of distinct words in an article. Used in precalculation */
#define ARTICLE_MAX_WORD 10000

/* Maximal number of articles indexed for one word */
#define WORD_MAX_ARTICLE 4000

/* A title word is duplicated TITLE_FACTOR times */
#define TITLE_FACTOR 100

/* Words appearing in more then MAX_WORD_ARTICLE_OCCURENCE of the corpus are not indexed */
#define MAX_WORD_ARTICLE_OCCURENCE 0.75

/* Size of specific vocabulary calculated during a query */
#define SPECIFIC_VOCAB_SIZE 25

/* Number of octets used to store an article number (use with caution !! no check)*/
#define ARTICLE_CODE_SIZE 2

#define WORD_INDEX_FILENAME "word.index"
#define WORD_MAP_FILENAME "word.map"
#define ARTICLE_INDEX_FILENAME "article.index"
#define ARTICLE_MAP_FILENAME "article.map"
 
#endif
