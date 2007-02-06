
// Nombre maximal de résultats affichés lors d'une recherche
var NB_SEARCH_RETURN = 25;
// Score au delà duquel la page s'ouvre automatiquement
var AUTO_OPEN_SCORE = 100;
// Liste des mots recherchés
var listHisto = new Array;
// Si l'historique est à l'écran
var isHistoAffich = false;
// Si recherche est à l'écran
var isSearchAffich = false;
// Is the completion popup open
var popupIsOpen = false;
// Le chemin absolu vers la racine html
var rootPath;
// does the completion popup have the focus
var focusPopup=false;
// structure for the find in page dialog
var findInstData=null;

function getBrowser() {

  return document.getElementById("wk-browser");  
}

const nsIWebProgress = Components.interfaces.nsIWebProgress;
const nsIWebProgressListener = Components.interfaces.nsIWebProgressListener;

function MouseOver(aEvent) {

  var link = aEvent.target;

  if (link instanceof HTMLAnchorElement) {

    if (link.href.indexOf("http://",0)==0) {
     document.getElementById("wk-addressbar").value = link.href;
     setVisible('wk-earth', false);
    }
    if (link.href.indexOf("file://",0)==0)
     document.getElementById("wk-addressbar").value = link.innerHTML;
  }
}

function MouseOut(aEvent) {

  var link = aEvent.target;

  if (link instanceof HTMLAnchorElement) {

    document.getElementById("wk-addressbar").value = "";
    setVisible('wk-earth', true);
  }
}

function Activate(aEvent)
{
  var link = aEvent.target;

  if (link instanceof HTMLAnchorElement) {
    var gzIdx = link.href.indexOf(".gz",0);
    if (gzIdx>=0)
      link.href=link.href.substr(0,gzIdx);
    if ((link.href.indexOf("/desc/",0)>=0)||(link.href.indexOf(".ogg",0)>=0)) {
      // prevent opening image notices when clicking on images.
      aEvent.preventDefault();
      aEvent.stopPropagation();
    } else 
    if (link.href.indexOf("http://",0)==0) {

      // We don't want to open external links in this process: do so in the
      // default browser.
      var ios = Components.classes["@mozilla.org/network/io-service;1"].
        getService(Components.interfaces.nsIIOService);

      var resolvedURI = ios.newURI(link.href, null, null);

      var extps = Components.
        classes["@mozilla.org/uriloader/external-protocol-service;1"].
        getService(Components.interfaces.nsIExternalProtocolService);

      extps.loadURI(resolvedURI, null);
      aEvent.preventDefault();
      aEvent.stopPropagation();
    }
  }
}

function RemoveListener(aEvent) {
  aEvent.target.ownerDocument.removeEventListener("mouseover", MouseOver, true);
  aEvent.target.ownerDocument.removeEventListener("DOMActivate", Activate, true);
  aEvent.target.ownerDocument.removeEventListener("unload", RemoveListener, false);
}

const listener = {
  
  onStateChange: function osc(aWP, aRequest, aStateFlags, aStatus) {
    if (aStateFlags & nsIWebProgressListener.STATE_STOP) {
      Components.utils.reportError("STATE_STOP");
      var myDocument = aWP.DOMWindow.document;
      myDocument.addEventListener("mouseover", MouseOver, true);
      myDocument.addEventListener("mouseout", MouseOut, true);
      myDocument.addEventListener("DOMActivate", Activate, true);
      myDocument.addEventListener("unload", RemoveListener, false);
    }
  },

  QueryInterface: function qi(aIID) {
    if (aIID.equals(nsIWebProgressListener) ||
        aIID.equals(Components.interfaces.nsISupports) ||
        aIID.equals(Components.interfaces.nsISupportsWeakReference)) {
      return this;
    }
    throw Components.results.NS_ERROR_NO_INTERFACE;
  },
};

// Called at startup : asks to wikicomponent the root path to html, and registers the browser
// listener for catching external links
function initRoot() {

  var wikisearch = Components.classes["@linterweb.com/wikicomponent"].getService();
  wikisearch = wikisearch.QueryInterface(Components.interfaces.iWikiSearch);
  rootPath = wikisearch.getRootPath();
  var dls = Components.classes["@mozilla.org/docloaderservice;1"].
  getService(Components.interfaces.nsIWebProgress);
  dls.addProgressListener(listener,
                          nsIWebProgress.NOTIFY_STATE |
                          nsIWebProgress.NOTIFY_STATE_DOCUMENT);
  searchPopupClose();
}

// Rend visible ou invisible un block
function visible(idVisible){
	var objet = document.getElementById(idVisible);
	if(objet.collapsed)
		 setVisible(idVisible, false);
	else
		 setVisible(idVisible, true);
}

function setVisible(idVisible, booleanVisible){
	var objet = document.getElementById(idVisible);
	objet.collapsed = booleanVisible;
	document.getElementById("wk-recherche").focus();
}

