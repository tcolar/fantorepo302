//
// History:
//   Aug 22, 2012 tcolar Creation
//

using draft
using fanr
using mongo
using web

**
** Master Server mod
** 
const class FantoServer : DraftMod
{
  static const Settings settings := Settings()
  static const Mongo mongo := Mongo(settings.mongoHost, settings.mongoPort)
  static const DB db := mongo.start.db("fantorepo")
  static const WebRepoMod repoMod := WebRepoMod() {
    repo = FantoRepo(settings)
    auth = FantoRepoAuth("test", "test")
  }
  
  ** Constructor.
  new make()
  {    
    // Will service "standard" fanr REST requests at /fanr/
    subMods = ["fanr": repoMod]
    
    // TODO: submod for browsing ?
    
    // Rest of web services. Index pages, browsing etc ...
    pubDir = null
    logDir = `./log/`.toFile
    router = Router {
      routes = [
        Route("/", "GET", #index),
        Route("/browse", "GET", #listPods), 
        Route("/browse/{pod}", "GET", #podInfo),
        Route("/browse/{pod}/{version}", "GET", #versionInfo),
        Route("/browse/{pod}/{version}/{file}", "GET", #downloadPod),  
      ]
    }
  }

  ** Display index page.
  Void index()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    out := res.out
    Rendering.top(out, "Pod listing")
    out.div("class='span12'")
    .print("TBD")
    .divEnd
    Rendering.bottom(out)
  }

  ** Page listing all the pods
  Void listPods()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    out := res.out
    Rendering.top(out, "Pod listing")
    out.h1.print("Pod listing").h1End
    out.table("class='table table-striped'").tr.th.print("Name").thEnd.th.print("Latest Version")
    .thEnd.th.print("Last Update").thEnd.th.print("Summary").thEnd.trEnd
    PodInfo.list(db).each |info|
    {
      summary := info.summary.size > 80 ? info.summary[0..79] + "..." : info.summary
      out.tr
      .td.a(req.modRel.plusSlash + `$info.name`).print(info.name).aEnd.tdEnd
      .td.a(req.modRel.plusSlash + `$info.name/$info.lastVersion`).print(info.lastVersion).aEnd.tdEnd
      .td.print(DateTime(info.lastModif).toLocale).tdEnd
      .td.print(summary).tdEnd
      .trEnd
    }
    out.tableEnd
    // TODO: private pods
    Rendering.bottom(out)
  }
  
  ** Page about a specific pod
  Void podInfo(Str:Str args)
  {
    pod := PodInfo.find(db, args["pod"])
    if(pod == null)
    {
      notFound
      return
    }  
    // Summary from PodInfo
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    out := res.out
    Rendering.top(out, "Pod info for : $pod.name")
    
    out.h1.print("Pod info for : $pod.name").h1End
    .div("class='alert alert-success'").print("To install the latest version (")
    .a(req.modRel.plusSlash + `$pod.lastVersion`).print(pod.lastVersion).aEnd
    .print(") of this pod, use:").br
    .br.code.b.print("fanr install -r ${settings.publicUri}fanr/ $pod.name").bEnd.codeEnd
    .br.br.print("Or download manually by browsing to a specific version.")
    .divEnd
    
    .div("class='span6'")
    .h4.print("Pod Summary: ").h4End.ul
    .li.b.print("Name: ").bEnd.print(pod.name).liEnd
    .li.b.print("Summary: ").bEnd.print(pod.summary).liEnd
    .li.b.print("Source Control Repo: ").a(pod.vcsUri?.toUri ?: `#`).print(pod.vcsUri).aEnd.bEnd.liEnd
    .li.print("Last Update: ").print(DateTime(pod.lastModif).toLocale).liEnd
    .li.print("Current version: ").a(req.modRel.plusSlash + `$pod.lastVersion`).print(pod.lastVersion).aEnd.liEnd
    .li.print("Published by: ").print(pod.owner).liEnd
    .li.print("# Dependant pods: ").print(pod.nbDependants).liEnd
    .li.print("# Of fetches: ").print(pod.nbFetches).liEnd
    .ulEnd

    // List and link to all versions
    out.h4.print("All versions: ").h4End.ul
    PodVersion.findAll(db, pod.name).each |version|
    {
      out.li.a(req.modRel.plusSlash + `$version.name`).print(version.name).aEnd.liEnd
    }
    out.ulEnd
    .divEnd //span6
        
    // current version infos (PodVersion / pod meta)
    .div("class='span5'")
    versionDetails(out, pod.name, pod.lastVersion)
    out.divEnd
        
    Rendering.bottom(out)
  } 
  
  ** Page about a specific version of a pod
  Void versionInfo(Str:Str args)
  {
    version := PodVersion.find(db, args["pod"], args["version"])
    if(version == null)
    {
      notFound
      return
    }  
    fname := version.filePath.toUri.name
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    out := res.out
    Rendering.top(out, "Details of $version.pod - $version.name")
    out.h1
    .print("Details for ").a(req.modRel.plusSlash+`../`).print(version.pod).aEnd
    .print(" at version $version.name")
    .h1End
    
    .div("class='alert alert-success'").print("To install ").b.print("THIS VERSION ($version.name)")
    .bEnd.print(" of the pod, use:").br
    .br.code.b.print("fanr install -r ${settings.publicUri}fanr/ $version.pod $version.name").bEnd.codeEnd
    .br.br.print("Or download manually here: ")
    .a(req.modRel.plusSlash + `$fname`).print(fname).aEnd
    .divEnd.ul
    
    versionDetails(out, version.pod, version.name)
    
    Rendering.bottom(out)
  } 
  
  ** Part about a version details
  Void versionDetails(WebOutStream out, Str podName, Str podVersion)
  {
    version := PodVersion.find(db, podName, podVersion)
    if(version == null) 
    {
      out.print("Version data missing for $podName - $podVersion").br
      return
    }  
    out.h4.print("Pod Details (Latest version):").h4End.ul
    out.li.print("Size: ").print(version.size.toInt.toLocale("B")).liEnd
    version.meta.each |val, key|
    {
        out.li
        if(key == "pod.depends")
          out.b    
        out.print("${key}: ").print(val)
        if(key == "pod.depends")
          out.bEnd    
        out.liEnd      
    }  
    out.ulEnd
  }
  
  ** "Manual" download of a pod
  Void downloadPod(Str:Str args)
  {
    version := PodVersion.find(db, args["pod"], args["version"])
    if(version == null || version.filePath.toUri.name != args["file"])
    {
      notFound
      return
    }  
    // serve the file
    FileWeblet(File.os(version.filePath)).onService
  } 
  
  ** Not found when browsing
  Void notFound()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 404
    out := res.out
    Rendering.top(out, "Page Not Found")
    out.div("class='span12'")
    .print("This item does not exist.")
    .divEnd
    Rendering.bottom(out) 
  }
}