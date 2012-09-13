
//
// History:
//   Sep 12, 2012 tcolar Creation
//
using mongo

**
** DbService
**
const class DbService : Service
{
  const SettingsService settings := Service.find(SettingsService#)
  const Mongo mongo := Mongo(settings.mongoHost, settings.mongoPort)
  const DB db := mongo.start.db("fantorepo")

  override Void onStop()
  {
    mongo.stop
  }
}