using compilerDoc::DocEnv
using compilerDoc::DocSpace
using compilerDoc::DocTheme
using compilerDoc::UnknownDocErr
using compilerDoc

internal const class FandocEnv : DefaultDocEnv {
	override DocTheme theme() { FandocTheme() }
		
	override Uri linkUri(DocLink link) {
		s := StrBuf()

		if (Utils.standardPods.contains(link.target.space.spaceName)) {
			s.add("http://www.fantom.org/doc/")
			s.add(link.target.space.spaceName).add("/")
			
		} else {
			// I don't expect fantorepo302 to write any top indexes, but just in case...
			if (link.from.isTopIndex)
				s.add(link.target.space.spaceName).add("/")
			else if (link.from.space !== link.target.space)
				s.add("../").add(link.target.space.spaceName).add("/")
		}
		
		docName := link.target.docName
		if (docName == "pod-doc")
			docName = "index"
		
		s.add(docName)
		
		ext := linkUriExt
		if (ext != null)
			s.add(ext)
		
		if (link.frag != null)
			s.add("#").add(link.frag)
		
		return s.toStr.toUri
	}	
}
