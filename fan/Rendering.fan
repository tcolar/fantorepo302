
//
// History:
//   Aug 26, 2012 tcolar Creation
//
using web

**
** Rendering
** Html rendeing helper
** TODO: Maybe use mustache instead
**
const class Rendering
{
  ** Top of page, including header, navbar and body start
  static Void top(WebOutStream out, Str title:="")
  {
    // todo: .favIcon(href)
    out.head.title.print(title).titleEnd
    .includeCss(`/pod/${Rendering#.pod.name}/res/css/bootstrap.min.css`)
    .includeCss(`/pod/${Rendering#.pod.name}/res/css/fantorepo.css`)
    .print("""<!--[if lt IE 9]><script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script><![endif]-->""")
    .headEnd
    out.body
    header(out)
    out.div("class='row-fluid'")
  }
  
  ** Header bar (part of top)
  internal static Void header(WebOutStream out)
  {
    out.div("class='navbar navbar-inverse'")
    .div("class='navbar-inner'").div("class='container-fluid'")
    .a(`#`, "class='brand'").print("Pod Repo").aEnd
    .div("class='nav-collapse collapse'").ul("class='nav'")
    .li.a(`/`).print("Home").aEnd.liEnd
    .li.a(`/browse`).print("Browse").aEnd.liEnd
    .ulEnd.divEnd
    .divEnd.divEnd
    .divEnd
  }
  
  ** bottom of page (body closing) and closing of the stream
  static Void bottom(WebOutStream out)
  {
    out.divEnd
    .bodyEnd
    .close
  }
  

}