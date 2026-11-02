import Foundation
import Network

/// Loopback-only companion service. Never owns or writes to USB.
final class DXCBridge {
 static let port:UInt16=51986
 private let requestedPort:UInt16
 private var readyPort:UInt16?
 var boundPort:UInt16?{lock.lock();defer{lock.unlock()};return readyPort}
 init(port:UInt16=DXCBridge.port){requestedPort=port}
 private let queue=DispatchQueue(label:"ATU4K.DXC.loopback")
 private let lock=NSLock()
 private var listener:NWListener?
 private var state:[String:Any]=[:]
 private var updated=Date.distantPast
 private var seen=Set<String>()
 private var pending=false
 private var activeID=""
 private let session=UUID().uuidString
 private let token=UUID().uuidString.replacingOccurrences(of:"-",with:"")+UUID().uuidString.replacingOccurrences(of:"-",with:"")
 private var sharingValue=true
 var sharing:Bool{get{lock.lock();defer{lock.unlock()};return sharingValue}set{lock.lock();sharingValue=newValue;lock.unlock()}}
 var refresh:((@escaping()->Void)->Void)?
 var perform:(([String:Any],@escaping(Bool)->Void)->Void)?
 func publish(_ value:[String:Any]){lock.lock();defer{lock.unlock()};let old=state["request"] as? Int;state=value;updated=Date();if old != value["request"] as? Int{seen=[];pending=false};if let action=value["receipt"] as? [String:Any],action["id"] as? String==activeID,let status=action["status"] as? String,status != "pending"{pending=false}}
 func snapshot()->[String:Any]{lock.lock();defer{lock.unlock()};var result=state
  let fresh=Date().timeIntervalSince(updated)<4
  result["schema_version"]=1;result["model"]="ATU4K";result["sharing"]=sharingValue;result["fresh"]=fresh;result["generation"]=session+"-"+String(state["request"] as? Int ?? -1);result["control_token"]=token
  result["can_bank"]=sharingValue && fresh && state["mode"] as? String=="usb" && state["connected"] as? Bool==true && state["memoryEnabled"] as? Bool==true && state["busy"] as? Bool==false && !pending
  result["can_recall"]=result["can_bank"] as? Bool==true && state["motorEnabled"] as? Bool==true
  result["pending"]=pending || state["busy"] as? Bool==true
  if !sharingValue {return ["schema_version":1,"model":"ATU4K","sharing":false,"fresh":false,"can_bank":false,"can_recall":false,"pending":false,"generation":session+"-off","control_token":token]}
  return result
 }
 func start(){do{let parameters=NWParameters.tcp;parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:requestedPort)!);let server=try NWListener(using:parameters);listener=server;server.stateUpdateHandler={[weak self,weak server] status in if case .ready=status,let port=server?.port?.rawValue,port != 0{self?.lock.lock();self?.readyPort=port;self?.lock.unlock()}};server.newConnectionHandler={[weak self] connection in self?.serve(connection)};server.start(queue:queue)}catch{NSLog("ATU4K DXC sharing unavailable: %@",error.localizedDescription)}}
 func stop(){listener?.cancel()}
 private func serve(_ connection:NWConnection){connection.start(queue:queue);queue.asyncAfter(deadline:.now()+5){connection.cancel()};receive(connection,Data())}
 private func receive(_ connection:NWConnection,_ previous:Data){connection.receive(minimumIncompleteLength:1,maximumLength:8192){[weak self] data,_,complete,error in guard let self=self else{return};var buffer=previous;if let data=data{buffer.append(data)};guard buffer.count<=12288 else{self.reply(connection,413,["error":"Request too large"]);return}
  guard let boundary=buffer.range(of:Data("\r\n\r\n".utf8)),boundary.lowerBound<=8192,let header=String(data:buffer[..<boundary.lowerBound],encoding:.utf8) else{if !complete && error==nil{self.receive(connection,buffer)}else{connection.cancel()};return}
  let lines=header.components(separatedBy:"\r\n"),first=lines[0].split(separator:" ");guard first.count==3,first[1]=="/api/v1/atu4k" else{self.reply(connection,404,["error":"Not found"]);return}
  var headers=[String:String]();for line in lines.dropFirst(){guard let colon=line.firstIndex(of:":") else{self.reply(connection,400,["error":"Invalid headers"]);return};let key=line[..<colon].lowercased();guard headers[key]==nil else{self.reply(connection,400,["error":"Duplicate header"]);return};headers[key]=line[line.index(after:colon)...].trimmingCharacters(in:.whitespaces)}
  guard headers["host"]=="127.0.0.1:"+String(self.boundPort ?? self.requestedPort),headers["origin"]==nil,headers["transfer-encoding"]==nil else{self.reply(connection,403,["error":"Local companion requests only"]);return}
  if first[0]=="GET"{if self.sharing,let refresh=self.refresh{DispatchQueue.main.async{refresh{self.reply(connection,200,self.snapshot())}}}else{self.reply(connection,200,self.snapshot())};return}
  guard first[0]=="POST",headers["x-atu4k-token"]==self.token,headers["content-type"]=="application/json",let length=Int(headers["content-length"] ?? ""),length>0,length<=4096 else{self.reply(connection,403,["error":"Invalid control request"]);return}
  let body=buffer[boundary.upperBound...];if body.count<length{if !complete && error==nil{self.receive(connection,buffer)}else{connection.cancel()};return}
  guard body.count==length,let value=(try? JSONSerialization.jsonObject(with:body)) as? [String:Any] else{self.reply(connection,400,["error":"Invalid JSON"]);return};self.command(value){ok,message in self.reply(connection,ok ? 202:409,ok ? ["accepted":true,"id":value["id"] ?? ""]:["error":message])}
 }}
 private func command(_ value:[String:Any],done:@escaping(Bool,String)->Void){let s=snapshot();guard let action=value["action"] as? String,["selectBank","recall"].contains(action),let id=value["id"] as? String,UUID(uuidString:id) != nil,value["generation"] as? String==s["generation"] as? String,let bank=value["bank"] as? Int,[1,2].contains(bank),value["expected_bank"] as? Int==s["bank"] as? Int,s["can_bank"] as? Bool==true else{done(false,"Controller state changed or sharing unavailable.");return}
  if action=="recall"{guard s["can_recall"] as? Bool==true,bank==s["bank"] as? Int,let slot=value["slot"] as? Int,(1...8).contains(slot) else{done(false,"Enable motor controls in ATU4K Control before recall.");return}}
  lock.lock();guard !pending,!seen.contains(id),seen.count<4096 else{lock.unlock();done(false,"Duplicate request or controller busy.");return};seen.insert(id);activeID=id;pending=true;lock.unlock()
  var command=value;command["request"]=s["request"]
  DispatchQueue.main.async{[weak self] in guard let self=self else{done(false,"Controller unavailable");return};guard self.sharing,let perform=self.perform else{self.lock.lock();self.pending=false;self.lock.unlock();done(false,"Controller unavailable");return};perform(command){ok in if !ok{self.lock.lock();self.pending=false;self.lock.unlock()};done(ok,ok ? "Accepted":"Controller changed; nothing sent.")}}
 }
 private func reply(_ connection:NWConnection,_ code:Int,_ object:[String:Any]){guard let body=try? JSONSerialization.data(withJSONObject:object) else{connection.cancel();return};let header="HTTP/1.1 \(code) \(code<300 ? "OK":"Rejected")\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\nContent-Length: \(body.count)\r\n\r\n";connection.send(content:Data(header.utf8)+body,completion:.contentProcessed{_ in connection.cancel()})}
}
