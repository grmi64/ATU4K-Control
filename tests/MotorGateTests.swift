import Foundation
@main struct Tests {
 static func main()throws {
 var gate=MotorGate();do{_ = try gate.jog(axis:"C",delta:1,id:1,now:0);preconditionFailure()}catch{}
 try gate.arm(C:0,L:9200,rfOff:true)
 for (axis,delta) in [("C",-1),("L",1),("L",100)]{do{_ = try gate.jog(axis:axis,delta:delta,id:1,now:0);preconditionFailure()}catch{}}
 let coarse=try gate.jog(axis:"C",delta:100,id:1,now:0);precondition(coarse==0x70)
 do{_ = try gate.jog(axis:"L",delta:-1,id:2,now:0);preconditionFailure()}catch{}
 let completed=try gate.position(axis:"C",value:100);precondition(completed);precondition(gate.enabled)
 do{_ = try gate.jog(axis:"C",delta:1,id:1,now:0);preconditionFailure()}catch{}
 let fine=try gate.jog(axis:"L",delta:-1,id:2,now:1);precondition(fine==0x6a)
 do{_ = try gate.position(axis:"L",value:9198);preconditionFailure()}catch{};precondition(!gate.enabled)
 try gate.arm(C:3690,L:2108,rfOff:true);_ = try gate.jog(axis:"C",delta:-1,id:3,now:10);precondition(!gate.expired(now:19));precondition(gate.expired(now:20));precondition(!gate.enabled && gate.positions.isEmpty)
 do{try gate.arm(C:9556,L:0,rfOff:true);preconditionFailure()}catch{}
 do{try gate.arm(C:0,L:0,rfOff:false);preconditionFailure()}catch{}
 var boundaryChecks=0
 for axis in ["C","L"] {
  let maximum=axis=="C" ? 9555:9200
  for position in [0,1,99,100,maximum-100,maximum-99,maximum-1,maximum] {
   for delta in [-100,-1,1,100] {
    var boundary=MotorGate()
    try boundary.arm(C:axis=="C" ? position:3691,L:axis=="L" ? position:2109,rfOff:true)
    let valid=(0...maximum).contains(position+delta)
    do {
     _ = try boundary.jog(axis:axis,delta:delta,id:1,now:0)
     precondition(valid,"Out-of-range jog accepted")
     precondition(boundary.pending?.target==position+delta)
    }catch {precondition(!valid,"Valid boundary jog rejected");precondition(boundary.pending==nil)}
    boundaryChecks += 1
   }
  }
 }
 print("Boundary checks passed: \(boundaryChecks) cases across both axes, exact endpoints, and fine/coarse crossings. No hardware access.")
 print("Motor gate checks passed: default lock, RF confirmation, seeded bounds, single in-flight jog, duplicate rejection, exact feedback and timeout lock.")
 }
}
