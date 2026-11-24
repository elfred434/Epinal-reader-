'use strict';
let book, rendition, currentLocation = '', currentProgress = 0;
function notify(type, data) { window.chrome.webview.postMessage({type, data}); }
function fail(error) { document.getElementById('message').textContent = 'Impossible d’ouvrir cet EPUB.'; notify('error', String(error && error.message || error)); }
async function openBook(cfi, progress, size=100, theme=0, scrolling=false) {
  currentProgress = Number.isFinite(progress) ? progress : 0;
  try {
    book = ePub('https://epinal.local/book.epub');
    rendition = book.renderTo('viewer', { width: '100%', height: '100%', flow: scrolling ? 'scrolled-doc' : 'paginated', spread: 'none', allowScriptedContent: false });
    rendition.on('relocated', loc => {
      currentLocation = loc.start.cfi;
      if (book.locations.total > 0) currentProgress = Math.max(0, Math.min(1, book.locations.percentageFromCfi(currentLocation) || 0));
      notify('position', { cfi: currentLocation, progress: currentProgress });
    });
    rendition.on('selected', (range, contents) => {
      const text = contents.window.getSelection().toString();
      if (text) notify('selection', { cfi: range, text: text.slice(0, 20000) });
    });
    await book.ready;
    const flatten = (items, depth=0) => items.flatMap(x => [{label: '　'.repeat(depth) + x.label.trim(), href: x.href}, ...flatten(x.subitems || [], depth+1)]);
    notify('toc', flatten(book.navigation.toc || []));
    fontSize(size); setTheme(theme);
    await rendition.display(cfi || undefined);
    document.getElementById('message').textContent = '';
    notify('displayed', null);
    try { await book.locations.generate(1600); if (currentLocation) { currentProgress = book.locations.percentageFromCfi(currentLocation) || 0; notify('position', {cfi:currentLocation, progress:currentProgress}); } } catch(e) { console.warn(e); }
  } catch(e) { fail(e); }
}
function goNext(){ if(rendition) rendition.next().catch(fail); }
function goPrevious(){ if(rendition) rendition.prev().catch(fail); }
function goTo(value){ if(rendition) rendition.display(value).catch(fail); }
function fontSize(value){ if(rendition) rendition.themes.fontSize(value + '%'); }
async function searchBook(query) {
  if (!book || !query) return;
  try {
    let matches = [];
    for (const item of book.spine.spineItems) {
      await item.load(book.load.bind(book));
      matches.push(...item.find(query));
      item.unload();
      if (matches.length >= 100) break;
    }
    notify('search', matches.slice(0,100).map(x => ({label:x.excerpt, href:x.cfi})));
  } catch(e) { notify('error', 'Recherche impossible : ' + String(e)); }
}
window.chrome.webview.postMessage({type:'ready'});

function addHighlight(cfi){ if(rendition) rendition.annotations.highlight(cfi, {}, null, 'epinal-highlight', {'fill':'#f3c957','fill-opacity':'0.4','mix-blend-mode':'multiply'}); }

function removeHighlight(cfi){ if(rendition) rendition.annotations.remove(cfi, 'highlight'); }

function setFlow(mode){ if(rendition) rendition.flow(mode); }
function setTheme(theme){ if(rendition) { const colors = [['#ffffff','#233b2d'],['#f4ecd9','#43372a'],['#202923','#e5eee6'],['#e9e4ce','#343a2e']][theme] || ['#ffffff','#233b2d']; rendition.themes.default({body:{'background':colors[0], 'color':colors[1], 'line-height':theme===3?'1.7':'normal'}}); document.body.style.background = colors[0]; } }
function readPage(){ if(!rendition) return; const contents = rendition.getContents(); const text = contents.map(c => c.document && c.document.body ? c.document.body.innerText : '').join(' ').slice(0,20000); notify('speak',text); }
