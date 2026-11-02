import Foundation
@main struct Tests {
 static func main()throws{
 let original=SettingsBackup(labels:(1...16).map{"Memory \($0)"},view:"mini",light:true)
 let data=try JSONEncoder().encode(original);let restored=try JSONDecoder().decode(SettingsBackup.self,from:data);try restored.validate();precondition(restored.memoryLabels==original.memoryLabels && restored.view=="mini" && restored.light)
 let base=try JSONSerialization.jsonObject(with:data) as! [String:Any]
 for (key,value) in [("version",2 as Any),("memoryLabels",["short"] as Any),("view","unknown" as Any),("limits",["C":99999,"L":9200] as Any)]{var bad=base;bad[key]=value;do{let decoded=try JSONDecoder().decode(SettingsBackup.self,from:JSONSerialization.data(withJSONObject:bad));try decoded.validate();preconditionFailure("Invalid backup accepted")}catch{}}
 print("Settings backup checks passed: JSON round-trip, 16 names, presentation, unsupported version, missing names, invalid view and altered limits.")
 }
}