// Retour en arrière dans le navigateur
function back() {
	try{
		var browser = document.getElementById("wk-browser");
		browser.stop();
		browser.goBack();
	}catch(e){
		ajouterErreur(e);
		return false;
		dump(e);
	}
	return true;
}

// Page précédente du navigateur
function forward() {
	try{
		var browser = document.getElementById("wk-browser");
		browser.stop();
		browser.goForward();
	}catch(e){
		ajouterErreur(e);
		return false;
		dump(e);
	}
	return true;
}

// Affiche une page dont l'url est transmise
function goTo(url){
	try{
		var browser = document.getElementById("wk-browser");
		browser.loadURI("file://"+rootPath+'/'+url, null, null);
	}catch(e){
		ajouterErreur(e);
		return false;
		dump(e);
	}
}

function deleteListHistory() {

 var desc = document.getElementById("wk-history");
 while ( desc.hasChildNodes() )        
   desc.removeChild( desc.lastChild );
}

// Efface le contenu de la liste
function deleteList(){
        var desc = document.getElementById("wk-vocspe1");
        while ( desc.hasChildNodes() )        
          desc.removeChild( desc.lastChild );

        desc = document.getElementById("wk-vocspe2");
        while ( desc.hasChildNodes() )        
          desc.removeChild( desc.lastChild );

	desc = document.getElementById("wk-resultat");
        while ( desc.hasChildNodes() )        
          desc.removeChild( desc.lastChild );
}

// Adds an entry in the history list (page is the title, chemin is the command to execute)
function addListHistory(page, chemin){

  var l = document.getElementById("wk-history");
  var li = document.createElement("richlistitem");
  var label = document.createElement("label");
  label.setAttribute( "value", page );
  li.setAttribute( "onclick", chemin );
  li.appendChild( label );
  l.appendChild( li );
}

// Adds an entry in the result list (page is the title, chemin is the command to execute, score ...
function addList(page, chemin, score){
	try{
		var l = document.getElementById("wk-resultat");
		var li = document.createElement("richlistitem");
		var lab = document.createElement("vbox");
		var titrescore = document.createElement("stack");
		var scoreslide = document.createElement("hbox");
                var scoreslidef = document.createElement("box");
                var scoreslideb = document.createElement("box");
		var slideWidth = score*2;
		if ( slideWidth > 180 ) slideWidth = 180;
		scoreslideb.setAttribute( "flex", 1 );
                scoreslidef.setAttribute("style", "width:"+slideWidth+"px; margin:1px; height:10px; background-color:#ddf;");
//		var sstext="";
//		for ( var i = 0 ; i < score ; i++ ) sstext += ' ';
//              scoreslidef.setAttribute("value", sstext );
		scoreslide.appendChild(scoreslidef);
		scoreslide.appendChild(scoreslideb);
		titrescore.appendChild(scoreslide);
		var titre = document.createElement("description");
                titrescore.appendChild(titre);
                titre.setAttribute("style", "color:#000;");
		titre.setAttribute("value", ' '+page);
		lab.appendChild(titrescore);
		li.setAttribute("onclick", chemin);
                li.setAttribute( "style", "cursor:pointer;" );
		li.appendChild(lab);
		l.appendChild(li);
	}catch(e){
		ajouterErreur(e);
		return false;
		dump(e);
	}
	return true;
}

// adds the word <mot> in the search text bar
function addword( mot ) {

  var searchbar = document.getElementById("wk-recherche");
  searchbar.value += ' '+mot;
  recherche();
}

// adds the word <mot> in the list of related vocabulary
function addVocSpe( mot ) {

  var desc1 = document.getElementById("wk-vocspe1");
  var desc2 = document.getElementById("wk-vocspe2");
  var entry = document.createElement( "label" );
  entry.setAttribute( "value", '> '+mot );
  entry.setAttribute( "onclick", "javascript:addword('"+mot+"')" );
  entry.setAttribute( "style", "cursor:pointer;" );
  if ( desc1.childNodes.length > desc2.childNodes.length ) 
    desc2.appendChild(entry);
  else desc1.appendChild(entry);
}

// Affichage de l'historique des recherches
function affichHisto(){
	if(!isHistoAffich){
		isHistoAffich = true;
		isSearchAffich = false;
		deleteListHistory();
		setVisible('wk-blockResult', true);
		setVisible('wk-blockHistory', false);
		for(var cle in listHisto){
			addListHistory(cle, listHisto[cle]);
		}
	}else{
		isHistoAffich = false;
		isSearchAffich = true;
		setVisible('wk-blockResult', true);
		setVisible('wk-blockHistory', true);
	}
   textfocus();
}

// Show search result bar
function affichSearch(){

  if ( isSearchAffich )
    setVisible('wk-blockResult', true);
  else {
    setVisible('wk-blockResult', false);
    setVisible('wk-blockHistory', true);
    isHistoAffich=false;
  }
  isSearchAffich = !isSearchAffich;
  textfocus();
}

