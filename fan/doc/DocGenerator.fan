using compilerDoc
using web
using concurrent
using netColarUtils
using mongo

**
** DocGenerator
** Generate pod documentation
**
const class DocGenerator : Service {
	// TODO: links to sources for bitbucket / github ??
	// TODO: don't check password on publish for now ?
	private static const Log 		log 	:= DocGenerator#.pod.log
	private const Actor generatorPipeline	:= Actor(ActorPool()) |Obj? msg| { generateForPod(msg) }
	private const SettingsService settings	:= Service.find(SettingsService#)
	private const DbService dbSvc			:= Service.find(DbService#)
	private const DB db 					:= dbSvc.db

	new make() {
		dir := File(settings.docRoot)
		if (!dir.exists)
			FileUtils.mkDirs(dir.uri)

		// check if any pods doc need to be regenerated
		PodInfo.list(db).each |pod| {
			if (!upToDate(pod)) {
				podVersion := PodVersion.find(db, pod.name, pod.lastVersion)
				genDoc(podVersion)
			}
		}
	}

	** ensures all doc generation is synchronous
	Void genDoc(PodVersion podVersion) {
		generatorPipeline.send(podVersion).get		
	}

	** Whether a pod doc is up to date or not
	private Bool upToDate(PodInfo pod) {
		versionFile := File(settings.docRoot) + `${pod.name}/version.txt`
		if (!versionFile.exists)
			return false
		return versionFile.readAllStr.trim == pod.lastVersion.trim
	}
	
	private Void generateForPod(PodVersion version) {
		echo("Generating doc for ${version.pod}-$version.name")
		dir := File(settings.docRoot + `${version.pod}/`)
		dir.delete
		docPod := DocPod.load(File.os(version.filePath))
		docEnv := FandocEnv()

		// write out all the docs, including the src files
		docPod.eachDoc |doc| {
			file := File(settings.docRoot + `${version.pod}/${doc.docName}${docEnv.linkUriExt}`)
			FileUtils.mkDirs(file.parent.uri)
			
			out		:= file.out
	        webOut 	:= WebOutStream(out)
			try {
				// do not render pod-doc :: see http://fantom.org/sidewalk/topic/2131
				if (doc.docName == "pod-doc")
					return
				
				rendererType := doc.renderer
				
				// substitute DocTypeRenderers for our own impl
				if (rendererType.fits(DocTypeRenderer#))
					rendererType = DtRenderer#
				
				render := rendererType.method("make").call(docEnv, webOut, doc) as DocRenderer
				render.writeDoc

			} catch (Err e) {
				log.warn("Could not generate docs for '$doc.docName'", e)
				// keep going - don't let a single error prevent other docs from being generated
				
			} finally {		
				webOut.close
				out.close
			}
		}

		File(settings.docRoot + `${version.pod}/version.txt`).open.print(version.name).close
	}
}

internal class DtRenderer : DocTypeRenderer {
	new make(DocEnv env, WebOutStream out, DocType doc) : super(env, out, doc) { }

	override Void writeTypeRef(DocTypeRef ref, Bool full := false) {
		if (ref.isParameterized || !Utils.standardPods.contains(ref.pod))
			return super.writeTypeRef(ref, full)
		
		// send standard pod links to fantom.org
		uri := StrBuf()
		uri.add("http://www.fantom.org/doc/${ref.pod}/${ref.name}")
		uriExt := env.linkUriExt ?: ""
		uri.add(uriExt)

		out	.a(uri.toStr.toUri)
			.w(full ? ref.qname : ref.name)
			.w(ref.isNullable ? "?" : "")
			.aEnd		
	}
	
	static Void main(Str[] args) {
		fwtPod	:= Env.cur.findFile(`lib/fan/fwt.pod`)
		docPod	:= DocPod.load(fwtPod)
		doc		:= docPod.doc("pod-doc")
		docEnv	:= DefaultDocEnv()
		webOut	:= WebOutStream(StrBuf().out)
		render	:= doc.renderer.method("make").call(docEnv, webOut, doc) as DocRenderer

		// render fwt's pod-doc
		render.writeDoc
	}
}

