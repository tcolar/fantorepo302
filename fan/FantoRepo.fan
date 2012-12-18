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
  const SettingsService settings := Service.find(SettingsService#)
  const DB db := (Service.find(DbService#) as DbService).db

  ** Make for given URI which must reference a local dir
  new make()
  {
    this.uri = settings.repoRoot
    this.root = File(uri)
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
    // Note: by the time we get here it has been autenticated and validated by FantomRepoAuth
    owner := Actor.locals["fanr-user"]

    log.info("Publishing : $podFile as $owner")
    PodVersion? podVer

    try
    {
      spec := PodSpec.load(podFile)

      isPrivate := spec.meta["repo.private"]?.toBool ?: false

      // Store the file
      File dest := isPrivate ?
        root + `private/$owner/$spec.name/$spec.version/${spec.name}.pod`
        : root + `public/$spec.name/$spec.version/${spec.name}.pod`

      dest.parent.create
      podFile.copyTo(dest)
      podFile.delete

      prevInfo := PodInfo.findOne(db, spec.name)

      // Create the version
      podVer = PodVersion.makeNew(spec, dest, owner)
      podVer.insert(db)

      log.info("Published: $spec.name - $spec.version.toStr")

      // Update the pod info
      if(prevInfo == null)
      { // new
        info := PodInfo.makeNew(spec, dest, owner)
        info.insert(db)
      }
      else
      { // update
        info := PodInfo.makeNew(spec, dest, owner, prevInfo.nbFetches, prevInfo.nbDependants)
        info.update(db)
      }
    }catch(Err err)
    {
      log.err("Publishing error: ", err)
    }

    return podVer?.asPodSpec ?: Err("Publish failed.")
  }

}