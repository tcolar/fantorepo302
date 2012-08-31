
//
// History:
//   Aug 30, 2012 tcolar Creation
//
using mongo

**
** MongoUtils
**
class MongoUtils
{
  ** Do an atomic increment/decrement on a field
  ** It's a bit of a hack, but we can't simply use a fanlink object since we would have to have
  ** a '$inc' named field, which is an illegal field name ... so just building that by hand.
  ** 
  ** Note that incBy can be negative for doing an atomic decrease.
  static Void atomicInc(DB db, Type mongoDocType, Field counterField, Str:Obj? filter, Int incBy := 1)
  {
    collectionName := mongoDocName(mongoDocType)
    Str:Obj? counter := [:]
    counter[counterField.name] = incBy    
    Str:Obj? doc := [:]
    doc[Str<|$inc|>] = counter
    db.collection(collectionName).update(filter, doc, false, false, true)
  }

  ** Using same naming convention as fanlink
  static Str mongoDocName(Type type) {
    return type.pod.name + "_" + type.name
  }
}