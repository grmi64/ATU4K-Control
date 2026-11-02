import Foundation
import Darwin

/// Sole USB owner. Status request and explicitly gated jogs only.
/// No arbitrary writes, memory operations, bank writes, retries or replay.
final class USBStatus {
 private let requestLock=NSLock()
 private var desiredRequest=0
 private func want(_ request:Int){requestLock.lock();desiredRequest=request;requestLock.unlock()}
 private func wanted(_ request:Int)->Bool{requestLock.lock();defer{requestLock.unlock()};return desiredRequest==request}
 private let queue=DispatchQueue(label:"ATU4K.usb-status")
 private var fd:Int32 = -1
 private var timer:DispatchSourceTimer?
 private var original:termios?
 private var exclusive=false
 private var generation=0
 private var gate=MotorGate()
 private var memory=MemoryGate()
 private var controllerReady=false
 private var lineBuffer=""
 private var dropping=false
 private var lastCommand="None"
 private var lastReply="None"
 private var readAny=false
 private var opened:TimeInterval=0
 private let openProvider:(String)->Int32
 private let portsProvider:()->[String]
 init(portsProvider:@escaping ()->[String] = USBStatus.ports,openProvider:@escaping (String)->Int32 = {Darwin.open($0,O_RDWR|O_NOCTTY|O_NONBLOCK)}){self.portsProvider=portsProvider;self.openProvider=openProvider}
 var event:(([String:Any])->Void)?
 static func ports()->[String]{((try? FileManager.default.contentsOfDirectory(atPath:"/dev")) ?? []).filter{$0.hasPrefix("cu.usbserial") || $0.hasPrefix("cu.SLAB_USBtoUART") || $0.hasPrefix("cu.usbmodem")}.sorted().map{"/dev/"+$0}}
 func connect(path:String,request:Int){want(request);queue.async{[self] in guard self.wanted(request) else{return};self.closePort();self.generation=request;let gen=request
  guard self.portsProvider().contains(path) else{self.emit(["type":"error","message":"Select an available USB serial port.","generation":gen]);return}
  self.emit(["type":"opening","generation":gen])
  let handle=self.openProvider(path)
  guard self.wanted(request) else{if handle>=0{_ = Darwin.close(handle)};return}
  guard handle>=0 else{self.fail("Cannot open USB port: "+String(cString:strerror(errno)));return}
  self.fd=handle
  guard flock(handle,LOCK_EX|LOCK_NB)==0,ioctl(handle,TIOCEXCL)==0 else{self.fail("USB port is already in use. Close other controller apps.");return}
  self.exclusive=true
  var settings=termios()
  guard tcgetattr(handle,&settings)==0 else{self.fail("Cannot read USB serial settings.");return}
  self.original=settings;cfmakeraw(&settings)
  settings.c_cflag &= ~tcflag_t(CSIZE|PARENB|CSTOPB|CRTSCTS)
  settings.c_cflag |= tcflag_t(CS8|CLOCAL|CREAD)
  cfsetispeed(&settings,speed_t(B1200));cfsetospeed(&settings,speed_t(B1200))
  guard tcsetattr(handle,TCSANOW,&settings)==0 else{self.fail("Cannot configure USB at 1200 baud.");return}
  // Discard queued input so a previous connection cannot establish this session.
  guard tcflush(handle,TCIFLUSH)==0 else{self.fail("Cannot clear stale USB input.");return}
  guard self.wanted(request) else{self.closePort();return}
  self.lastCommand="Startup status";self.lastReply="None"
  let statusByte:[UInt8]=[0x38]
  let sent=statusByte.withUnsafeBytes{Darwin.write(handle,$0.baseAddress,1)}
  guard sent==1 else{self.fail("Status request failed. Nothing will be retried automatically.");return}
  self.readAny=false;self.opened=Date.timeIntervalSinceReferenceDate
  self.emit(["type":"open","generation":gen])
  let timer=DispatchSource.makeTimerSource(queue:self.queue);self.timer=timer
  timer.schedule(deadline:.now(),repeating:.milliseconds(50))
  timer.setEventHandler{[weak self] in self?.poll(gen)};timer.resume()
 }}
 func enableMotors(C:Int,L:Int,rfOff:Bool,request:Int){queue.async{guard self.wanted(request),request==self.generation,self.fd>=0,self.controllerReady,self.memory.pending==nil else{return};do{try self.gate.arm(C:C,L:L,rfOff:rfOff);self.emit(["type":"motorsEnabled","generation":request,"C":C,"L":L])}catch{self.lockMotors(error.localizedDescription)}}}
 func disableMotors(request:Int){queue.async{guard self.wanted(request),request==self.generation else{return};if self.gate.pending != nil || self.memory.pending != nil {self.fail("Connection closed during movement. Verify position at controller; no stop command was sent.")}else{self.lockMotors("Motor controls disabled.")}}}
 func jog(axis:String,delta:Int,id:Int,request:Int){queue.async{
  guard self.wanted(request),request==self.generation,self.fd>=0,self.controllerReady else{return}
  do{guard self.memory.pending==nil else{throw MotorGate.GateError.invalid};let byte=try self.gate.jog(axis:axis,delta:delta,id:id,now:ProcessInfo.processInfo.systemUptime);self.lastCommand="Jog "+axis+" "+String(delta)+"; expected "+String(self.gate.pending?.target ?? -1);let bytes=[byte];let count=bytes.withUnsafeBytes{Darwin.write(self.fd,$0.baseAddress,1)};guard count==1 else{self.lockMotors("Jog write failed; position uncertain. No retry sent.");return}}catch{self.emit(["type":"jogRejected","generation":request,"busy":self.gate.pending != nil || self.memory.pending != nil,"message":error.localizedDescription])}
 }}
 func enableMemory(_ enabled:Bool,rfOff:Bool,request:Int){queue.async{guard self.wanted(request),request==self.generation,self.fd>=0,self.controllerReady else{return};do{guard self.gate.pending==nil else{throw MotorGate.GateError.invalid};try self.memory.enable(enabled);self.emit(["type":"memoryEnabled","generation":request,"enabled":enabled])}catch{self.emit(["type":"memoryRejected","generation":request,"busy":self.memory.pending != nil || self.gate.pending != nil,"message":error.localizedDescription])}}}
 func selectBank(_ bank:Int,id:Int,request:Int){queue.async{guard self.wanted(request),request==self.generation,self.fd>=0 else{return};do{guard self.gate.pending==nil else{throw MotorGate.GateError.invalid};let byte=try self.memory.select(bank,id:id,now:ProcessInfo.processInfo.systemUptime);self.lastCommand="Select bank "+String(bank);self.writeMemory(byte)}catch{self.emit(["type":"memoryRejected","generation":request,"busy":self.memory.pending != nil || self.gate.pending != nil,"message":error.localizedDescription])}}}
 func recall(bank:Int,slot:Int,id:Int,rfOff:Bool,request:Int){queue.async{guard self.wanted(request),request==self.generation,self.fd>=0 else{return};do{guard self.gate.pending==nil else{throw MotorGate.GateError.invalid};let byte=try self.memory.recall(slot,bank:bank,id:id,rfOff:rfOff,positionsKnown:self.gate.enabled && self.gate.positions.count==2,now:ProcessInfo.processInfo.systemUptime);self.lastCommand="Recall bank "+String(bank)+" slot "+String(slot);self.writeMemory(byte)}catch{self.emit(["type":"memoryRejected","generation":request,"busy":self.memory.pending != nil || self.gate.pending != nil,"message":error.localizedDescription])}}}
 func saveMemory(bank:Int,slot:Int,id:Int,rfOff:Bool,request:Int){queue.async{guard self.wanted(request),request==self.generation,self.fd>=0 else{return};do{guard self.gate.pending==nil,self.gate.enabled else{throw MotorGate.GateError.invalid};let byte=try self.memory.save(slot,bank:bank,id:id,rfOff:rfOff,positions:self.gate.positions,now:ProcessInfo.processInfo.systemUptime);self.lastCommand="Save bank "+String(bank)+" slot "+String(slot);self.writeMemory(byte)}catch{self.emit(["type":"memoryRejected","generation":request,"busy":self.memory.pending != nil || self.gate.pending != nil,"message":error.localizedDescription])}}}
 private func writeMemory(_ byte:UInt8){let bytes=[byte];guard bytes.withUnsafeBytes({Darwin.write(fd,$0.baseAddress,1)})==1 else{fail("Bank/recall write failed; no retry.");return}}
 private func lockMotors(_ message:String){gate.lock();emit(["type":"motorsLocked","generation":generation,"message":message])}
 private func inspect(_ data:Data){for byte in data {guard fd>=0 else{return};
  if byte==13 {let line=lineBuffer;lineBuffer="";if !line.isEmpty{lastReply=String(line.prefix(128))};if dropping{dropping=false;continue};if line=="B1" || line=="B2"{controllerReady=true;do{if try memory.reportedBank(line=="B1" ? 1:2){emit(["type":"bankComplete","generation":generation])}}catch{fail(error.localizedDescription)}}
   let stripped=line.trimmingCharacters(in:.whitespaces)
   if stripped.range(of:"^M[1-8]$",options:.regularExpression) != nil,let number=Int(stripped.dropFirst()){do{try memory.reportedSlot(number,ack:line.hasPrefix(" "))}catch{fail(error.localizedDescription)}}
   if let match=line.range(of:"^[CL] STEPS=[0-9]{1,5}$",options:.regularExpression),match==line.startIndex..<line.endIndex,let axis=line.first,let value=Int(line.split(separator:"=").last ?? "") {
    do{guard memory.pending==nil else{throw MotorGate.GateError.unexpected};if try gate.position(axis:String(axis),value:value){emit(["type":"jogComplete","generation":generation,"C":gate.positions["C"] as Any,"L":gate.positions["L"] as Any])}}catch{fail(error.localizedDescription)}
   }else if line.range(of:"^C=[0-9]{1,5} L=[0-9]{1,5}$",options:.regularExpression) != nil {
    let parts=line.split(separator:" ");let C=Int(parts[0].dropFirst(2)) ?? -1,L=Int(parts[1].dropFirst(2)) ?? -1
    if memory.recalling {let wasSaving=memory.saving;let recalledSlot=memory.recallSlot ?? 0;let recalledBank=memory.bank ?? 0;do{if try memory.reportedPair(C:C,L:L){gate.positions=["C":C,"L":L];emit(["type":wasSaving ? "saveComplete":"recallComplete","generation":generation,"C":C,"L":L,"bank":recalledBank,"slot":recalledSlot])}}catch{fail(error.localizedDescription)}}else if gate.enabled{fail("Unexpected paired position report while motors enabled.")}
   }
  }else if byte==10 && lineBuffer.isEmpty {}else if byte<32 || byte>126 || lineBuffer.count>=128 {lineBuffer="";dropping=true;if gate.enabled{fail("Malformed controller reply; position uncertain.")}}else if !dropping{lineBuffer.append(Character(UnicodeScalar(byte)))}
 }}
 func disconnect(request:Int){want(request);queue.async{self.closePort();self.generation=request;self.emit(["type":"closed","generation":self.generation])}}
 func shutdown(){want(-1);queue.async{self.closePort()}}
 private func poll(_ gen:Int){guard gen==generation,wanted(gen),fd>=0 else{return};var descriptor=pollfd(fd:fd,events:Int16(POLLIN),revents:0)
  if Darwin.poll(&descriptor,1,0)>0 && descriptor.revents & Int16(POLLHUP|POLLERR|POLLNVAL) != 0 {fail("USB device disconnected. Reconnect explicitly when ready.");return}
  var bytes=[UInt8](repeating:0,count:512)
  // Bound work per tick even with a noisy device.
  for _ in 0..<8 {let count=Darwin.read(fd,&bytes,bytes.count);let readError=errno
   if count>0{readAny=true;let data=Data(bytes.prefix(count));emit(["type":"data","generation":gen,"base64":data.base64EncodedString()]);inspect(data);if fd<0{return}}
   else if count<0 && readError != EAGAIN && readError != EWOULDBLOCK && readError != EINTR {fail("USB read failed: "+String(cString:strerror(readError))+" (error "+String(readError)+"). Reconnect explicitly when ready.");return}
   else {break}
  }
  if memory.expired(now:ProcessInfo.processInfo.systemUptime){fail("Bank/recall confirmation timed out. Physical position may be uncertain; no retry or stop sent.")}
  if gate.expired(now:ProcessInfo.processInfo.systemUptime){fail("No matching movement reply. Position uncertain; no retry or return move sent.")}
  if !readAny && Date.timeIntervalSinceReferenceDate-opened>8{fail("No controller reply. Check the selected port and controller power.")}
 }
 private func closePort(){gate.lock();memory.reset();controllerReady=false;lineBuffer="";dropping=false;timer?.cancel();timer=nil;if fd>=0{if var settings=original{_ = tcsetattr(fd,TCSANOW,&settings)};if exclusive{_ = ioctl(fd,TIOCNXCL)};_ = Darwin.close(fd)};fd = -1;original=nil;exclusive=false}
 private func fail(_ message:String){let detail=message+" Last command: "+lastCommand+". Last complete reply: "+lastReply+". No retry sent.";closePort();emit(["type":"error","generation":generation,"message":detail])}
 private func emit(_ payload:[String:Any]){event?(payload)}
}
