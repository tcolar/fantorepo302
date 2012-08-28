
//
// History:
//   Aug 27, 2012 tcolar Creation
//
using fanr
using mongo

**
** FantoRepoAuth
** Authentication / permissions for repo
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
    return true
  }
  
  override Bool allowRead(Obj? u, PodSpec? p) 
  { 
    return true
  }
  
  override Bool allowPublish(Obj? u, PodSpec? p) 
  {
    username ?: throw Err("You need to provide a valid username and password to publish.")
      
    // wil throw a descriptive Err if not valid  
    if(p != null)
      validateSpec(p)
 
    pod := PodInfo.find(db, p.name)
    if(pod != null && pod.owner != username)
      throw Err("There is already a pod named $p.name in the repository by a different owner. Note that it might not show if it's private)")  
    version := PodVersion.find(db, p.name, p.version.toStr)
    if(version != null)
      throw Err("There is already a pod of that name and version ($p) in the repository. Note that it might not show it's private")      
   
    return true
  }

  ** Validate the pod spec (upon publish)
  Void validateSpec(PodSpec p)
  {
    if(p.name.size < 2 || Settings.standardPods.contains(p.name))
      throw Err("Invalid pod name")
    if(p.version.toStr.size < 2)
      throw Err("A pod version is required ('version' build.fan)")
    if(p.summary.size < 2)
      throw Err("A pod summary is required ('summary' build.fan)")
    if(p.meta["vcs.uri"].size < 2 && p.meta["org.uri"].size < 2)
      throw Err("Either vcs.uri or org.uri entries are required (in meta of build.fan)")
    if(p.meta["license.name"].size < 2)
      throw Err("A license.name entry required (in meta  build.fan)")            
  }

  private const Str? username := "test"
  private const Str userSalt := "test"
  private const Str password := "test"
}