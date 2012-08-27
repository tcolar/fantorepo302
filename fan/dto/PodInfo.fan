
//
// History:
//   Aug 24, 2012 tcolar Creation
//
using fanr
using fanlink
using mongo

**
** PodInfo object
** Top level pod infos
**
const class PodInfo : MongoDoc
{
  override const ObjectID? _id
  
  const Str name
  
  const Str? dirPath // dir of this pod
  
  const Str? lastModif // last time it was updated
  const Str? owner// user that published it
  
  const Str? lastVersion
  
  const Bool? isPrivate := false
 
  const Int? nbFetches := 0// how many times it was pulled
  const Int? nbDependants := 0// how many pods depand on this one
  
  const Str? vcsUri
  const Str? summary
 
  new make(|This| f) {f(this)}

  new makeNew(PodSpec spec, File newFile, Str owner)
  {
      this.name = spec.name
      this.owner = owner
      this.dirPath = newFile.parent.parent.osPath
              
      this.lastModif = DateTime.now.toStr
      
      this.lastVersion = spec.version.toStr   
        
      this.isPrivate = spec.meta["fantorepo.private"]?.toBool ?: false    
      this.vcsUri = spec.meta["vcs.uri"]?.toStr 
      this.summary = spec.summary            
  }
  
  static PodInfo? find(DB db, Str podName)
  {
    filterObj := PodInfo {
      name = podName
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodInfo#name]
    }
    results := Operations.find(db, findFilter)
    return results.isEmpty ? null : results[0]
  }
  
  static PodInfo[] list(DB db)
  {
    return Operations.findAll(db, PodInfo#)
  }
  
  Void update(DB db)
  {
    filterObj := PodInfo {
      it.name = this.name
      it.lastModif = DateTime.now.toStr
      it.lastVersion = this.lastVersion
      it.isPrivate = this.isPrivate
      it.vcsUri = this.vcsUri
      it.summary = this.summary
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [PodInfo#name]
    }
    Operations.update(db, findFilter, this)
  }
  
  Void insert(DB db)
  {
    Operations.insert(db, this)
  }
}