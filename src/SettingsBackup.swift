import Foundation
struct SettingsBackup:Codable {
 let format:String
 let version:Int
 let memoryLabels:[String]
 let view:String
 let light:Bool
 let limits:[String:Int]
 init(labels:[String],view:String,light:Bool){self.format="ATU4K Control settings";version=1;memoryLabels=labels;self.view=view;self.light=light;limits=["C":9555,"L":9200]}
 func validate()throws{
  guard format=="ATU4K Control settings",version==1,memoryLabels.count==16,memoryLabels.allSatisfy({$0.count<=40 && !$0.contains(where:{$0.isNewline || $0.asciiValue.map{$0<32} == true})}),["full","compact","mini"].contains(view),limits==["C":9555,"L":9200] else{throw NSError(domain:"ATU4K",code:1,userInfo:[NSLocalizedDescriptionKey:"This backup has unsupported settings, limits, or format."])}
 }
}
