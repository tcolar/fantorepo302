
//
// History:
//   Aug 27, 2012 tcolar Creation
//
using fanr

**
** FantoRepoAuth
** Authentication / permissions for repo
**
internal const class FantoRepoAuth : WebRepoAuth
{
  new make(Str username, Str password)
  {
    this.username = username
    this.userSalt = Buf.random(16).toHex
    this.password = password
  }

  override Obj? user(Str username) 
  { 
    username == this.username ? this : null 
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
    if(u == null)
      // todo: except private pod ?
       return true
    return false 
  }
  
  override Bool allowRead(Obj? u, PodSpec? p) 
  { 
    if(u == null)
       // todo: except private pod ?
       return true
    return false 
  }
  
  override Bool allowPublish(Obj? u, PodSpec? p) 
  {
    return true
    /*if(u == null)
       return false // no publish as a guest
    return true*/ // TODO 
  }

  private const Str username
  private const Str userSalt
  private const Str password
}