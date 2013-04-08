using compilerDoc::Doc
using compilerDoc::DocChapter
using compilerDoc::DocPodIndex
using compilerDoc::DocRenderer
using compilerDoc::DocSrc
using compilerDoc::DocTheme
using web::WebOutStream
using mustache

internal const class FandocTheme : DocTheme {

	static const Str fandocHeader 	:= Templating.read(`/res/tpl/doc_top.html`)
	static const Str fandocFooter	:= Templating.read(`/res/tpl/doc_bottom.html`)

	
	** Write opening HTML for page.  This should generate the doc type, html, head, and opening body tags.  
	override Void writeStart(DocRenderer r) {		
		render(r.out, fandocHeader, ["title":r.doc.title])
	}
	
	override Void writeBreadcrumb(DocRenderer r) {
		out := r.out
		out.div("class='subHeader'")
		out.div
		writeCrumbs(r)
		out.divEnd
		out.divEnd
		
		// a hack to wrap Manual content in a div to give padding
		if (isManual(r.doc)) {
			out.div("class='manual'")
			out.div
		}		
	}

	** Write closing HTML for page.  This should generate the common footer and close the body and html tags.
	override Void writeEnd(DocRenderer r) {
		render(r.out, fandocFooter)
	}
	
	Void writeCrumbs(DocRenderer r) {
		ext := ".html"
		out := r.out
		doc := r.doc
		out.div("class='breadcrumb'").ul
		
		writeCrumb(out, `index${ext}`, r.doc.space.breadcrumb, doc.isSpaceIndex)
		
		if (doc.isSpaceIndex) {
			// skip
		} else if (doc is DocChapter) {
			writeCrumb(out, `${doc.docName}${ext}`, r.doc.title, true)
			
		} else if (doc is DocSrc) {
			src := (DocSrc)doc
			type := src.pod.type(src.uri.basename, false)
			if (type != null)
				writeCrumb(out, `${doc.docName}${ext}`, type.breadcrumb, true)
			else
				writeCrumb(out, `${doc.docName}${ext}`, src.breadcrumb, true)
			
		} else {
			writeCrumb(out, `${doc.docName}${ext}`, r.doc.breadcrumb, true)
		}

		out.ulEnd.divEnd		
	}

	private Void writeCrumb(WebOutStream out, Uri link, Str text, Bool last) {
		out.span
		out.a(link).w(text).aEnd
		if (!last)
			out.w(" > ")
		out.spanEnd
	}
		
	private static Bool isManual(Doc doc) {
		doc is DocPodIndex && (doc as DocPodIndex).pod.isManual
	}
	
	internal Void render(WebOutStream out, Str template, [Str:Obj]? params := null) {
		out.print(Mustache(template.in).render(params))
	}
}
