//
// History:
//   Aug 22, 2012 tcolar Creation
//

using draft
using fanr
using mongo
using web
using concurrent
using webmod

**
** Master Server mod
** Route and serve the pages
**
const class FantoServer : DraftMod
{
  const SettingsService settings := SettingsService().start
  const DbService dbSvc := DbService().start
  internal const AuthService auth := AuthService().start
  const Templating tpl := Templating()
  const Mongo mongo := dbSvc.mongo
  const DB db := dbSvc.db

  const Log log := FantoServer#.pod.log

  const DocGenerator docGen := DocGenerator().start

  const WebModWrapper repo := WebModWrapper()

  ** Constructor.
  new make()
  {
    // Will service "standard" fanr REST requests at /fanr/
    subMods = ["fanr": repo,
               // serve generated static pod docs under /doc/
               "doc" : FileMod {file = File(settings.docRoot)}]

    // Rest of web services. Index pages, browsing etc ...
    pubDir = null
    logDir = `./log/`.toFile
    router = Router {
      routes = [
        Route("/", "GET", #index),
        Route("/login", "GET", #login),
        Route("/login", "POST", #ajaxLogin),
        Route("/logout", "GET", #logout),
        Route("/register", "POST", #ajaxRegister),
        Route("/help", "GET", #help),
        Route("/search", "POST", #search),
        Route("/browse", "GET", #listPods),
        Route("/browse/{pod}", "GET", #podInfo),
        Route("/browse/{pod}/{version}", "GET", #versionInfo),
        Route("/mypods", "GET", #myPods),
        Route("/mypods", "POST", #ajaxUpload),
        Route("/get/{pod}/{version}/{file}", "GET", #downloadPod),
        Route("/remove/{pod}", "GET", #removePod),
        Route("/user/{user}", "GET", #user),
      ]
    }
  }

  ** Display index page.
  Void index()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    top := MongoUtils.topPods(db)
    recent := MongoUtils.recentPods(db)
    renderPage(res.out, Templating.home, "Pod repo - home", ["top": top, "recent": recent])
  }

  Void help()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    renderPage(res.out, Templating.help, "Pod repo - help")
  }

  ** Display login page.
  Void login()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    renderPage(res.out, Templating.login, "Pod repo - login")
  }

  ** Process login form if given (ajax)
  Void ajaxLogin()
  {
    form := req.form
    res.headers["Content-Type"] = "text/plain"
    user := auth.login(req, form)
    if(user == null)
    {
      res.statusCode = 500
      res.out.print("Login failed.</br/>Check the username and password").close
    }
    else
    {
      res.statusCode = 200
      res.out.close;
    }
  }

  Void logout()
  {
    auth.logout(req)
    index
  }

  ** Process regsitration form (ajax)
  Void ajaxRegister()
  {
    form := req.form
    errors := auth.validateNewUser(form)
    res.headers["Content-Type"] = "text/plain"
    if(errors.size == 0)
    {
      auth.createUser(form)
      auth.login(req, form) // log in as the user right away
      res.statusCode = 200
      res.out.close;
    }
    else
    {
      res.statusCode = 500
      res.out.print(errors.join("<br/>")).close;
    }
  }

  ** Page listing all the pods
  Void listPods()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    // sorted by name -> keep sorted by last update instead ??
    // TODO: do frontend srting later (jquery ? )
    pods := PodInfo.list(db).dup.sort |a, b| {return a.nameLower.compare(b.nameLower)}

    pods = auth.filterPodList(req, pods)

    renderPage(res.out, Templating.podList, "Pod listing", ["pods" : pods])
  }

  ** Page listing all the pods
  Void myPods()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    pods := PodInfo.listByOwner(db, auth.curUser(req)).dup.sort |a, b| {return a.nameLower.compare(b.nameLower)}
    renderPage(res.out, Templating.myPods, "My pods", ["pods" : pods])
  }

  ** Page about a specific pod
  Void podInfo(Str:Str args)
  {
    pod := PodInfo.findOne(db, args["pod"])
    if(pod == null || ! auth.canSeePod(req, pod))
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

    renderPage(res.out, Templating.pod, "Pod info for : $pod.name", data)
  }

  ** Page about a specific version of a pod
  Void versionInfo(Str:Str args)
  {
    if(! auth.canSeePod(req, PodInfo.findOne(db, args["pod"]))) {notFound; return}

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

    renderPage(res.out, Templating.version, "Version details for : $version.pod - $version.name", data)
  }

  ** "Manual" download of a pod
  Void downloadPod(Str:Str args)
  {
    if(! auth.canSeePod(req, PodInfo.findOne(db, args["pod"]))) {notFound; return}

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

  ** "Manual" download of a pod
  Void removePod(Str:Str args)
  {
    name:= args["pod"]
    pod := PodInfo.findOne(db, name)
    if(pod !=null && pod.isPrivate && auth.isPodOwner(req, pod))
    {
      PodInfo.remove(db, pod.nameLower)
    }
    res.redirect(`/mypods`)
  }

  ** Not found when browsing
  Void notFound()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 404
    renderPage(res.out, Templating.notFound, "Page not found")
  }

  ** Run a search on the pods (name & summary)
  Void search()
  {
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    form := req.form
    query := form["query"]

    log.info("Search for: $query")

    // Warning : list of mongo docs (not a PodInfo list)
    pods := PodInfo.searchPods(db, query)

    pods = pods.findAll |Str:Obj? pod, Int index -> Bool|
    {
      log.info("found: $pod")
      Bool isPrivate := pod["isPrivate"]
      return ! isPrivate || pod["owner"] == auth.curUser(req)?.userName
    }

    Str:Obj? data := [:]
    data["pods"] = pods
    data["query"] = query

    renderPage(res.out, Templating.results, "Search results", data)
  }

  ** Manual pod upload
  Void ajaxUpload()
  {
    user := auth.curUser(req)
    if(user != null)
    {
      Actor.locals["fanr-user"] = user.userName
      now := DateTime.nowTicks.toStr
      f := File(settings.repoRoot) + `tmp/${now}.pod`
      try
      {
        mime := MimeType(req.headers["Content-Type"])
        boundary := mime.params["boundary"] ?: throw IOErr("Missing boundary param: $mime")
        // TODO: should enforce a size limit ?
        WebUtil.parseMultiPart(req.in, boundary) |headers, in|
        {
          out := f.out
          try
            in.pipe(out)
          finally
            out.close
        }
        spec := PodSpec.load(f)
        if(repo.repoMod.auth.allowPublish(user, spec))
        {
          repo.repoMod.repo.publish(f)
        }
        else
        {
          throw Err("Not allowed to publish.")
        }
      }
      catch(Err e)
      {
        e.trace
        res.statusCode = 500
        res.headers["Content-Type"] = "text/html"
        renderPage(res.out, "Error: $e", "Upload Error")
        return
      }
      finally
      {
        if(f.exists) f.delete
      }
    }

    myPods
  }

  Void renderPage(WebOutStream out, Str template, Str title, [Str:Obj]? params := [:])
  {
    user := auth.curUser(req)
    if(user != null)
      params["user"] = user
    tpl.renderPage(out, template, title, params)
  }

  Void user(Str:Str args)
  {
    name := args["user"]
    user := User.find(db, name)
    if(user == null)
    {
      notFound; return;
    }
    res.headers["Content-Type"] = "text/html"
    res.statusCode = 200
    renderPage(res.out, Templating.user, "User", ["user" : user])
  }
}

const class WebModWrapper : WebMod
{
  const WebRepoMod repoMod := WebRepoMod() {
    repo = FantoRepo()
    auth = FantoRepoAuth()
  }

  override Void onService()
  {
    // Stash the user name since FantoRepo.publish does not have access to it otherwise
    username := req.headers["Fanr-Username"]
    Actor.locals["fanr-user"] = username

    repoMod.onService
  }
}