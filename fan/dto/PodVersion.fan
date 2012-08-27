
//
// History:
//   Aug 24, 2012 tcolar Creation
//
using mongo
using fanlink
using fanr

**
** PodVersion
** Specific version of a pod
**
const class PodVersion : MongoDoc
{
  override const ObjectID? _id
  
  ** The pod name tis version is of
  const Str pod
  ** Name of this version. ie: 1.0.0
  const Str? name
  
  const [Str:Str] meta := [:] // fanlink doesn't like nullable maps'
  const Int? size
  const Str? filePath // latest file of this pod 
  
  new make(|This| f) {f(this)}

  new makeNew(PodSpec spec, File newFile, Str owner)
  {
    this.pod = spec.name
    this.name = spec.version.toStr  
    this.meta = spec.meta  
    this.filePath = newFile.osPath              
    this.size = newFile.size 
  }
  
  ** find a specific version of that pod
  static PodVersion? find(DB db, Str podName, Str podVersion)
  {
    filterObj := PodVersion {
      pod = podName
      name = podVersion
      meta = [:]
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodVersion#pod, PodVersion#name]
    }
    results := Operations.find(db, findFilter)
    return results.isEmpty ? null : results[0]
  }

  ** find all versions of that pod
  static PodVersion[] findAll(DB db, Str podName)
  {
    filterObj := PodVersion {
      pod = podName
      meta = [:]
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodVersion#pod]
    }
    return Operations.find(db, findFilter)
  }
  
  Void insert(DB db)
  {
    Operations.insert(db, this)
  }

  PodSpec asPodSpec()
  {
    ps := PodSpec.make(meta, File.os(filePath))
    return ps
  }  
}