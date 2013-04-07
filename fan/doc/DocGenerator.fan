// History:
//   11 13 12 tcolar Creation
using compilerDoc
using web
using concurrent
using netColarUtils
using mongo

**
** DocGenerator
** Generate pod documentation
**
const class DocGenerator : Service
{

   // TODO: send standard pods links to fantom.org
   // -> would need to override DocTypeRenderer.writeTypeRef
   // TODO: links to sources for bitbucket / github ??
   // TODO: better styling
   // TODO: don't check password on publish for now ?

  const SettingsService settings := Service.find(SettingsService#)
  const DbService dbSvc := Service.find(DbService#)
  const DB db := dbSvc.db

  const GeneratorActor actor := GeneratorActor(settings)

  new make()
  {
    dir := File(settings.docRoot)
    if(! dir.exists)
      FileUtils.mkDirs(dir.uri)
    // Upon creation check if any pods doc need to be regenerated
    Future? prev
    PodInfo.list(db).each |pod|
      {
      if(! upToDate(pod))
      {
        // do one at a time to limit i/o
        latest := PodVersion.find(db, pod.name, pod.lastVersion)
        prev = genDoc(latest, prev)
      }
    }
  }

  ** Whether a pod doc is up to date or not
  Bool upToDate(PodInfo pod)
  {
    vf := File(settings.docRoot) + `${pod.name}/version.txt`
    if( ! vf.exists)
      return false
    v := vf.readAllStr
    return v.trim == pod.lastVersion.trim
  }

  ** Request doc generation
  Future? genDoc(PodVersion? latest, Future? after := null)
  {
    if(latest != null)
    {
      if(after != null)
        return actor.sendWhenDone(after, latest)
      else
        return actor.send(latest)
    }
    return null
  }


}

const class GeneratorActor : Actor
{
  const SettingsService settings
  const Templating tpl := Templating()

  new make(SettingsService settings) : super.make(ActorPool())
  {
    this.settings = settings
  }

  override Obj? receive(Obj? msg)
  {
    version := msg as PodVersion
    generateForPod(version)
    return null
  }

  Void generateForPod(PodVersion version)
  {
    echo("Generating doc for ${version.pod}-$version.name")
    dir := File(settings.docRoot + `${version.pod}/`)
    dir.delete
    DocPod dp := DocPod.load(File.os(version.filePath))
    env := DefaultDocEnv()

    // Types

    dp.types.each |dt|
    {
      // Note: if type is "Index" and we are on windows it could be overwritten by the index.html
      f := File(settings.docRoot + `${version.pod}/${dt.name}.html`)
        FileUtils.mkDirs(f.parent.uri)
      wos := WebOutStream(f.out)
      tpl.render(wos, Templating.docTop, ["title":"${version.pod}::${dt.name}"])
      dr := DtRenderer(env, wos, dt)
      dr.writeContent
      tpl.render(wos, Templating.docBottom)
      wos.close
    }

    // Index
    File index := dir + `index.html`
        FileUtils.mkDirs(index.parent.uri)
    wos := WebOutStream(index.out)
    tpl.render(wos, Templating.docTop, ["title":"${dp.name}"])
    DocRenderer dr := DocPodIndexRenderer(env, wos, dp.index)
    dr.writeContent
    tpl.render(wos, Templating.docBottom)
    wos.close

    File(settings.docRoot + `${version.pod}/version.txt`).open.print(version.name).close
  }
}

class DtRenderer : DocTypeRenderer
{
  new make(DocEnv env, WebOutStream out, DocType doc) : super(env, out, doc) {}

  // Mostly copied from standard code but sending standard pod links to fantom.org
  override Void writeTypeRef(DocTypeRef ref, Bool full := false)
  {
    if (ref.isParameterized)
    {
      if (ref.qname == "sys::List")
      {
        writeTypeRef(ref.v)
        out.w("[]")
      }
      else if (ref.qname == "sys::Map")
      {
        if (ref.isNullable) out.w("[")
        writeTypeRef(ref.k)
        out.w(":")
        writeTypeRef(ref.v)
        if (ref.isNullable) out.w("]")
      }
      else if (ref.qname == "sys::Func")
      {
        isVoid := ref.funcReturn.qname == "sys::Void"
        out.w("|")
        ref.funcParams.each |p, i|
        {
          if (i > 0) out.w(",")
          writeTypeRef(p)
        }
        if (!isVoid || ref.funcParams.isEmpty)
        {
          out.w("->")
          writeTypeRef(ref.funcReturn)
        }
        out.w("|")
      }
      else throw Err("Unsupported parameterized type: $ref")
      if (ref.isNullable) out.w("?")
    }
    else
    {
      // make link by hand to avoid having to resolve
      // every type to a full fledged Doc instance
      uri := StrBuf()
      if (ref.pod != type.pod.name)
      {
        // Start custom
        if(Utils.standardPods.contains(ref.pod))
          uri.add("http://www.fantom.org/doc/${ref.pod}/")
        else
          uri.add("../").add(ref.pod).add("/")
        // End custom
      }
      uri.add(ref.name)
      uriExt := env.linkUriExt
      if (uriExt != null) uri.add(uriExt)

      out.a(uri.toStr.toUri)
         .w(full ? ref.qname : ref.name)
         .w(ref.isNullable ? "?" : "")
         .aEnd
    }
  }
}

