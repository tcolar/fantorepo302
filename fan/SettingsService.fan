
//
// History:
//   Aug 23, 2012 tcolar Creation
//

**
** RepoSettings
**
const class SettingsService : Service
{
  const Uri? repoRoot
  const Uri? docRoot
  const Int listenPort
  const Str mongoHost
  const Int mongoPort
  const Uri publicUri
  const Str salt // encryption salt

  new make()
  {
    pod := typeof.pod
    r := pod.config("repoRoot")
    if(r == null)
    {
      throw Err("repoRoot not defined ! define it in ${Env.cur.homeDir}/etc/${pod.name}/config.props")
    }
    repoRoot = r.toUri
    docRoot = repoRoot.plusName("docs", true)
    file := File(repoRoot).normalize
    if (!file.exists) throw Err("Repo uri does not exist: $file")
    if (!file.isDir)  throw Err("Repo uri is not a directory: $file")

    listenPort = pod.config("listenPort", "8100").toInt
    mongoHost = pod.config("mongoHost", "localhost")
    mongoPort = pod.config("mongoPort", "27017").toInt
    publicUri = pod.config("publicUri", "http://127.0.0.1:8080/").toUri.plusSlash
    salt = pod.config("salt", "")

    if(salt.size < 40){
      err := Err("We need more salt (config.props)!")
      err.trace
      throw(err)
    }
  }

  override Str toStr()
  {
    return "Settings{root: $repoRoot, port: $listenPort,
            mongoHost: $mongoHost, mongoPort: $mongoPort}"
  }
}