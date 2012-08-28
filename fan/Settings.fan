
//
// History:
//   Aug 23, 2012 tcolar Creation
//

**
** RepoSettings
**
@Serializable
const class Settings
{
  const Uri? repoRoot
  const Int listenPort
  const Str mongoHost
  const Int mongoPort
  const Uri publicUri
  
  new make()
  {
    pod := typeof.pod
    r := pod.config("repoRoot")
    if(r == null)
    {
      throw Err("repoRoot not defined ! define it in ${Env.cur.homeDir}/etc/${pod.name}/config.props")
    }
    repoRoot = r.toUri
    file := File(repoRoot).normalize
    if (!file.exists) throw Err("Repo uri does not exist: $file")
    if (!file.isDir)  throw Err("Repo uri is not a directory: $file")
  
    listenPort = pod.config("listenPort", "8100").toInt
    mongoHost = pod.config("mongoHost", "localhost")
    mongoPort = pod.config("mongoPort", "27017").toInt
    publicUri = pod.config("publicUri", "http://127.0.0.1:8080/").toUri.plusSlash
    
    echo(this)
  }
  
  override Str toStr()
  {
    return "Settings{root: $repoRoot, port: $listenPort, 
            mongoHost: $mongoHost, mongoPort: $mongoPort}"
  }
  
  static const Str[] standardPods := ["build", "compiler","compilerDoc","compilerJava",
    "compilerJs","concurrent","doc","dom","email","fandoc","fanr","fansh",
    "flux","fwt","gfx","icons","inet","obix","sql","syntax","sys","util",
    "web","webfwt","webmod","wisp","xml"] 
}