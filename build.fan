
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
    podName = "fantorepo"
    summary = "public fanr repository implementation"
    meta = ["vcs.uri":"http://www.github.com/tcolar/fantorepo/",
	    "license.name":"MIT"]
    depends = ["sys 1.0+", "draft 1.0+", "fanr 1.0+", "concurrent 1.0+", 
                "mongo 1.0+", "fanlink 0.1+", "web 1.0+"]
    srcDirs = [`fan/`, `fan/dto/`]
    resDirs = [`res/css/`]
    version = Version("1.0.0")
  }
}
