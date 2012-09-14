
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
  const DB db := (Service.find(DbService#) as DbService).db
  const AuthService auth := Service.find(AuthService#)
  const SettingsService settings := Service.find(SettingsService#)
  
  override Obj? user(Str username) 
  { 
    return User.find(db, username)
  }

  override Buf secret(Obj? u, Str algorithm)
  {
    user := u as User

    switch (algorithm)
    {
      case "SALTED-HMAC-SHA1":
        return Buf.fromBase64(user.password)
      default:
        throw Err("Unexpected secret algorithm: $algorithm")
    }
  }

  override Str? salt(Obj? u) 
  { 
    user := u as User
    return user == null ? null : settings.salt.toBuf.hmac("SHA1", user.userName.toBuf).toBase64 
  }

  override Str[] secretAlgorithms() 
  { 
    ["SALTED-HMAC-SHA1"] 
  }

  override Bool allowQuery(Obj? u, PodSpec? p) 
  { 
    user := u as User
    if(p != null)
    {
      pod := PodInfo.findOne(db, p.name)
      if(pod == null)
        return false
      if(pod.isPrivate)
        return pod.owner == user?.userName
    }  
    return true
  }
  
  override Bool allowRead(Obj? u, PodSpec? p) 
  {
    user := u as User
    if(p != null)
    {
      pod := PodInfo.findOne(db, p.name)
      if(pod == null)
        return false
      if(pod.isPrivate)
        return pod.owner == user.userName
    }  
    return true
  }
  
  override Bool allowPublish(Obj? u, PodSpec? p) 
  {
    user := u as User
    // Need valid user/password to publish
    if(u == null)
      throw Err("You Have to provide a valid username and password to publish.")
      
    if(p != null)
    {  
      // wil throw a descriptive Err if not valid  
      isPrivate := p.meta["repo.private"]?.toBool ?: false
      validateSpec(p, isPrivate)
 
      pod := PodInfo.findOne(db, p.name)
      if(pod!=null && (pod.isPrivate != isPrivate))
        throw Err("Not allowing both a public and a private version of the same pod.")          
      if(pod != null && pod.owner != user.userName)
        throw Err("There is already a pod (possibly private) named $p.name in the repository by a different owner.")  
      version := PodVersion.find(db, p.name, p.version.toStr)
      if(version != null)
        throw Err("There is already a pod (possibly private) of that name and version ($p) in the repository.")      
    }
    
    return true
  }

  ** Validate the pod spec (upon publish)
  ** Throw descriptive errors if validation fails
  Void validateSpec(PodSpec p, Bool isPrivate)
  {
    if( ! checkStr(p.name) || Utils.standardPods.contains(p.name))
      throw Err("Invalid pod name")
    if( ! checkStr(p.version.toStr))
      throw Err("A pod version is required ('version' build.fan)")
      
    if( ! isPrivate)
    {  
      if( ! checkStr(p.summary))
        throw Err("A pod summary is required ('summary' build.fan)")
      if( ! checkStr(p.meta["vcs.uri"]) && ! checkStr(p.meta["org.uri"]))
        throw Err("Either vcs.uri or org.uri entries are required (in meta of build.fan)")
      if( ! checkStr(p.meta["license.name"]))
        throw Err("A license.name entry required (in meta  build.fan)")  
    }        
  }
  
  ** check not null and at least one char in that str 
  Bool checkStr(Str? str)
  {
    str != null && str.size()> 1
  }

}