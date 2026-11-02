import Foundation
/// Bank and recall permission is session-local, independent of jog permission.
struct MemoryGate {
 enum Job {case bank(Int,TimeInterval);case recall(Int,Int,Bool,TimeInterval)}
 var saving=false
 var savePositions:[String:Int]?
 var enabled=false
 var bank:Int?
 var pending:Job?
 var lastID=0
 mutating func reset(){enabled=false;bank=nil;pending=nil;saving=false;savePositions=nil}
 mutating func enable(_ value:Bool)throws{guard pending==nil else{throw MotorGate.GateError.invalid};enabled=value}
 mutating func select(_ bank:Int,id:Int,now:TimeInterval)throws->UInt8{
  guard enabled,pending==nil,id>lastID,[1,2].contains(bank),self.bank != nil else{throw MotorGate.GateError.invalid}
  guard self.bank != bank else{throw MotorGate.GateError.invalid}
  lastID=id;pending = .bank(bank,now+5);return bank==1 ? 0x36:0x37
 }
 mutating func recall(_ slot:Int,bank:Int,id:Int,rfOff:Bool,positionsKnown:Bool,now:TimeInterval)throws->UInt8{
  guard enabled,pending==nil,id>lastID,rfOff,positionsKnown,self.bank==bank,(1...8).contains(slot) else{throw MotorGate.GateError.invalid}
  lastID=id;pending = .recall(bank,slot,false,now+180);return UInt8(0x60+slot)
 }
 mutating func save(_ slot:Int,bank:Int,id:Int,rfOff:Bool,positions:[String:Int],now:TimeInterval)throws->UInt8{
  guard let C=positions["C"],let L=positions["L"],(0...9555).contains(C),(0...9200).contains(L) else{throw MotorGate.GateError.invalid}
  guard enabled,pending==nil,id>lastID,self.bank==bank,(1...8).contains(slot) else{throw MotorGate.GateError.invalid}
  lastID=id
  saving=true;savePositions=positions;pending = .recall(bank,slot,false,now+10)
  return UInt8(0x40+slot)
 }
 mutating func reportedBank(_ value:Int)throws->Bool{
  guard [1,2].contains(value) else{throw MotorGate.GateError.unexpected}
  if let job=pending{switch job{case .bank(let expected,_):guard expected==value else{throw MotorGate.GateError.unexpected};bank=value;pending=nil;return true
   case .recall(let expected,_,_,_):guard expected==value else{throw MotorGate.GateError.unexpected}}}
  bank=value;return false
 }
 mutating func reportedSlot(_ value:Int,ack:Bool)throws{
  if case .recall(let bank,let slot,_,let deadline)=pending {guard value==slot else{throw MotorGate.GateError.unexpected};if !ack{pending = .recall(bank,slot,true,deadline)}}
 }
 mutating func reportedPair(C:Int,L:Int)throws->Bool{
  guard (0...9555).contains(C),(0...9200).contains(L) else{throw MotorGate.GateError.unexpected}
  guard case .recall(_,_,let confirmed,_)=pending,confirmed else{throw MotorGate.GateError.unexpected}
  if saving {guard savePositions?["C"]==C,savePositions?["L"]==L else{throw MotorGate.GateError.unexpected}}
  pending=nil;saving=false;savePositions=nil;return true
 }
 func expired(now:TimeInterval)->Bool{switch pending{case .bank(_,let d):return now>=d;case .recall(_,_,_,let d):return now>=d;case nil:return false}}
 var recallSlot:Int?{if case .recall(_,let slot,_,_)=pending{return slot};return nil}
 var recalling:Bool{if case .recall=pending{return true};return false}
}
