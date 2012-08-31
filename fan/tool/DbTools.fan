
//
// History:
//   Aug 31, 2012 tcolar Creation
//

**
** Rebuild the db entries from the given pod of folder of pods(recursively)
**
class RebuildFromPods
{ 
  File f
  
  new make(File f)
  {
    this.f  =f
    doFile(f)
  } 
  
  Void doFile(File f)
  {
    if(f.isDir)
    {
      f.list.each {doFile(it)}
    } 
    else
    {  
      if(f.ext.lower == "pod")
      {
        echo("TODO: Rebuilding entry for: $f.osPath")
      }   
    }      
  }
  
  static Void main()
  {
    File? f 
    if( ! Env.cur.args.isEmpty)
      f = File.os(Env.cur.args[0])
    if(f == null || ! f.exists)
    {
      echo("Need to pass a dir or folder")
      return
    }
    rebuild := RebuildFromPods(f)
  }
}