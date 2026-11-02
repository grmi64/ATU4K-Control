/* Shared Mac/Windows StepperTune ASCII framing. Never issues commands. */
(function(root){
class ReplyParser{
 constructor(limits={C:9555,L:9200}){this.limits={...limits};this.reset();}
 reset(){this.buffer='';this.dropping=false;}
 feed(chunk){const events=[];for(const ch of chunk){if(ch==='\r'){if(!this.dropping&&this.buffer)events.push(this.parse(this.buffer));this.buffer='';this.dropping=false;}else if(ch==='\n'&&!this.buffer){}else if(ch.charCodeAt(0)<32||ch.charCodeAt(0)>126||this.buffer.length>=128){if(!this.dropping)events.push({type:'invalid',reason:'Malformed or oversized reply'});this.dropping=true;this.buffer='';}else if(!this.dropping)this.buffer+=ch;}return events;}
 parse(raw){let m;if((m=/^B([12])$/.exec(raw)))return {type:'bank',bank:Number(m[1]),raw};if((m=/^( ?)(M)([1-8])$/.exec(raw)))return {type:'memory',slot:Number(m[3]),ack:!!m[1],raw};if((m=/^([CL]) STEPS=(\d{1,5})$/.exec(raw))){const axis=m[1],value=Number(m[2]);return value<=this.limits[axis]?{type:'position',positions:{[axis]:value},raw}:{type:'invalid',reason:'Position exceeds configured '+axis+' limit',raw};}if((m=/^C=(\d{1,5}) L=(\d{1,5})$/.exec(raw))){const C=Number(m[1]),L=Number(m[2]);return C<=this.limits.C&&L<=this.limits.L?{type:'position',positions:{C,L},raw}:{type:'invalid',reason:'Position exceeds configured limits',raw};}return {type:'unknown',raw};}
}
if(typeof module!=='undefined')module.exports={ReplyParser};else root.Ladderline.ReplyParser=ReplyParser;
})(typeof globalThis!=='undefined'?globalThis:this);
