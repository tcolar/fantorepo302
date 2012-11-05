
//
// History:
//   Aug 24, 2012 tcolar Creation
//
using fanr
using fanlink
using mongo

**
** PodInfo object
** Top level pod infos (with individual version as PodVersion#)
**
const class PodInfo : MongoDoc
{
  override const ObjectID? _id

  const Str name
  ** lower case name for searching
  const Str nameLower

  const Str? dirPath // dir of this pod

  const Int? lastModif // last time it was updated
  const Str? owner// user that published it

  const Str? lastVersion

  const Bool? isPrivate := false

  const Str? vcsUri
  const Str? summary

  // Note: we update those 2 via the inc* & dec* static atomic methods and never "manually"
  const Int? nbFetches := 0// how many times it was pulled
  const Int? nbDependants := 0// how many pods depand on this one ... not used yet

  new make(|This| f) {f(this)}

  new makeNew(PodSpec spec, File newFile, Str owner)
  {
      this.name = spec.name
      this.nameLower = spec.name.lower
      this.owner = owner
      this.dirPath = newFile.parent.parent.osPath

      this.lastModif = DateTime.now.toJava

      this.lastVersion = spec.version.toStr

      this.isPrivate = spec.meta["repo.private"]?.toBool ?: false
      this.vcsUri = spec.meta["vcs.uri"]?.toStr
      this.summary = spec.summary
  }

  static PodInfo? findOne(DB db, Str podName)
  {
    pods := find(db, podName)
    return pods.isEmpty ? null : pods[0]
  }

  static PodInfo[] find(DB db, Str podName)
  {
    filterObj := PodInfo {
      nameLower = podName.lower
      name = ""
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodInfo#nameLower]
    }
    return Operations.find(db, findFilter)
  }

  static PodInfo[] list(DB db)
  {
    return Operations.findAll(db, PodInfo#)
  }

  ** Delete  pod and it's version (only allowed via web interface and only for private pods)
  static Void remove(DB db, Str podName)
  {
    // remove vserions first
    PodVersion.findAll(db, podName).each |version|
    {
        PodInfo#.pod.log.info("Removing $version")
        f := File.os(version.filePath)
        // remove whole pod dir
        MongoUtils.remove(db, PodVersion#, ["podLower" : version.podLower, "name" : version.name])
        if(f.exists && f.parent.parent.exists)
          f.parent.parent.delete
    }
    // remove the pod itself
    PodInfo#.pod.log.info("Removing $podName")
    MongoUtils.remove(db, PodInfo#, ["nameLower" : podName.lower])
  }

  static PodInfo[] listByOwner(DB db, User? u)
  {
    if(u == null)
      return [,]

    filterObj := PodInfo {
      owner = u.userName
      nameLower = ""
      name = ""
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodInfo#owner]
    }
    return Operations.find(db, findFilter)
  }

  ** Search pod names and summary (can use patterns)
  ** Because we bypass fanlink we get a plain list as the result (not deserialized back into PodInfo)
  static List searchPods(DB db, Str query)
  {
    return MongoUtils.searchPods(db, query)
  }

  Void update(DB db)
  {
    filterObj := PodInfo {
      it.name = this.name
      it.nameLower = this.nameLower
      it.lastModif = DateTime.now.toJava
      it.lastVersion = this.lastVersion
      it.isPrivate = this.isPrivate
      it.vcsUri = this.vcsUri
      it.summary = this.summary
      it.nbFetches = this.nbFetches
      it.nbDependants = this.nbDependants
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodInfo#nameLower]
    }
    Operations.update(db, findFilter, this)
  }

  Void insert(DB db)
  {
    Operations.insert(db, this)
  }

  static Void incFetches(DB db, Str podName)
  {
    MongoUtils.atomicInc(db, PodInfo#, PodInfo#nbFetches, [PodInfo#name.name : podName])
  }

  static Void incDependants(DB db, Str podName)
  {
    MongoUtils.atomicInc(db, PodInfo#, PodInfo#nbDependants, [PodInfo#name.name : podName])
  }

  static Void decDependants(DB db, Str podName)
  {
    MongoUtils.atomicInc(db, PodInfo#, PodInfo#nbDependants, [PodInfo#name.name : podName], -1)
  }
}