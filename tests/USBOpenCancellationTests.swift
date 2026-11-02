import Foundation
import Darwin
@main struct Tests {
 static func main(){
 var m:Int32=0,s:Int32=0;var name=[CChar](repeating:0,count:128);precondition(openpty(&m,&s,&name,nil,nil)==0);let path=String(cString:name);close(s);_ = fcntl(m,F_SETFL,O_NONBLOCK)
 let started=DispatchSemaphore(value:0),release=DispatchSemaphore(value:0),closed=DispatchSemaphore(value:0)
 let usb=USBStatus(portsProvider:{[path]},openProvider:{p in started.signal();release.wait();return Darwin.open(p,O_RDWR|O_NOCTTY|O_NONBLOCK)})
 usb.event={e in if e["type"] as? String=="closed"{closed.signal()}}
 usb.connect(path:path,request:1);precondition(started.wait(timeout:.now()+2) == .success)
 usb.disconnect(request:2);let start=Date();usb.shutdown();precondition(Date().timeIntervalSince(start)<0.5,"Quit blocked on opening")
 release.signal();precondition(closed.wait(timeout:.now()+2) == .success);var b=[UInt8](repeating:0,count:10);precondition(read(m,&b,10)<=0,"Canceled open sent a command");close(m)
 print("Blocked-open checks passed: shutdown stays responsive; canceled delayed open sends no startup or movement command. No hardware access.")
 }
}
