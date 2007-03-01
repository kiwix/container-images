
function rechercheXpcom(motR){

	var resCount;
	var result0;
	var wikisearch = Components.classes["@linterweb.com/wikicomponent"].getService();
	wikisearch = wikisearch.QueryInterface(Components.interfaces.iWikiSearch);
	resCount = wikisearch.search(motR);
        if ( resCount > NB_SEARCH_RETURN ) resCount = NB_SEARCH_RETURN;
        if ( resCount == 0 ) setVisible( "wk-noresult", false );
        for ( var i = 0 ; i < resCount ; i++ ) {
         var score = wikisearch.getScore(i);
         if (( i == 0 )&&( score > AUTO_OPEN_SCORE )) goTo(wikisearch.getResult(i));
         if ( score < 2 ) break;
         var page = wikisearch.getTitle(i);
         var chemin = "javascript:goTo('"+wikisearch.getResult(i)+"')";
	 addList(page, chemin, score );
        }
        var j = 0;
        for ( var i = 0 ; (i < 25) && (j < 8); i++ ) {

          var word = wikisearch.getVocSpe(i);
          if (( word.length > 5 )
             &&(document.getElementById("wk-recherche").value.indexOf(word,0))==-1) {
            addVocSpe( word );
            j++;
          }
        } 
	return true;
}

