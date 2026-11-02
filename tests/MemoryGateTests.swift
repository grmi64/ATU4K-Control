import Foundation
@main struct Tests {
 static func main()throws {
 var g=MemoryGate();_ = try g.reportedBank(1)
 do{_ = try g.select(2,id:1,now:0);preconditionFailure()}catch{}
 try g.enable(true);let b=try g.select(2,id:1,now:0);precondition(b==0x37)
 do{_ = try g.recall(4,bank:1,id:2,rfOff:true,positionsKnown:true,now:0);preconditionFailure()}catch{}
 precondition(!g.expired(now:4));precondition(g.expired(now:5));let changed=try g.reportedBank(2);precondition(changed)
 do{_ = try g.select(1,id:1,now:0);preconditionFailure()}catch{}
 do{_ = try g.recall(1,bank:1,id:2,rfOff:true,positionsKnown:true,now:0);preconditionFailure()}catch{}
 do{_ = try g.recall(1,bank:2,id:2,rfOff:false,positionsKnown:true,now:0);preconditionFailure()}catch{}
 do{_ = try g.recall(1,bank:2,id:2,rfOff:true,positionsKnown:false,now:0);preconditionFailure()}catch{}
 let recall=try g.recall(1,bank:2,id:2,rfOff:true,positionsKnown:true,now:10);precondition(recall==0x61)
 try g.reportedSlot(1,ack:true)
 do{_ = try g.reportedPair(C:100,L:200);preconditionFailure()}catch{}
 try g.reportedSlot(1,ack:false);precondition(g.recalling)
 do{_ = try g.reportedPair(C:9556,L:0);preconditionFailure()}catch{}
 let complete=try g.reportedPair(C:100,L:200);precondition(complete && g.pending==nil)
 let back=try g.select(1,id:3,now:20);precondition(back==0x36)
 do{_ = try g.reportedBank(2);preconditionFailure()}catch{}
 g.reset();precondition(!g.enabled && g.bank==nil && g.pending==nil)
 _ = try g.reportedBank(1)
 do{_ = try g.save(4,bank:1,id:10,rfOff:true,positions:["C":10,"L":20],now:0);preconditionFailure()}catch{}
 try g.enable(true)
 let save=try g.save(4,bank:1,id:10,rfOff:true,positions:["C":10,"L":20],now:0);precondition(save==0x44 && g.saving)
 try g.reportedSlot(4,ack:false)
 do{_ = try g.reportedPair(C:11,L:20);preconditionFailure()}catch{}
 let saved=try g.reportedPair(C:10,L:20);precondition(saved && !g.saving)
 print("Memory gate checks passed: default lock, bank acknowledgement, wrong-bank/unknown-position/RF guards, busy/duplicate rejection, leading ack versus completed slot, bounds and timeout.")
 }
}
