import Foundation
import IOKit

/// Reads registry descriptors only. Never opens a serial device or probes it.
struct USBDiscovery {
 static func likely(vendor:Int,product:Int)->Bool {vendor==0x10c4 && product==0xea60}
 static func devices()->[[String:Any]] {
  var iterator:io_iterator_t=0
  guard IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching("IOSerialBSDClient"),&iterator)==KERN_SUCCESS else{return USBStatus.ports().map{["path":$0,"likely":false]}}
  defer{IOObjectRelease(iterator)}
  var result=[[String:Any]]();var service=IOIteratorNext(iterator)
  while service != 0 {
   let current=service;defer{IOObjectRelease(current)}
   service=IOIteratorNext(iterator)
   guard let path=IORegistryEntryCreateCFProperty(current,"IOCalloutDevice" as CFString,kCFAllocatorDefault,0)?.takeRetainedValue() as? String,USBStatus.ports().contains(path) else{continue}
   var info:[String:Any]=["path":path,"likely":false];var entry=current;var owned=false
   for _ in 0..<12 {
    for key in ["idVendor","idProduct","USB Product Name","USB Vendor Name","USB Serial Number"] where info[key]==nil {
     if let value=IORegistryEntryCreateCFProperty(entry,key as CFString,kCFAllocatorDefault,0)?.takeRetainedValue(){if let n=value as? NSNumber{info[key]=n.intValue}else if let text=value as? String{info[key]=String(text.prefix(120))}}
    }
    var parent:io_registry_entry_t=0
    let found=IORegistryEntryGetParentEntry(entry,kIOServicePlane,&parent)==KERN_SUCCESS
    if owned{IOObjectRelease(entry)}
    owned=false
    guard found else{break};entry=parent;owned=true
   }
   if owned{IOObjectRelease(entry)}
   info["likely"]=likely(vendor:info["idVendor"] as? Int ?? -1,product:info["idProduct"] as? Int ?? -1)
   result.append(info)
  }
  let present=Set(result.compactMap{$0["path"] as? String})
  for path in USBStatus.ports() where !present.contains(path){result.append(["path":path,"likely":false])}
  return result.sorted{($0["path"] as? String ?? "")<($1["path"] as? String ?? "")}
 }
}
