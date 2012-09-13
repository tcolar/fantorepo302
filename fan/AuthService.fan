
//
// History:
//   Sep 12, 2012 tcolar Creation
//
using mongo
using web

**
** AuthService
**
const class AuthService : Service
{
  const SettingsService settings := Service.find(SettingsService#)
  const Mongo mongo := Mongo(settings.mongoHost, settings.mongoPort)
  const DB db := mongo.start.db("fantorepo")
  
  ** Try to login. return the user, or null if login failed.
  ** If succesful store the user in the session as well
  internal User? login(WebReq req, [Str:Str]? form)
  {
    userName := form["username"]?.lower
    plainPassword := form["password"]
    if(userName == null || plainPassword == null) 
      return null
    userName = userName.lower
    hash := hashPassword(userName, plainPassword)
    user := User.find(db, userName, hash)
    req.session.set("user", user) 
    Pod.of(this).log.info("Login for $userName, Result: $user")
    return user
  }
  
  internal Void logout(WebReq req)
  {
    req.session.set("user", null)
  }
  
  ** Return the currently logged in user. Or null if not logged in
  internal User? curUser(WebReq req)
  {
    return req.session.get("user");
  }
  
  ** reset the password and sends back the plain temp password
  internal Str resetPassword()
  {
    return "TODO"
  }
  
  ** Set a new password
  internal Void updatePassword(Str userName, Str newPass)
  {
    // TODO
  }
  
  internal Bool availableUserName(Str userName)
  {
    user := User.find(db, userName.lower)
    return user == null;
  }
  
  internal Str hashPassword(Str userName, Str password)
  {
    salt := settings.salt.toBuf.hmac("SHA1", userName.toBuf).toBase64 
    // usng same hash metod as fanr (SHA1-MAC)
    return Buf().print("$userName:$salt").hmac("SHA-1", password.toBuf).toBase64
  }

  ** Validate a new user
  internal Str[] validateNewUser([Str:Str]? form)
  {
    if(form == null) 
      return ["Missing form payload !"]
    errors := [,]
    name := form["username"]
    pass := form["password"]
    pass2 := form["password2"]
    email := form["email"]
    site := form["website"]
    if(name==null || name.size < 3) {errors.add("Invalid username")}
    // Lame validation but then agin a real check is a nightmare (crazy spec)
    if(email==null || email.size < 5 || ! email.contains("@")) {errors.add("Invalid email address")}
    if(pass==null || pass.size < 8) {errors.add("Invalid password (too short)")}
    if(pass != pass2) {errors.add("Passwords are not matching")}
    if(site!=null && !site.isEmpty && ! site.startsWith("http://")) {errors.add("Invalid website address")}
  
    if(! availableUserName(name)) {errors.add("This user name is alreday registered")}
  
    return errors
  }
  
  ** Create the user
  internal User createUser([Str:Str] form)
  {
    if( ! validateNewUser(form).isEmpty)
    {
      throw Err("User was not validate properly ! $form");
    }  
      
    user := User()
    {
      userName = form["username"].lower
      password = hashPassword(userName, form["password"])
      email = form["email"]
      website = form["website"]
    }
    user.insert(db);
    return user
  }
}