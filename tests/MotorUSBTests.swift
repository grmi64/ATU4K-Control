import Foundation
import Darwin
@main struct Tests {
 static func main(){
 var m:Int32=0,s:Int32=0;var name=[CChar](repeating:0,count:128);precondition(openpty(&m,&s,&name,nil,nil)==0);let path=String(cString:name);_ = close(s);_ = fcntl(m,F_SETFL,O_NONBLOCK)
 let usb=USBStatus(portsProvider:{[path]}),data=DispatchSemaphore(value:0),armed=DispatchSemaphore(value:0),done=DispatchSemaphore(value:0),reject=DispatchSemaphore(value:0),closed=DispatchSemaphore(value:0),fault=DispatchSemaphore(value:0)
 var faultMessage=""
 usb.event={e in switch e["type"] as? String {case "data":data.signal();case "motorsEnabled":armed.signal();case "jogComplete":done.signal();case "jogRejected":reject.signal();case "closed":closed.signal();case "error":faultMessage=e["message"] as? String ?? "";fault.signal();default:break}}
 func incoming(_ text:String){let b=Array(text.utf8);_ = b.withUnsafeBytes{write(m,$0.baseAddress,b.count)}}
 func outgoing()->[UInt8]{var b=[UInt8](repeating:0,count:64);for _ in 0..<100{let n=read(m,&b,64);if n>0{return Array(b.prefix(n))};usleep(10000)};return []}
 usb.connect(path:path,request:1);precondition(outgoing()==[0x38]);incoming("B1\rM4\r");precondition(data.wait(timeout:.now()+2) == .success);usleep(100000)
 usb.jog(axis:"C",delta:-1,id:1,request:1);precondition(reject.wait(timeout:.now()+2) == .success)
 usb.enableMotors(C:3690,L:2108,rfOff:true,request:1);precondition(armed.wait(timeout:.now()+2) == .success)
 var b=[UInt8](repeating:0,count:64);precondition(read(m,&b,64)<=0,"Enable must not move")
 usb.jog(axis:"C",delta:-1,id:1,request:1);precondition(outgoing()==[0x75]);usb.jog(axis:"L",delta:1,id:2,request:1);precondition(reject.wait(timeout:.now()+2) == .success)
 incoming("C STEPS=36");usleep(100000);incoming("89\r");precondition(done.wait(timeout:.now()+2) == .success)
 usb.jog(axis:"C",delta:-1,id:1,request:1);precondition(reject.wait(timeout:.now()+2) == .success);precondition(read(m,&b,64)<=0,"Duplicate must not replay")
 usb.jog(axis:"L",delta:100,id:2,request:1);precondition(outgoing()==[0x6b]);incoming("L STEPS=2208\r");precondition(done.wait(timeout:.now()+2) == .success)
 usb.jog(axis:"C",delta:100,id:3,request:1);precondition(outgoing()==[0x70]);_ = close(m);precondition(fault.wait(timeout:.now()+2) == .success);precondition(faultMessage.contains("expected 3789"));precondition(faultMessage.contains("Last complete reply: L STEPS=2208"));precondition(faultMessage.contains("No retry sent"))
 usb.disconnect(request:2);precondition(closed.wait(timeout:.now()+2) == .success);usb.shutdown();_ = close(m)
 print("Native motor PTY checks passed: default lock, zero-write enabling, exact fine/coarse bytes, busy/duplicate rejection, fragmented feedback and clean close. No real hardware.")
 }
}
