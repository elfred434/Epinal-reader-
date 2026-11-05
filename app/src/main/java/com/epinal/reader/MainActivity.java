package com.epinal.reader;

import android.app.*;
import android.content.*;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.provider.OpenableColumns;
import android.database.Cursor;
import android.view.*;
import android.webkit.*;
import android.widget.*;
import org.json.*;
import org.w3c.dom.*;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.zip.*;

public class MainActivity extends Activity {
    private static final int PICK = 42, INK = Color.rgb(32,42,37), GREEN = Color.rgb(65,87,68), PAPER = Color.rgb(247,246,240);
    private static final long MAX_BOOK = 100L * 1024 * 1024, MAX_ENTRY = 20L * 1024 * 1024;
    private final String origin = "https://epub.local/";
    private android.content.SharedPreferences prefs;
    private LinearLayout root, content, top;
    private WebView web;
    private Book current;
    private int chapter = 0, font = 110, theme = 0, restoreY = 0;
    private boolean reading = false;
    private JSONArray books;

    static class Book { String id, title, author; ArrayList<String> chapters = new ArrayList<>(); HashMap<String,String> titles = new HashMap<>(); File file; }
    @Override public void onCreate(Bundle b) { super.onCreate(b); prefs = getSharedPreferences("epinal", MODE_PRIVATE); font = prefs.getInt("font",110); theme = prefs.getInt("theme",0); try { books = new JSONArray(prefs.getString("books","[]")); } catch(Exception e) { books = new JSONArray(); } showLibrary(); }
    int dp(float n) { return (int)(n * getResources().getDisplayMetrics().density + .5f); }
    GradientDrawable shape(int c, int radius) { GradientDrawable d = new GradientDrawable(); d.setColor(c); d.setCornerRadius(dp(radius)); return d; }
    TextView text(String s, int size, int color, boolean bold) { TextView v = new TextView(this); v.setText(s); v.setTextSize(size); v.setTextColor(color); if(bold) v.setTypeface(Typeface.DEFAULT,Typeface.BOLD); return v; }
    Button button(String title, boolean filled) { Button b = new Button(this); b.setText(title); b.setTextSize(13); b.setAllCaps(false); b.setTextColor(filled ? Color.WHITE : GREEN); b.setBackground(shape(filled ? GREEN : 0xffe9eee7, 12)); b.setPadding(dp(12),0,dp(12),0); return b; }
    LinearLayout row() { LinearLayout l = new LinearLayout(this); l.setOrientation(LinearLayout.HORIZONTAL); l.setGravity(Gravity.CENTER_VERTICAL); return l; }
    void base() { root = new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setBackgroundColor(PAPER); setContentView(root); }
    void pad(LinearLayout l,int x,int y) { l.setPadding(dp(x),dp(y),dp(x),dp(y)); }
    void message(String s) { Toast.makeText(this,s,Toast.LENGTH_LONG).show(); }
    void saveBooks() { prefs.edit().putString("books",books.toString()).apply(); }
    @Override protected void onPause() { super.onPause(); savePosition(); }
    void savePosition() { if(reading && current != null && web != null) prefs.edit().putInt(current.id+".chapter",chapter).putInt(current.id+".scroll",web.getScrollY()).apply(); }
    void showLibrary() {
        savePosition(); reading=false; if(web!=null) { web.destroy(); web=null; } current=null; base();
        LinearLayout head = new LinearLayout(this); head.setOrientation(LinearLayout.VERTICAL); pad(head,24,24); head.setBackgroundColor(INK); root.addView(head);
        TextView brand=text("ÉPINAL  /  LECTEUR EPUB",11,0xffb8c9b2,true); brand.setLetterSpacing(.12f); head.addView(brand);
        TextView title=text("Votre bibliothèque",28,Color.WHITE,true); LinearLayout.LayoutParams tp=new LinearLayout.LayoutParams(-1,-2); tp.topMargin=dp(16); head.addView(title,tp);
        TextView sub=text("Un peu de temps pour soi, une page à la fois.",14,0xffcbd5ca,false); LinearLayout.LayoutParams sp=new LinearLayout.LayoutParams(-1,-2); sp.topMargin=dp(6); head.addView(sub,sp);
        LinearLayout tools=row(); pad(tools,20,18); root.addView(tools);
        TextView count=text(books.length()+" LIVRE"+(books.length()>1?"S":""),12,GREEN,true); count.setLetterSpacing(.08f); tools.addView(count,new LinearLayout.LayoutParams(0,-2,1));
        Button add=button("+  Importer un EPUB",true); tools.addView(add,new LinearLayout.LayoutParams(-2,dp(46))); add.setOnClickListener(v -> pick());
        EditText search=new EditText(this); search.setSingleLine(); search.setTextSize(15); search.setHint("Rechercher un titre ou un auteur"); search.setPadding(dp(14),0,dp(14),0); search.setBackground(shape(Color.WHITE,12)); LinearLayout.LayoutParams ep=new LinearLayout.LayoutParams(-1,dp(48)); ep.setMargins(dp(20),0,dp(20),dp(12)); root.addView(search,ep);
        ScrollView scroll=new ScrollView(this); root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1)); content=new LinearLayout(this); content.setOrientation(LinearLayout.VERTICAL); pad(content,20,0); scroll.addView(content); renderBooks("");
        search.addTextChangedListener(new android.text.TextWatcher() { public void beforeTextChanged(CharSequence s,int st,int c,int a){} public void onTextChanged(CharSequence s,int st,int before,int c){renderBooks(s.toString());} public void afterTextChanged(android.text.Editable e){} });
        TextView footer=text("VOTRE ESPACE DE LECTURE PERSONNEL",10,0xff89958a,true); footer.setGravity(Gravity.CENTER); footer.setLetterSpacing(.1f); footer.setPadding(0,dp(14),0,dp(20)); root.addView(footer);
    }
    void renderBooks(String query) {
        content.removeAllViews(); int shown=0;
        for(int i=books.length()-1;i>=0;i--) { JSONObject item=books.optJSONObject(i); if(item==null) continue; String title=item.optString("title"), author=item.optString("author"), id=item.optString("id"); if(!(title+" "+author).toLowerCase(Locale.ROOT).contains(query.toLowerCase(Locale.ROOT))) continue; shown++;
            LinearLayout card=row(); pad(card,14,14); card.setBackground(shape(Color.WHITE,16)); LinearLayout.LayoutParams cp=new LinearLayout.LayoutParams(-1,-2); cp.bottomMargin=dp(10); content.addView(card,cp);
            TextView cover=text("▤",30,0xffe8eee5,true); cover.setGravity(Gravity.CENTER); cover.setBackground(shape(GREEN,9)); card.addView(cover,new LinearLayout.LayoutParams(dp(58),dp(76)));
            LinearLayout info=new LinearLayout(this); info.setOrientation(LinearLayout.VERTICAL); info.setPadding(dp(15),0,dp(8),0); card.addView(info,new LinearLayout.LayoutParams(0,-2,1));
            TextView name=text(title,16,INK,true); name.setMaxLines(2); info.addView(name); TextView by=text(author.isEmpty()?"Auteur inconnu":author,13,0xff7e8b7f,false); info.addView(by); TextView status=text(prefs.contains(id+".chapter")?"REPRENDRE LA LECTURE →":"COMMENCER LA LECTURE →",10,GREEN,true); status.setPadding(0,dp(9),0,0); info.addView(status);
            Button more=button("⋮",false); card.addView(more,new LinearLayout.LayoutParams(dp(42),dp(42))); card.setOnClickListener(v -> openBook(id)); more.setOnClickListener(v -> new AlertDialog.Builder(this).setTitle(title).setItems(new String[]{"Lire", "Retirer de la bibliothèque"}, (d,n)-> { if(n==0) openBook(id); else confirmDelete(id,title); }).show());
        }
        if(shown==0) { TextView empty=text(books.length()==0?"Votre prochaine histoire commence ici.\n\nImportez un fichier EPUB depuis votre appareil pour commencer à lire.":"Aucun livre ne correspond à votre recherche.",16,0xff788579,false); empty.setGravity(Gravity.CENTER); empty.setPadding(dp(20),dp(60),dp(20),dp(40)); content.addView(empty); }
    }
    void confirmDelete(String id,String title) { new AlertDialog.Builder(this).setTitle("Retirer ce livre ?").setMessage("« "+title+" » sera supprimé de l’application. Votre fichier original sera conservé.").setNegativeButton("Annuler",null).setPositiveButton("Retirer",(d,w)-> { JSONArray a=new JSONArray(); for(int i=0;i<books.length();i++){ JSONObject o=books.optJSONObject(i); if(o!=null&&!id.equals(o.optString("id"))) a.put(o); } books=a; new File(getFilesDir(),id+".epub").delete(); prefs.edit().remove(id+".chapter").remove(id+".scroll").apply(); saveBooks(); showLibrary(); }).show(); }
    void pick() { Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT); i.addCategory(Intent.CATEGORY_OPENABLE); i.setType("application/epub+zip"); i.putExtra(Intent.EXTRA_MIME_TYPES,new String[]{"application/epub+zip","application/octet-stream"}); try { startActivityForResult(i,PICK); } catch(Exception e) { message("Impossible d’ouvrir le sélecteur de fichiers."); } }
    @Override protected void onActivityResult(int request,int result,Intent data) { super.onActivityResult(request,result,data); if(request!=PICK||result!=RESULT_OK||data==null||data.getData()==null) return; Uri uri=data.getData(); String id=UUID.randomUUID().toString(); File f=new File(getFilesDir(),id+".epub"); try(InputStream in=getContentResolver().openInputStream(uri); OutputStream out=new FileOutputStream(f)) { if(in==null) throw new IOException(); byte[] b=new byte[8192]; long total=0; int n; while((n=in.read(b))!=-1) { total+=n; if(total>MAX_BOOK) throw new IOException("Fichier supérieur à 100 Mo"); out.write(b,0,n); } } catch(Exception e) { f.delete(); message("Import impossible : "+e.getMessage()); return; }
        try { Book b=parseBook(id); JSONObject o=new JSONObject(); o.put("id",id); o.put("title",b.title); o.put("author",b.author); books.put(o); saveBooks(); showLibrary(); message("Livre ajouté à votre bibliothèque."); } catch(Exception e) { f.delete(); message("EPUB illisible ou non pris en charge : "+e.getMessage()); }
    }
    byte[] entry(ZipFile z,String name,long max) throws IOException { ZipEntry e=z.getEntry(name); if(e==null||e.isDirectory()) throw new IOException("Ressource absente"); if(e.getSize()>max) throw new IOException("Ressource trop volumineuse"); try(InputStream in=z.getInputStream(e); ByteArrayOutputStream out=new ByteArrayOutputStream()) { byte[] b=new byte[8192]; int n; long t=0; while((n=in.read(b))!=-1) { t+=n; if(t>max) throw new IOException("Ressource trop volumineuse"); out.write(b,0,n); } return out.toByteArray(); } }
    Document xml(byte[] bytes) throws Exception { DocumentBuilderFactory f=DocumentBuilderFactory.newInstance(); f.setNamespaceAware(true); f.setFeature("http://apache.org/xml/features/disallow-doctype-decl",true); f.setFeature("http://xml.org/sax/features/external-general-entities",false); f.setFeature("http://xml.org/sax/features/external-parameter-entities",false); return f.newDocumentBuilder().parse(new ByteArrayInputStream(bytes)); }
    String first(Document d,String tag) { NodeList a=d.getElementsByTagNameNS("*",tag); return a.getLength()>0?a.item(0).getTextContent().trim():""; }
    String resolve(String base,String href) throws Exception { URI u=new URI(null,null,"/"+base,null).resolve(new URI(href)).normalize(); if(u.isAbsolute() || u.getRawAuthority()!=null) throw new IOException("Lien externe interdit"); String path=u.getPath(); if(path==null||!path.startsWith("/")||path.contains("/../")) throw new IOException("Chemin invalide"); return path.substring(1); }
    Book parseBook(String id) throws Exception { Book book=new Book(); book.id=id; book.file=new File(getFilesDir(),id+".epub"); try(ZipFile z=new ZipFile(book.file)) { Document container=xml(entry(z,"META-INF/container.xml",1024*1024)); NodeList roots=container.getElementsByTagNameNS("*","rootfile"); if(roots.getLength()==0) throw new IOException("Paquet EPUB absent"); String opf=((Element)roots.item(0)).getAttribute("full-path"); Document pkg=xml(entry(z,opf,4*1024*1024)); book.title=first(pkg,"title"); book.author=first(pkg,"creator"); if(book.title.isEmpty()) book.title="Livre sans titre";
        HashMap<String,String> manifest=new HashMap<>(); NodeList items=pkg.getElementsByTagNameNS("*","item"); for(int i=0;i<items.getLength();i++) { Element e=(Element)items.item(i); String type=e.getAttribute("media-type"); if(type.equals("application/xhtml+xml")||type.equals("text/html")) { try { manifest.put(e.getAttribute("id"),resolve(opf,e.getAttribute("href"))); } catch(Exception ignored) {} } }
        NodeList refs=pkg.getElementsByTagNameNS("*","itemref"); for(int i=0;i<refs.getLength();i++) { Element e=(Element)refs.item(i); String path=manifest.get(e.getAttribute("idref")); if(path!=null && z.getEntry(path)!=null) book.chapters.add(path); }
        if(book.chapters.isEmpty()) throw new IOException("Aucun chapitre lisible (DRM non pris en charge)"); return book; } }
    void openBook(String id) { try { current=parseBook(id); chapter=Math.max(0,Math.min(current.chapters.size()-1,prefs.getInt(id+".chapter",0))); restoreY=prefs.getInt(id+".scroll",0); showReader(); } catch(Exception e) { message("Impossible d’ouvrir ce livre : "+e.getMessage()); } }
    void showReader() {
        reading=true; base(); top=row(); pad(top,12,10); top.setBackgroundColor(INK); root.addView(top);
        Button back=button("‹",false); top.addView(back,new LinearLayout.LayoutParams(dp(45),dp(42))); back.setOnClickListener(v->showLibrary());
        TextView name=text(current.title,15,Color.WHITE,true); name.setSingleLine(); name.setEllipsize(android.text.TextUtils.TruncateAt.END); name.setPadding(dp(12),0,dp(6),0); top.addView(name,new LinearLayout.LayoutParams(0,-2,1));
        Button toc=button("☰",false); top.addView(toc,new LinearLayout.LayoutParams(dp(45),dp(42))); toc.setOnClickListener(v->chapterMenu());
        Button settings=button("Aa",false); LinearLayout.LayoutParams ap=new LinearLayout.LayoutParams(dp(48),dp(42)); ap.leftMargin=dp(6); top.addView(settings,ap); settings.setOnClickListener(v->settings());
        web=new WebView(this); web.setBackgroundColor(theme==2?0xff181b19:theme==1?0xfff2e6cf:Color.WHITE); WebSettings s=web.getSettings(); s.setJavaScriptEnabled(false); s.setAllowFileAccess(false); s.setAllowContentAccess(false); s.setAllowFileAccessFromFileURLs(false); s.setAllowUniversalAccessFromFileURLs(false); s.setTextZoom(font); web.setWebViewClient(new ReaderClient()); root.addView(web,new LinearLayout.LayoutParams(-1,0,1));
        LinearLayout nav=row(); pad(nav,16,10); nav.setBackgroundColor(PAPER); root.addView(nav); Button prev=button("← Précédent",false); nav.addView(prev,new LinearLayout.LayoutParams(dp(120),dp(44))); prev.setOnClickListener(v->go(chapter-1)); TextView progress=text((chapter+1)+" / "+current.chapters.size(),12,GREEN,true); progress.setGravity(Gravity.CENTER); nav.addView(progress,new LinearLayout.LayoutParams(0,-2,1)); Button next=button("Suivant →",false); nav.addView(next,new LinearLayout.LayoutParams(dp(110),dp(44))); next.setOnClickListener(v->go(chapter+1)); nav.setTag(progress);
        loadChapter();
    }
    void loadChapter() { if(!reading||web==null)return; LinearLayout nav=(LinearLayout)root.getChildAt(root.getChildCount()-1); ((TextView)nav.getTag()).setText((chapter+1)+" / "+current.chapters.size()); String path=Uri.encode(current.chapters.get(chapter),"/"); web.loadUrl(origin+path); }
    void go(int n) { if(n<0||n>=current.chapters.size()) { message(n<0?"Début du livre":"Fin du livre"); return; } chapter=n; restoreY=0; prefs.edit().putInt(current.id+".chapter",chapter).putInt(current.id+".scroll",0).apply(); loadChapter(); }
    void chapterMenu() { String[] labels=new String[current.chapters.size()]; for(int i=0;i<labels.length;i++) labels[i]="Partie "+(i+1)+" · "+Uri.decode(current.chapters.get(i).substring(current.chapters.get(i).lastIndexOf('/')+1)); new AlertDialog.Builder(this).setTitle("Sommaire des parties").setItems(labels,(d,n)->go(n)).setNegativeButton("Fermer",null).show(); }
    void settings() { String[] choices={"A−  Réduire la taille", "A+  Agrandir la taille", "Thème clair", "Thème sépia", "Thème sombre"}; new AlertDialog.Builder(this).setTitle("Confort de lecture").setItems(choices,(d,n)-> { if(n==0) font=Math.max(70,font-10); if(n==1) font=Math.min(200,font+10); if(n>=2) theme=n-2; prefs.edit().putInt("font",font).putInt("theme",theme).apply(); if(n<2) web.getSettings().setTextZoom(font); else { restoreY=web.getScrollY(); web.setBackgroundColor(theme==2?0xff181b19:theme==1?0xfff2e6cf:Color.WHITE); loadChapter(); } }).setNegativeButton("Fermer",null).show(); }
    class ReaderClient extends WebViewClient {
        @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) { Uri u=req.getUrl(); if(!"https".equals(u.getScheme())||!"epub.local".equals(u.getHost())) return true; String p=u.getPath(); if(p==null)return true; int index=current.chapters.indexOf(p.startsWith("/")?p.substring(1):p); if(index>=0) { chapter=index; restoreY=0; prefs.edit().putInt(current.id+".chapter",chapter).putInt(current.id+".scroll",0).apply(); LinearLayout nav=(LinearLayout)root.getChildAt(root.getChildCount()-1); ((TextView)nav.getTag()).setText((chapter+1)+" / "+current.chapters.size()); return false; } return true; }
        @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) { Uri u=req.getUrl(); if(!"https".equals(u.getScheme())||!"epub.local".equals(u.getHost())||current==null) return blocked(); String p=u.getPath(); if(p==null)return blocked(); p=p.startsWith("/")?p.substring(1):p; if(p.contains("../")||p.startsWith("/"))return blocked(); try(ZipFile z=new ZipFile(current.file)) { byte[] data=entry(z,p,MAX_ENTRY); String lower=p.toLowerCase(Locale.ROOT); String mime=URLConnection.guessContentTypeFromName(lower); if(lower.endsWith(".xhtml")||lower.endsWith(".html")||lower.endsWith(".htm")) { mime="text/html"; String css=theme==2?"html,body{background:#181b19!important;color:#e7e8e1!important} a{color:#b1c8a2!important}":theme==1?"html,body{background:#f2e6cf!important;color:#40362b!important}":"html,body{background:#fff!important;color:#252c27!important}"; String html=new String(data,java.nio.charset.StandardCharsets.UTF_8); String style="<style>"+css+" body{padding:0 1em;line-height:1.6} img{max-width:100%;height:auto}</style>"; int head=html.toLowerCase(Locale.ROOT).indexOf("</head>"); html=head>=0?html.substring(0,head)+style+html.substring(head):style+html; data=html.getBytes(java.nio.charset.StandardCharsets.UTF_8); } if(mime==null) mime="application/octet-stream"; return new WebResourceResponse(mime,mime.startsWith("text/")?"UTF-8":null,new ByteArrayInputStream(data)); } catch(Exception e) { return blocked(); } }
        WebResourceResponse blocked(){return new WebResourceResponse("text/plain","UTF-8",new ByteArrayInputStream(new byte[0]));}
        @Override public void onPageFinished(WebView view,String url) { int y=restoreY; restoreY=0; if(y>0) view.postDelayed(()->{if(reading && web==view)view.scrollTo(0,y);},300); }
    }
    @Override public void onBackPressed() { if(reading) showLibrary(); else super.onBackPressed(); }
}
