/* Portable controller service. Simulation only; no device or network transport. */
(function(root){
class Controller {
 constructor(labels=[]){this.mode='simulation';this.connected=true;this.positions={C:6026,L:9099};this.limits={C:9555,L:9200};this.bank=1;this.busy=false;this.memories=Array.from({length:16},()=>null);this.memories[3]={name:'Capture reference',C:3691,L:2109};this.labels=Array.from({length:16},(_,i)=>typeof labels[i]==='string'?labels[i].trim().slice(0,40):'');}
 snapshot(){return {mode:this.mode,connected:this.connected,busy:this.busy,positions:{...this.positions},limits:{...this.limits},bank:this.bank,labels:[...this.labels],memories:this.memories.map(m=>m?{...m}:null)};}
 check(){if(this.mode!=='simulation')throw Error('USB status-only mode: movement and memory operations are disabled.');if(!this.connected)throw Error('Connect the simulator first.');if(this.busy)throw Error('Wait for the current movement to finish.');}
 jog(axis,delta){this.check();if(!['C','L'].includes(axis)||![-100,-1,1,100].includes(delta))throw Error('Invalid movement.');const target=this.positions[axis]+delta;if(target<0||target>this.limits[axis])throw Error('Movement exceeds the configured '+axis+' limit.');this.positions[axis]=target;return target;}
 save(slot,name){this.check();this.validSlot(slot);this.rename(slot,name);this.memories[slot]={...this.positions};}
 recall(slot){this.check();this.validSlot(slot);const m=this.memories[slot];if(!m)throw Error('This memory is empty.');for(const a of ['C','L'])if(!Number.isInteger(m[a])||m[a]<0||m[a]>this.limits[a])throw Error('Saved position is outside configured limits.');this.positions={C:m.C,L:m.L};}
 setMode(mode){if(!['simulation','usb'].includes(mode))throw Error('Invalid mode.');this.mode=mode;this.busy=false;this.connected=mode==='simulation';this.positions=mode==='simulation'?{C:6026,L:9099}:{C:null,L:null};this.memories=Array.from({length:16},()=>null);if(mode==='simulation')this.memories[3]={C:3691,L:2109};this.deviceBank=null;this.deviceMemory=null;}
 rename(slot,name){if(this.busy)throw Error('Wait for the current movement to finish.');this.validSlot(slot);if(typeof name!=='string')throw Error('Invalid label.');this.labels[slot]=name.trim().slice(0,40);}
 validSlot(slot){if(!Number.isInteger(slot)||slot<0||slot>=16)throw Error('Invalid memory.');}
}
if(typeof module!=='undefined')module.exports={Controller};else root.Ladderline={Controller};
})(typeof globalThis!=='undefined'?globalThis:this);
