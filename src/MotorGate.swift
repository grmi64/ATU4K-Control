import Foundation
/// No hardware access. One outstanding, explicitly requested jog; no replay.
struct MotorGate {
 var enabled=false
 var positions:[String:Int]=[:]
 var pending:(axis:String,target:Int,deadline:TimeInterval)?
 var lastID=0
 mutating func lock(){enabled=false;positions=[:];pending=nil}
 mutating func arm(C:Int,L:Int,rfOff:Bool)throws {guard pending==nil,rfOff,(0...9555).contains(C),(0...9200).contains(L) else{throw GateError.invalid};positions=["C":C,"L":L];enabled=true}
 mutating func jog(axis:String,delta:Int,id:Int,now:TimeInterval)throws->UInt8 {
  guard enabled,pending==nil,id>lastID,let current=positions[axis],[-100,-1,1,100].contains(delta) else{throw GateError.invalid}
  let max=axis=="C" ? 9555 : 9200;let target=current+delta
  guard (0...max).contains(target) else{throw GateError.limit}
  let commands:[String:[Int:UInt8]]=["C":[-100:0x72,-1:0x75,1:0x74,100:0x70],"L":[-100:0x6d,-1:0x6a,1:0x69,100:0x6b]]
  guard let byte=commands[axis]?[delta] else{throw GateError.invalid}
  lastID=id;pending=(axis,target,now+10);return byte
 }
 mutating func position(axis:String,value:Int)throws->Bool {
  guard ["C","L"].contains(axis),(0...(axis=="C" ? 9555:9200)).contains(value) else{lock();throw GateError.unexpected}
  if let job=pending {guard job.axis==axis,job.target==value else{lock();throw GateError.unexpected};positions[axis]=value;pending=nil;return true}
  // A position report with no requested movement may reflect physical controls.
  if enabled {lock();throw GateError.unexpected};return false
 }
 mutating func expired(now:TimeInterval)->Bool {if let job=pending,now>=job.deadline{lock();return true};return false}
 enum GateError:Error,LocalizedError {case invalid,limit,unexpected
  var errorDescription:String?{switch self{case .invalid:return "Motor controls are locked, busy, or the request is invalid.";case .limit:return "That jog would exceed the configured motor limit.";case .unexpected:return "Unexpected position reply. Verify both positions before enabling motors again."}}
 }
}
