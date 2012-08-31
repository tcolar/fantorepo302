
//
// History:
//   Aug 27, 2012 tcolar Creation
//
using fanr
using mongo

**
** FantoRepoAuth
** Authentication / permissions for the repo (via fanr command)
**
internal const class FantoRepoAuth : WebRepoAuth
{
  const DB db
  
  new make()
  {
    Mongo mongo := Service.find(Mongo#)
    this.db = mongo.db("fantorepo")
  }

  override Obj? user(Str username) 
  { 
    echo("Getting instance for user : $username")
    return username == this.username ? this : null 
  }

  override Buf secret(Obj? user, Str algorithm)
  {
    if (user != this) throw Err("Invalid user: $user")
      switch (algorithm)
    {
      case "PASSWORD":
        return Buf().print(password)
      case "SALTED-HMAC-SHA1":
        return Buf().print("$username:$userSalt").hmac("SHA-1", password.toBuf)
      default:
        throw Err("Unexpected secret algorithm: $algorithm")
    }
  }

  override Str? salt(Obj? user) 
  { 
    user != null ? userSalt : null 
  }

  override Str[] secretAlgorithms() 
  { 
    ["PASSWORD", "SALTED-HMAC-SHA1"] 
  }

  override Bool allowQuery(Obj? u, PodSpec? p) 
  { 
    if(p != null)
    {
      pod := PodInfo.find(db, p.name)
      if(pod == null)
        return false
      if(pod.isPrivate)
        return pod.owner == username
    }  
    return true
  }
  
  override Bool allowRead(Obj? u, PodSpec? p) 
  {
    if(p != null)
    {
      pod := PodInfo.find(db, p.name)
      if(pod == null)
        return false
      if(pod.isPrivate)
        return pod.owner == username
    }  
    return true
  }
  
  override Bool allowPublish(Obj? u, PodSpec? p) 
  {
    // Need valid user/password to publish
    if(username == null)
      throw Err("You need to provide a valid username and password to publish.")
      
    if(p != null)
    {  
      // wil throw a descriptive Err if not valid  
      validateSpec(p)
 
      pod := PodInfo.find(db, p.name)
      if(pod != null && pod.owner != username)
        throw Err("There is already a pod named $p.name in the repository by a different owner. Note that it might not show if it's private)")  
      version := PodVersion.find(db, p.name, p.version.toStr)
      if(version != null)
        throw Err("There is already a pod of that name and version ($p) in the repository. Note that it might not show it's private")      
    }
    
    return true
  }

  ** Validate the pod spec (upon publish)
  ** Throw descriptive errors if validation fails
  Void validateSpec(PodSpec p)
  {
    if( ! checkStr(p.name) || Utils.standardPods.contains(p.name))
      throw Err("Invalid pod name")
    if( ! checkStr(p.version.toStr))
      throw Err("A pod version is required ('version' build.fan)")
    if( ! checkStr(p.summary))
      throw Err("A pod summary is required ('summary' build.fan)")
    if( ! checkStr(p.meta["vcs.uri"]) && ! checkStr(p.meta["org.uri"]))
      throw Err("Either vcs.uri or org.uri entries are required (in meta of build.fan)")
    if( ! checkStr(p.meta["license.name"]))
      throw Err("A license.name entry required (in meta  build.fan)")            
  }
  
  ** check not null and at least one char in that str 
  Bool checkStr(Str? str)
  {
    str != null && str.size()> 1
  }

  private const Str? username := "TODO"
  private const Str userSalt := "TODO"
  private const Str password := "TODO"
}