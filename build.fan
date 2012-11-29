
//
// History:
//   Aug 22, 2012  tcolar  Creation
//
using build

**
** Build: fantorepo
**
class Build : BuildPod
{
  new make()
  {
    podName = "fantorepo302"
    summary = "Public / private Fantom pod repository."
    meta = ["vcs.uri":"https://bitbucket.org/status302/fantorepo302",
      "license.name":"MIT"]
    depends = ["sys 1.0+", "draft 1.0+", "fanr 1.0+", "concurrent 1.0+",
                "mongo 1.0+", "fanlink 0.1+", "web 1.0+", "mustache 1.0+",
                "compilerDoc 1.0+", "webmod 1.0+", "netColarUtils 1.0+"]
    srcDirs = [`fan/`, `fan/dto/`, `fan/tool/`, `fan/doc/`]
    resDirs = [`res/css/`, `res/tpl/`, `res/js/`]
    version = Version("1.0.9")
  }
}