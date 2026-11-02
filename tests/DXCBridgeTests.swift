import Foundation
@main struct Tests {
 static func main() async throws{
 let bridge=DXCBridge(port:0)
 let state:[String:Any] = ["request":1,"mode":"usb","connected":true,"motorEnabled":false,"memoryEnabled":true,"busy":false,"bank":1,"positions":["C":100,"L":200],"lastKnown":["C":99,"L":199],"labels":Array(repeating:"Test",count:16)]
 bridge.publish(state);var snap=bridge.snapshot();precondition(snap["can_bank"] as? Bool==true && snap["can_recall"] as? Bool==false)
 bridge.start();for _ in 0..<100{if bridge.boundPort != nil{break};try await Task.sleep(nanoseconds:20_000_000)}
 guard let port=bridge.boundPort else{fatalError("Isolated bridge did not bind")};let url=URL(string:"http://127.0.0.1:\(port)/api/v1/atu4k")!
 try await Task.sleep(nanoseconds:4_100_000_000);precondition(bridge.snapshot()["fresh"] as? Bool==false)
 bridge.refresh={done in bridge.publish(state);done()}
 let (raw,response)=try await URLSession.shared.data(from:url);precondition((response as! HTTPURLResponse).statusCode==200);snap=try JSONSerialization.jsonObject(with:raw) as! [String:Any]
 precondition(snap["fresh"] as? Bool==true && snap["connected"] as? Bool==true)
 var origin=URLRequest(url:url);origin.setValue("http://example.invalid",forHTTPHeaderField:"Origin");let (_,denied)=try await URLSession.shared.data(for:origin);precondition((denied as! HTTPURLResponse).statusCode==403)
 func request(_ value:[String:Any],token:String)async throws->Int{var r=URLRequest(url:url);r.httpMethod="POST";r.setValue("application/json",forHTTPHeaderField:"Content-Type");r.setValue(token,forHTTPHeaderField:"X-ATU4K-Token");r.httpBody=try JSONSerialization.data(withJSONObject:value);let (_,response)=try await URLSession.shared.data(for:r);return (response as! HTTPURLResponse).statusCode}
 let id=UUID().uuidString,token=snap["control_token"] as! String,generation=snap["generation"] as! String
 let action:[String:Any] = ["action":"selectBank","id":id,"generation":generation,"expected_bank":1,"bank":2]
 let badToken=try await request(action,token:"wrong");precondition(badToken==403)
 var recall=action;recall["action"]="recall";recall["bank"]=1;recall["slot"]=1;let locked=try await request(recall,token:token);precondition(locked==409)
 bridge.perform={value,done in precondition(value["action"] as? String=="selectBank");done(true)}
 let accepted=try await request(action,token:token);precondition(accepted==202)
 let duplicate=try await request(action,token:token);precondition(duplicate==409)
 var complete=state;complete["receipt"]=["id":id,"status":"complete"];bridge.publish(complete)
 let replay=try await request(action,token:token);precondition(replay==409)
 bridge.sharing=false;precondition(bridge.snapshot()["can_bank"] as? Bool==false)
 let disabled=try await request(action,token:token);precondition(disabled==409)
 bridge.sharing=true;var fresh=state;fresh["request"]=2;bridge.publish(fresh);let staleGeneration=try await request(action,token:token);precondition(staleGeneration==409)
 bridge.stop();print("DXC bridge checks passed: isolated loopback HTTP, host/origin/token guards, motor permission, bank acknowledgement dispatch, duplicate/replay rejection, sharing-off and old-session rejection. No USB access.")
 }
}
