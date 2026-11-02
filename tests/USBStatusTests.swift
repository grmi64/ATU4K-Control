import Foundation
import Darwin
@main struct USBStatusTests {
 static func main(){
 var master:Int32=0,slave:Int32=0;var name=[CChar](repeating:0,count:128)
 precondition(openpty(&master,&slave,&name,nil,nil)==0)
 let path=String(cString:name);_ = close(slave);_ = fcntl(master,F_SETFL,O_NONBLOCK)
 let usb=USBStatus(portsProvider:{[path]});let received=DispatchSemaphore(value:0);let closed=DispatchSemaphore(value:0);let errors=DispatchSemaphore(value:0)
 usb.event={e in if e["type"] as? String=="data" {precondition(e["generation"] as? Int==1);received.signal()};if e["type"] as? String=="closed"{closed.signal()};if e["type"] as? String=="error"{errors.signal()}}
 usb.connect(path:path,request:1)
 var bytes=[UInt8](repeating:0,count:64);var sent=[UInt8]()
 for _ in 0..<100 {let n=read(master,&bytes,64);if n>0{sent += bytes.prefix(n);break};usleep(10000)}
 precondition(sent==[0x38],"Only startup status byte allowed")
 let reply=Array("B1\rM4\r".utf8);_ = reply.withUnsafeBytes{write(master,$0.baseAddress,reply.count)}
 precondition(received.wait(timeout:.now()+2) == .success)
 usleep(100000);let extra=read(master,&bytes,64);precondition(extra<=0,"No additional writes or replay")
 usb.disconnect(request:2);precondition(closed.wait(timeout:.now()+2) == .success)
 usb.connect(path:"/dev/not-allowed",request:3);precondition(errors.wait(timeout:.now()+2) == .success)
 usb.shutdown();_ = close(master)
 print("Native pseudo-terminal checks passed: 1200-baud open, sole status byte, incoming data, explicit close and port allowlist. No hardware access.")
 }
}
