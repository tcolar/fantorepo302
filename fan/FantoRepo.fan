//
// History:
//   Aug 22, 2012 tcolar Creation
//

using concurrent
using fanr
using mongo
using fanlink

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
    log.info("Find :  $name - $ver")

    info := PodInfo.findOne(db, name)
    if(info != null)
    { 
      // if no version specified then return latest  
      pod := PodVersion.find(db, name, ver ?: info.lastVersion)
      if(pod != null)
        return pod.asPodSpec
    }
    
    if (checked) throw UnknownPodErr("$name-$ver")
      return null
  }

  ** Numversion: how many versions max to return
  override PodSpec[] query(Str query, Int numVersions := 1)
  {
    log.info("Query : $query")
    q := Query.fromStr(query)
    return MongoUtils.runFanrQuery(db, q, numVersions)
    // note that WebRepoMod with filter this further with auth.allowQuery
    // that means numVersions might not be respected (only if only some versions allowed -> unlikely)
  }

  override InStream read(PodSpec spec)
  {
    log.info("Read : $spec")
    version := PodVersion.find(db, spec.name, spec.version.toStr)

    PodInfo.incFetches(db, version.pod) 
    
    file := File.os(version.filePath)
    // TODO: send the pod matching the spec
    return file.in
  }

  override PodSpec publish(File podFile)
  {
    log.info("Publishing : $podFile")
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
    
      prevInfo := PodInfo.findOne(db, spec.name)
      info := PodInfo.makeNew(spec, dest, owner) 
 
      // Create the version
      podVer = PodVersion.makeNew(spec, dest, owner)
      podVer.insert(db)
    
      log.info("Published: $spec.name - $spec.version.toStr")
      
      // Update the pod info
      if(prevInfo == null)
      { // new
        info.insert(db)  
      }
      else
      { // update
        info.update(db)
      }        
    }catch(Err err) 
    {
      log.err("Publishing error: ", err)
    }
   
    return podVer?.asPodSpec ?: Err("Publish failed.")
  }
  
}