// close search result bar
function closeSearch(){
	isSearchAffich = false;
	setVisible('wk-blockResult', true);
}

// close history bar
function closeHistory(){
	isHistoAffich = false;
	setVisible('wk-blockHistory', true);
}

// do a search query on word <mot>, put it in the text search bar
function rechercheHistory(mot){
	document.getElementById("wk-recherche").value = mot;
	recherche(mot);
	return true;
}

// do a search query
function recherche(){
  searchPopupClose();
  var mot = document.getElementById("wk-recherche").value;
  mot = mot.toLowerCase();
	
  deleteList();
  rechercheXpcom(mot);
  listHisto[mot] = "javascript:rechercheHistory('"+mot+"');";
  isHistoAffich = false;
  setVisible('wk-blockResult', false);
  setVisible('wk-blockHistory', true);
  document.getElementById("wk-labelSearchHistory").value = "Results";
  isHistoAffich = false;
  return true;
}

// open the "find in page" dialog
function findin() {

  searchPopupClose();
  if ( !findInstData ) {
    findInstData = new nsFindInstData();
    findInstData.browser = getBrowser();
  }
  var lastSearch = document.getElementById("wk-recherche").value;
  var bLastWord = lastSearch.lastIndexOf( " ", lastSearch.length );
  findInstData.webBrowserFind.searchString = lastSearch.substring( bLastWord+1, lastSearch.length );
  findInPage( findInstData );
}

// open the "print" dialog
function print(){
      searchPopupClose();
	try{
		var tt = PrintUtils.print();
		
		//apercu avant impression ==> printPreview();
		//page de modification des marges ==> showPageSetup();
		//getWebBrowserPrint;
	}catch(e){
		ajouterErreur("erreur  " +e);
		return false;
		dump(e);
	}
}

function searchPopupClose() {

  var popup = document.getElementById("wk-searchpopup");
  popup.hidePopup();
  focusPopup=false;
  popupIsOpen=false;
  textfocus();
}

function autoComplete(mot) {

  var textbox = document.getElementById("wk-recherche");
  var text = textbox.value;
  var begin = text.substring(0, text.lastIndexOf(' ', text.length)+1);
  textbox.value = begin+mot;
  
  searchPopupClose();
  recherche();
} 

function searchInput(){

  var textbox = document.getElementById("wk-recherche");
  var text = textbox.value;
  var word = text.substring(text.lastIndexOf(' ', text.length)+1, text.length);
  var wikisearch = Components.classes["@linterweb.com/wikicomponent"].getService();
  wikisearch = wikisearch.QueryInterface(Components.interfaces.iWikiSearch);
  var nCompl = wikisearch.completionStart(word);
  if ( nCompl < 1 ) {
   searchPopupClose();
   return;
  }
  var popup = document.getElementById("wk-searchpopup");
  var popuplist = document.getElementById("wk-searchpopuplist");
  var i;
  popup.showPopup(textbox,-1,-1, "tooltip", "bottomleft", "topleft" );
  popupIsOpen = true;
  if ( nCompl > 12 ) nCompl = 12;
  for ( i = 0 ; i < nCompl ; i++ ) {
 
  	var text = wikisearch.getCompletion(i);
    var popuplistitem = document.getElementById("wk-searchpopuplistI"+i);
    popuplistitem.setAttribute( "label", text );
    popuplistitem.setAttribute( "onclick", "autoComplete('"+text+"');");
    popuplistitem.setAttribute( "value", text);
  }
  for ( ; i < 12 ; i++ ) {
 
    var popuplistitem = document.getElementById("wk-searchpopuplistI"+i);
    popuplistitem.setAttribute( "label", "" );
    popuplistitem.setAttribute( "onclick", "");
    popuplistitem.setAttribute( "value", "");
  }
  textbox.focus();
  popuplist.selectItem(popuplist.getItemAtIndex(0));
}

function popupSelect() {

  var popuplist = document.getElementById("wk-searchpopuplist");
  autoComplete( popuplist.selectedItem.value );
}

function textfocus() {

  document.getElementById("wk-recherche").focus();
}

function popupfocus() {
  
  var popup = document.getElementById("wk-searchpopup");
  var popuplist = document.getElementById("wk-searchpopuplist");
  if ( popupIsOpen ) popuplist.focus();
  focusPopup = true;
}

function browserfocus() {

  var browser = document.getElementById("wk-browser");
  browser.contentWindow.focus();
  focusPopup = false;
}

function enter() {

  if ( !focusPopup ) recherche();
  else popupSelect();
}

function textkeydown(event) {
  
  if ( event.keyCode == 40 ) if ( popupIsOpen ) popupfocus(); else browserfocus();
}

function copy() {

  getBrowser().contentViewerEdit.copySelection();
}

function ajouterErreur(e){
	afficher(e);
}

function afficher(a){
	alert(a);
}

