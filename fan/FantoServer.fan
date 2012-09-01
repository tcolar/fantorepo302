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
** Route and serve the pages
** 
const class FantoServer : DraftMod
{
  const Settings settings := Settings()
  const Templating tpl := Templating(settings)
  const Mongo mongo := Mongo(settings.mongoHost, settings.mongoPort)
  const DB db := mongo.start.db("fantorepo")
  const WebRepoMod repoMod := WebRepoMod() {
    repo = FantoRepo(settings)
    auth = FantoRepoAuth()
  }
  
  ** Constructor.
  new make()
  {    
    // TODO: check authentication here for get requests to /private ??
    
    // Will service "standard" fanr REST requests at /fanr/
    subMods = ["fanr": repoMod]
    
    // Rest of web services. Index pages, browsing etc ...
    pubDir = null
    logDir = `./log/`.toFile
    router = Router {
      routes = [
        Route("/", "GET", #index),
        Route("/search", "POST", #search), 
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
    tpl.renderPage(res.out, Templating.home, "Pod repo home")
  }

  ** Page listing all the pods
  Void listPods()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    // sorted by name -> keep sorted by last update instead ??
    // TODO: do frontend srting later (jquery ? )
    pods := PodInfo.list(db).dup.sort |a, b| {return a.nameLower.compare(b.nameLower)}
    tpl.renderPage(res.out, Templating.podList, "Pod listing", ["pods" : pods])    
  }
  
  ** Page about a specific pod
  Void podInfo(Str:Str args)
  {
    pod := PodInfo.findOne(db, args["pod"])
    if(pod == null)
    {
      notFound
      return
    }  
    // Summary from PodInfo
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    Str:Obj? data := [:] 
    
    version := PodVersion.find(db, pod.name, pod.lastVersion) // latest
    versions := PodVersion.findAll(db, pod.name).dup.reverse // last modified first
    
    data["pod"] = pod
    data["version"] = version
    data["versions"] = versions
    
    tpl.renderPage(res.out, Templating.pod, "Pod info for : $pod.name", data)  
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
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    Str:Obj? data := [:] 
    
    data["version"] = version
    
    tpl.renderPage(res.out, Templating.version, "Version details for : $version.pod - $version.name", data)  
  } 
  
  ** "Manual" download of a pod
  Void downloadPod(Str:Str args)
  {
    // TODO: deal with private pods, only allow if logged in and owner
    version := PodVersion.find(db, args["pod"], args["version"])
    if(version == null || version.filePath.toUri.name != args["file"])
    {
      notFound
      return
    } 
    
    PodInfo.incFetches(db, version.pod) 
    // serve the file
    FileWeblet(File.os(version.filePath)).onService
  } 
  
  ** Not found when browsing
  Void notFound()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 404
    tpl.renderPage(res.out, Templating.notFound, "Page not found")
  }
  
  ** Run a search on the pods (name & summary)
  Void search()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    form := req.form
    query := form["query"]
    
    pods := PodInfo.searchPods(db, query)
    
    // filter out according to permissions    
    // TODO : specs = specs.findAll |pod| { repoMod.auth.allowQuery(user, pod) }
    Str:Obj? data := [:] 
    data["pods"] = pods
    data["query"] = query
    
    tpl.renderPage(res.out, Templating.results, "Search results", data)  
  }
}