
//
// History:
//   Aug 30, 2012 tcolar Creation
//
using mongo
using fanr

**
** MongoUtils
**
class MongoUtils
{
  ** Do an atomic increment/decrement on a field
  ** It's a bit of a hack, but we can't simply use a fanlink object since we would have to have
  ** a '$inc' named field, which is an illegal field name ... so just building that by hand.
  ** 
  ** Note that incBy can be negative for doing an atomic decrease.
  static Void atomicInc(DB db, Type mongoDocType, Field counterField, Str:Obj? filter, Int incBy := 1)
  {
    collectionName := mongoDocName(mongoDocType)
    doc := doc(counterField.name, doc(Str<|$inc|>, 1))    
    db.collection(collectionName).update(filter, doc, false, false, true)
  }

  ** Just syntax sugar for manually creating mongo docs 
  static Str:Obj? doc(Str name, Obj val)
  {
    Str:Obj? obj := [:]
    obj[name] = val
    return obj        
  }

  ** Using same naming convention as fanlink
  static Str mongoDocName(Type type) {
    return type.pod.name + "_" + type.name
  }
  
  ** Take a standard fan query and build a mongo query object from it
  ** This should be much faster than fetching all and filtering locally as done by query.include
  ** 
  ** TODO: right now it's not very optimized, much of the filtering is done here rather tha building
  ** the exact mongo query to get what we need ... but that's would be lots of work and version would be tricky.
  ** 
  static PodSpec[] runFanrQuery(DB db, Query q, Int numVersions)
  {
    PodSpec[] matches := [,]
    q.parts.each |part|
    {
      // first gather matching pods (either 1 if exact name or many if regex)
      PodInfo[] pods := [,]
      if( ! part.namePattern.contains("*"))
      {
        pod := PodInfo.findOne(db, part.namePattern)
        if(pod != null)
          pods.add(pod)
      }
      else
      {
        regex := Regex.glob(part.namePattern.lower)
        PodInfo.list(db).each | pod |
        {
          if(regex.matches(pod.nameLower))
            pods.add(pod)
        }
      }    
        
      depends := part.version
      pods.each | pod | 
      {
        // Then fetch versions
        PodVersion[] versions := [,]
        if(depends == null)
        {
          // add the latest version only if no specific version asked (optimization))
          version := PodVersion.find(db, pod.name, pod.lastVersion)
          if(version!=null) // should not happen
            versions.add(version)
        }
        else
        {
          // otherwise add all known versions
          versions.addAll(PodVersion.findAll(db, pod.name))
        }
        // Now filter out avvording to version & meta
        cpt := 0
        versions.eachr |PodVersion version -> Str?| // we use eachr to get newest first
        {
          if(cpt >= numVersions) return "done"
          cpt++
          spec := version.asPodSpec
          if(part.includeVersion(spec) && part.includeMetas(spec))
          {
            matches.add(spec)
          }
          return null             
        }
      }        
    }
    return matches
  }
}