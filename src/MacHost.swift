import Cocoa
import WebKit
final class AppDelegate:NSObject,NSApplicationDelegate,WKNavigationDelegate,WKScriptMessageHandler {
 var usbActive=false
 var currentView="full"
 var window:NSWindow!
 var web:WKWebView!
 let usb=USBStatus()
 let dxc=DXCBridge()
 func applicationDidFinishLaunching(_ notification:Notification){
  let config=WKWebViewConfiguration();config.websiteDataStore = .nonPersistent();config.userContentController.add(self,name:"presentation");config.userContentController.add(self,name:"labels");config.userContentController.add(self,name:"usb");config.userContentController.add(self,name:"dxcState")
  let savedView=UserDefaults.standard.string(forKey:"presentation.view") ?? "full"
  currentView=["full","compact","mini"].contains(savedView) ? savedView:"full"
  let presentation:[String:Any] = ["view":currentView,"light":UserDefaults.standard.bool(forKey:"presentation.light")]
  if let data=try? JSONSerialization.data(withJSONObject:presentation),let json=String(data:data,encoding:.utf8){config.userContentController.addUserScript(WKUserScript(source:"window.atuPresentation="+json+";",injectionTime:.atDocumentStart,forMainFrameOnly:true))}
  if let cache=UserDefaults.standard.dictionary(forKey:"positions.lastKnown.v1"),let data=try? JSONSerialization.data(withJSONObject:cache),let json=String(data:data,encoding:.utf8){config.userContentController.addUserScript(WKUserScript(source:"window.atuLastPositions="+json+";",injectionTime:.atDocumentStart,forMainFrameOnly:true))}
  let names=UserDefaults.standard.stringArray(forKey:"memoryLabels.v1") ?? []
  if let data=try? JSONSerialization.data(withJSONObject:names),let json=String(data:data,encoding:.utf8){config.userContentController.addUserScript(WKUserScript(source:"window.atuSavedLabels="+json+";",injectionTime:.atDocumentStart,forMainFrameOnly:true))}
  web=WKWebView(frame:.zero,configuration:config);web.navigationDelegate=self
  window=NSWindow(contentRect:NSRect(x:0,y:0,width:1020,height:900),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
  window.title="ATU4K Control";window.minSize=NSSize(width:670,height:550);window.contentView=web;window.center();window.minSize=currentView=="mini" ? NSSize(width:360,height:530):NSSize(width:670,height:550)
  window.setContentSize(viewSize(currentView));_ = window.setFrameUsingName("ATU4K."+currentView);window.setFrameAutosaveName("ATU4K."+currentView);window.makeKeyAndOrderFront(nil)
  let menu=NSMenu();let item=NSMenuItem();menu.addItem(item);let appMenu=NSMenu();appMenu.addItem(withTitle:"Quit ATU4K Control",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");item.submenu=appMenu
  let settingsItem=NSMenuItem();menu.addItem(settingsItem);let settingsMenu=NSMenu(title:"Settings");settingsItem.submenu=settingsMenu
  settingsMenu.addItem(withTitle:"Export settings backup…",action:#selector(exportSettings),keyEquivalent:"")
  settingsMenu.addItem(withTitle:"Import settings backup…",action:#selector(importSettings),keyEquivalent:"")
  settingsMenu.addItem(.separator())
  settingsMenu.addItem(withTitle:"Enter Demo Mode",action:#selector(enterDemo),keyEquivalent:"")
  settingsMenu.addItem(withTitle:"Exit Demo Mode",action:#selector(exitDemo),keyEquivalent:"")
  let shareItem=NSMenuItem(title:"Share with DX Caliber",action:#selector(toggleDXCSharing(_:)),keyEquivalent:"");shareItem.state=UserDefaults.standard.object(forKey:"dxc.sharing") as? Bool == false ? .off:.on;dxc.sharing=shareItem.state == .on;settingsMenu.addItem(shareItem)
  dxc.refresh={[weak self] done in guard let self=self else{done();return};self.web.evaluateJavaScript("window.captureDXCState && window.captureDXCState()"){[weak self] result,error in if error==nil,let state=result as? [String:Any]{self?.dxc.publish(state)};done()}}
  dxc.perform={[weak self] value,done in guard let self=self,let data=try? JSONSerialization.data(withJSONObject:value),let json=String(data:data,encoding:.utf8) else{done(false);return};self.web.evaluateJavaScript("window.receiveDXCAction && window.receiveDXCAction("+json+")"){result,error in done(error==nil && result as? Bool==true)}};dxc.start()
  NSApp.mainMenu=menu
  if let url=Bundle.main.url(forResource:"index",withExtension:"html"){web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())}
  usb.event={[weak self] payload in DispatchQueue.main.async{self?.sendUSB(payload)}}
  NSApp.activate(ignoringOtherApps:true)
 }
 func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage){
  guard message.frameInfo.isMainFrame,message.frameInfo.request.url?.isFileURL == true else{return}
  if message.name=="dxcState" {if let value=message.body as? [String:Any]{dxc.publish(value)};return}
  if message.name=="usb" {
   guard let command=message.body as? [String:Any],let action=command["action"] as? String else{return}
   if action=="ports" || action=="discover"{let devices=USBDiscovery.devices();sendUSB(["type":"ports","ports":devices.compactMap{$0["path"] as? String},"devices":devices,"discovery":action=="discover"]);return}
   guard let request=command["request"] as? Int,request>=0 else{return}
   if action=="enableMemory",let enabled=command["enabled"] as? Bool,let rfOff=command["rfOff"] as? Bool{usb.enableMemory(enabled,rfOff:rfOff,request:request);return}
   if action=="selectBank",let bank=command["bank"] as? Int,let id=command["id"] as? Int{usb.selectBank(bank,id:id,request:request);return}
   if action=="recall",let bank=command["bank"] as? Int,let slot=command["slot"] as? Int,let id=command["id"] as? Int,let rfOff=command["rfOff"] as? Bool{usb.recall(bank:bank,slot:slot,id:id,rfOff:rfOff,request:request);return}
   if action=="saveMemory",let bank=command["bank"] as? Int,let slot=command["slot"] as? Int,let id=command["id"] as? Int,let rfOff=command["rfOff"] as? Bool{usb.saveMemory(bank:bank,slot:slot,id:id,rfOff:rfOff,request:request);return}
   if action=="enableMotors",let C=command["C"] as? Int,let L=command["L"] as? Int,let rfOff=command["rfOff"] as? Bool{usb.enableMotors(C:C,L:L,rfOff:rfOff,request:request);return}
   if action=="disableMotors"{usb.disableMotors(request:request);return}
   if action=="jog",let axis=command["axis"] as? String,let delta=command["delta"] as? Int,let id=command["id"] as? Int{usb.jog(axis:axis,delta:delta,id:id,request:request);return}
   if action=="connect",let path=command["path"] as? String{usbActive=true;usb.connect(path:path,request:request)}
   else if action=="disconnect"{usbActive=false;usb.disconnect(request:request)}
   return
  }
  if message.name=="labels" {if let names=message.body as? [String],names.count==16,names.allSatisfy({$0.count<=40}){UserDefaults.standard.set(names,forKey:"memoryLabels.v1")};return}
  if let theme=message.body as? [String:Bool],let light=theme["light"]{UserDefaults.standard.set(light,forKey:"presentation.light");return}
  guard let mode=message.body as? String,["compact","full","mini"].contains(mode) else{return}
  UserDefaults.standard.set(mode,forKey:"presentation.view")
  guard mode != currentView else{return}
  window.saveFrame(usingName:"ATU4K."+currentView);currentView=mode
  window.minSize=mode=="mini" ? NSSize(width:360,height:530) : NSSize(width:670,height:550)
  let top=window.frame.maxY;window.setContentSize(viewSize(mode));var frame=window.frame;frame.origin.y=top-frame.height;window.setFrame(frame,display:true)
  _ = window.setFrameUsingName("ATU4K."+mode);window.setFrameAutosaveName("ATU4K."+mode)

 }
 @objc func toggleDXCSharing(_ item:NSMenuItem){dxc.sharing = !dxc.sharing;item.state=dxc.sharing ? .on:.off;UserDefaults.standard.set(dxc.sharing,forKey:"dxc.sharing")}
 @objc func enterDemo(){guard !usbActive else{let alert=NSAlert();alert.messageText="Disconnect USB before entering Demo Mode";alert.runModal();return};web.evaluateJavaScript("window.setDemoMode(true)",completionHandler:nil)}
 @objc func exitDemo(){web.evaluateJavaScript("window.setDemoMode(false)",completionHandler:nil)}
 func settingsError(_ error:Error){let alert=NSAlert();alert.messageText="Settings backup unavailable";alert.informativeText=error.localizedDescription;alert.runModal()}
 @objc func exportSettings(){
  let panel=NSSavePanel();panel.nameFieldStringValue="ATU4K-settings.json";guard panel.runModal() == .OK,let url=panel.url else{return}
  let settings=SettingsBackup(labels:UserDefaults.standard.stringArray(forKey:"memoryLabels.v1") ?? Array(repeating:"",count:16),view:currentView,light:UserDefaults.standard.bool(forKey:"presentation.light"))
  do{try settings.validate();let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(settings).write(to:url,options:.atomic)}catch{settingsError(error)}
 }
 @objc func importSettings(){
  guard !usbActive else{let alert=NSAlert();alert.messageText="Disconnect USB before importing settings";alert.informativeText="Use Disconnect in the app, then import your backup.";alert.runModal();return}
  let panel=NSOpenPanel();panel.allowsMultipleSelection=false;panel.canChooseDirectories=false;guard panel.runModal() == .OK,let url=panel.url else{return}
  do{
   let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0;guard size<=65536 else{throw NSError(domain:"ATU4K",code:2,userInfo:[NSLocalizedDescriptionKey:"Backup file is too large."])}
   let settings=try JSONDecoder().decode(SettingsBackup.self,from:Data(contentsOf:url));try settings.validate()
   let alert=NSAlert();alert.messageText="Replace app settings?";alert.informativeText="Import 16 memory names, \(settings.view.capitalized) view and \(settings.light ? "Light":"Dark") theme. Limits: C 0–9555, L 0–9200. Hardware presets and motor positions are not included. Controls stay disabled.";alert.addButton(withTitle:"Import settings");alert.addButton(withTitle:"Cancel");guard alert.runModal() == .alertFirstButtonReturn else{return}
   UserDefaults.standard.set(settings.memoryLabels,forKey:"memoryLabels.v1")
   let data=try JSONEncoder().encode(settings);let json=String(decoding:data,as:UTF8.self)
   web.evaluateJavaScript("window.applySettingsBackup("+json+")",completionHandler:nil)
  }catch{settingsError(error)}
 }
 func viewSize(_ mode:String)->NSSize{mode=="mini" ? NSSize(width:410,height:600):(mode=="compact" ? NSSize(width:800,height:650):NSSize(width:1020,height:900))}
 func sendUSB(_ input:[String:Any]){var event=input
  if let type=event["type"] as? String,["jogComplete","recallComplete","saveComplete"].contains(type),let C=event["C"] as? Int,let L=event["L"] as? Int,(0...9555).contains(C),(0...9200).contains(L){let cache:[String:Any] = ["C":C,"L":L,"savedAt":ISO8601DateFormatter().string(from:Date())];UserDefaults.standard.set(cache,forKey:"positions.lastKnown.v1");event["lastKnown"]=cache}
if let type=event["type"] as? String,["closed","error"].contains(type){usbActive=false};guard let data=try? JSONSerialization.data(withJSONObject:event),let json=String(data:data,encoding:.utf8) else{return};web.evaluateJavaScript("window.receiveUSB && window.receiveUSB("+json+");",completionHandler:nil)}
 func applicationWillTerminate(_ notification:Notification){window.saveFrame(usingName:"ATU4K."+currentView);dxc.stop();usb.shutdown()}
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {true}
 func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)}
}
@main struct Main {static func main(){let app=NSApplication.shared;app.setActivationPolicy(.regular);let delegate=AppDelegate();app.delegate=delegate;app.run()}}
