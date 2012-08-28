//
// History:
//   Aug 22, 2012 tcolar Creation
//

using concurrent
using fanr
using mongo

**
** FantoRepo implements a repository on the file system using
** a simple directory structure: (where 1.0.0 would be a pod version)
** 
**  - /repo/public/pod1/1.0.0/pod1.pod for public pods
**  - /repo/private/company1/pod1/1.0.1/pod1.pod for private pods
**
** The pods are indexed into MongoDb 
**
const class FantoRepo : Repo
{
  const Log log := Pod.of(FantoRepo#).log
  const File root             // Root directory of the repo
  const DB db
  
  ** Make for given URI which must reference a local dir
  new make(Settings settings)
  {
    echo("make repo")
    this.uri = settings.repoRoot
    this.root = File(uri)
    Mongo mongo := Service.find(Mongo#)
    this.db = mongo.db("fantorepo")
  }

  // ############################## Repo impl #################################
  override const Uri uri  

  override Str:Str ping()
  {
    ["fanr.type":    FantoRepo#.pod.name,
     "fanr.version": FantoRepo#.pod.version.toStr]
  }

  override PodSpec? find(Str name, Version? ver, Bool checked := true)
  {
    echo(">find")

    info := PodInfo.find(db, name)
    PodVersion? pod
    if(info !=null)
    {   
      pod = PodVersion.find(db, name, ver ?: info.lastVersion)
    }
    
    if(pod != null)
    {
      return pod.asPodSpec
    }        
    if (checked) throw UnknownPodErr("$name-$ver")
      return null
  }

  override PodSpec[] query(Str query, Int numVersions := 1)
  {
    echo(">query")
    // TODO: search mongo
    return [,]
  }

  override InStream read(PodSpec spec)
  {
    echo(">read")
    // TODO: send the pod matching the spec
    return "TODO".in
  }

  override PodSpec publish(File podFile)
  {
    throw(Err("test error"))
    PodVersion? podVer 
    
    try
    { 
      Str owner := "TODO" // TODO: user name
    
      spec := PodSpec.load(podFile)    
    
      isPrivate := spec.meta["fantorepo.private"]?.toBool ?: false
      // TODO: private -> different path
    
      // Store the file
      File dest := root + `public/$spec.name/$spec.version/${spec.name}.pod`
      echo(dest.osPath)
      dest.parent.create
      podFile.moveTo(dest)
    
      log.info("Published: $dest.osPath")
      isNew := PodInfo.find(db, spec.name) == null
      info := PodInfo.makeNew(spec, dest, owner) 
 
      // Create the version
      podVer = PodVersion.makeNew(spec, dest, owner)
      podVer.insert(db)
    
      // Update the pod info
      if(isNew)
      {
        info.insert(db)  
      }
      else
      {
        info.update(db)
      }  
    }catch(Err err) 
    {
      log.err("Publishing error: ", err)
    }
   
    // todo: update the depends ? if not a new pod, compare new depends to old depends to update affected items)
    echo("spec: "+podVer?.asPodSpec)
    
    return podVer?.asPodSpec ?: Err("Publish failed.")
  }
  
}