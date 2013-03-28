
//
// History:
//   Aug 31, 2012 tcolar Creation
//
using mustache
using web

**
** Templating helper to render mustache templates
**
const class Templating
{
  // read templates into memory
  static const Str top := read(`/res/tpl/top.html`)
  static const Str bottom := read(`/res/tpl/bottom.html`)
  static const Str home := read(`/res/tpl/home.html`)
  static const Str login := read(`/res/tpl/login.html`)
  static const Str help := read(`/res/tpl/help.html`)
  static const Str user := read(`/res/tpl/user.html`)
  static const Str notFound := read(`/res/tpl/404.html`)
  static const Str podList := read(`/res/tpl/podlist.html`)
  static const Str myPods := read(`/res/tpl/mypods.html`)
  static const Str pod := read(`/res/tpl/pod.html`)
  static const Str version := read(`/res/tpl/version.html`)
  static const Str results := read(`/res/tpl/results.html`)
  static const Str docTop := read(`/res/tpl/doc_top.html`)
  static const Str docBottom := read(`/res/tpl/doc_bottom.html`)

  const SettingsService settings := Service.find(SettingsService#)

  static Str read(Uri template)
  {
    Templating#.pod.file(template).readAllStr
  }

  ** write the whole page
  Void renderPage(WebOutStream out, Str template, Str title, [Str:Obj]? params := [:])
  {
    params["title"] = title
    params["publicUri"] = settings.publicUri

    // useful lambdas
    params["formatTimestamp"] = formatTimestamp
    params["showMeta"] = showMeta
    params["formatSize"] = formatSize

    render(out, top + template + bottom, params)
  }

  ** write a template, does NOT close the stream
  internal Void render(WebOutStream out, Str template, [Str:Obj]? params := null)
  {
    out.print(Mustache(template.in).render(params))
  }

  // lambda to display nicer looking DateTimes in locale format
  const static Func formatTimestamp := |Str var, |Str->Obj?| context, Func render -> Obj?|
  {
    date := DateTime.fromJava(context(var))
    return date.toLocale("MMM DDD YYYY - hh:mm zzz")
  }

  // lambda to format a size (in B/KB/MB/GB format))
  const static Func formatSize := |Str var, |Str->Obj?| context, Func render -> Obj?|
  {
    Int size := context(var)
    return size.toLocale("B")
  }

  // lambda to show pod meta map as an html list (key : value))
  const static Func showMeta := |Str var, |Str->Obj?| context, Func render -> Obj?|
  {
    map := context(var) as Str:Str
    Str result := ""
    map.each |val, key|
    {
      if(key == "pod.depends")
      {
        // highlight non standard deps
        tmp := ""
        val.split(';').each |dep|
        {
          parts := dep.split(' ')
          name := parts.size > 0 ? parts[0] : ""
          tmp += Utils.standardPods.contains(name) ? "$dep; " : "<b>$dep</b>; "
        }
        val = tmp
      }
      else if(key == "org.uri" && ! val.isEmpty)
      {
        // make org.uri a link
        val = "<a href='$val'>$val</a>"
      }
      result += "<li>${key}: ${val}</li>"
    }
    return result
  }
}