import Foundation
import Darwin
@main struct Tests {
 static func main(){
 var m:Int32=0,s:Int32=0;var name=[CChar](repeating:0,count:128);precondition(openpty(&m,&s,&name,nil,nil)==0);let path=String(cString:name);_ = close(s);_ = fcntl(m,F_SETFL,O_NONBLOCK)
 let usb=USBStatus(portsProvider:{[path]});let data=DispatchSemaphore(value:0),armed=DispatchSemaphore(value:0),enabled=DispatchSemaphore(value:0),bank=DispatchSemaphore(value:0),done=DispatchSemaphore(value:0),reject=DispatchSemaphore(value:0),fault=DispatchSemaphore(value:0),jog=DispatchSemaphore(value:0)
 usb.event={e in switch e["type"] as? String{case "data":data.signal();case "motorsEnabled":armed.signal();case "memoryEnabled":enabled.signal();case "bankComplete":bank.signal();case "recallComplete","saveComplete":done.signal();case "memoryRejected","jogRejected":reject.signal();case "error":fault.signal();case "jogComplete":jog.signal();default:break}}
 func incoming(_ text:String){let b=Array(text.utf8);_ = b.withUnsafeBytes{write(m,$0.baseAddress,b.count)}}
 func outgoing()->[UInt8]{var b=[UInt8](repeating:0,count:64);for _ in 0..<100{let n=read(m,&b,64);if n>0{return Array(b.prefix(n))};usleep(10000)};return []}
 func silent(){var b=[UInt8](repeating:0,count:64);precondition(read(m,&b,64)<=0,"Unexpected command")}
 usb.connect(path:path,request:1);precondition(outgoing()==[0x38]);incoming("B1\rM4\r");precondition(data.wait(timeout:.now()+2) == .success);usleep(100000)
 usb.selectBank(2,id:1,request:1);precondition(reject.wait(timeout:.now()+2) == .success);silent()
 usb.enableMemory(true,rfOff:true,request:1);precondition(enabled.wait(timeout:.now()+2) == .success);silent()
 usb.selectBank(2,id:1,request:1);precondition(outgoing()==[0x37]);incoming("B2\r");precondition(bank.wait(timeout:.now()+2) == .success)
 usb.recall(bank:2,slot:4,id:2,rfOff:true,request:1);precondition(reject.wait(timeout:.now()+2) == .success);silent()
 usb.enableMotors(C:3690,L:2108,rfOff:true,request:1);precondition(armed.wait(timeout:.now()+2) == .success)
 usb.recall(bank:2,slot:4,id:2,rfOff:true,request:1);precondition(outgoing()==[0x64]);incoming(" M4\r");precondition(done.wait(timeout:.now()+0.15) == .timedOut)
 usb.jog(axis:"C",delta:1,id:9,request:1);precondition(reject.wait(timeout:.now()+2) == .success);silent()
 incoming("M4\rC=36");precondition(done.wait(timeout:.now()+0.15) == .timedOut);incoming("91 L=2109\r");precondition(done.wait(timeout:.now()+2) == .success)
 usb.recall(bank:2,slot:4,id:2,rfOff:true,request:1);precondition(reject.wait(timeout:.now()+2) == .success);silent()
 usb.jog(axis:"C",delta:1,id:10,request:1);precondition(outgoing()==[0x74]);incoming("C STEPS=3692\r");precondition(jog.wait(timeout:.now()+2) == .success)
 usb.saveMemory(bank:2,slot:4,id:3,rfOff:false,request:1);precondition(outgoing()==[0x44]);incoming("M4\rC=3692 L=2109\r");precondition(done.wait(timeout:.now()+2) == .success);silent()
 usb.selectBank(1,id:4,request:1);precondition(outgoing()==[0x36]);incoming("B1\r");precondition(bank.wait(timeout:.now()+2) == .success)
 usb.recall(bank:1,slot:1,id:5,rfOff:true,request:1);precondition(outgoing()==[0x61]);incoming("M2\r");precondition(fault.wait(timeout:.now()+2) == .success)
 usb.shutdown();_ = close(m)
 print("Memory PTY checks passed: enable sends nothing; exact bank/recall bytes; no recall without seeded positions; shared busy lock; fragmented final pair required; post-recall jog synchronized; duplicates/wrong slot rejected. No physical hardware.")
 }
}
