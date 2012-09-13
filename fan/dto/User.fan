
//
// History:
//   Sep 12, 2012 tcolar Creation
//
using fanlink
using mongo

**
** User DTO
**
@Serializable
const class User: MongoDoc
{
  override const ObjectID? _id
  
  ** Username (lower case)
  const Str userName  
  ** Hashed password
  const Str password  
  const Str email
  const Str? website
  ** would be set to true if a temp password was set and not replaced yet by the user
  const Bool rest := false
  
  new make(|This| f) {f(this)}

  Void insert(DB db)
  {
    Operations.insert(db, this)
  }
  
  ** find by username (and password if not null)
  static User? find(DB db, Str name, Str? passwordHash := null)
  {
    filterObj := User {
      userName = name.lower
      password = passwordHash ?: ""
      email = ""
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = passwordHash == null ? [User#userName] : [User#userName, User#password]
    }
    results := Operations.find(db, findFilter)
    return results.isEmpty ? null : results[0]
  }
  
  Void update(DB db)
  {
    filterObj := User {
      it.userName = this.userName
      it.password = this.password
      it.email = this.email
      it.website = this.website
    }
    findFilter := FindFilter {
      filter = filterObj
      interestingFields = [User#userName]
    }
    Operations.update(db, findFilter, this)
  }
  
  override Str toStr()
  {
    return "$userName, $email"
  }                
}