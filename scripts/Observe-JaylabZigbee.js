'use strict';
const fs=require('fs'),crypto=require('crypto'),dns=require('dns').promises,mqtt=require('/home/jay/.node-red/node_modules/mqtt');
const duration=Number(process.argv[2]||240);if(!Number.isInteger(duration)||duration<30||duration>600)throw Error('Observation range 30..600 seconds');
const start=new Date();let client,timer,tick,bridgeOnlineAt=null;let devicesInfo=[],info=null,received=0,retained=0,unknown=0;const devices=new Map();
function summary(final=false){console.log(JSON.stringify({kind:final?'final':'progress',observationStartUtc:start.toISOString(),observedUtc:new Date().toISOString(),seconds:Math.round((Date.now()-start)/1000),connected:client?.connected||false,bridgeOnlineAt:bridgeOnlineAt?new Date(bridgeOnlineAt).toISOString():null,bridgeInfo:info,deviceInventory:final?devicesInfo:undefined,inventoryCount:devicesInfo.length,received,retained,unknown,devices:Array.from(devices.values())}));}
async function main(){
 const base='/home/jay/.node-red',pc=JSON.parse(fs.readFileSync(base+'/.config.projects.json')),p=pc.activeProject;
 const flows=JSON.parse(fs.readFileSync(`${base}/projects/${p}/flows.json`));let creds=JSON.parse(fs.readFileSync(`${base}/projects/${p}/flows_cred.json`));
 if(creds.$){const key=crypto.createHash('sha256').update(pc.projects[p].credentialSecret).digest(),d=crypto.createDecipheriv('aes-256-ctr',key,Buffer.from(creds.$.slice(0,32),'hex'));creds=JSON.parse(d.update(creds.$.slice(32),'base64','utf8')+d.final('utf8'));}
 const b=flows.find(n=>n.type==='mqtt-broker'),a=creds[b.id],tc=creds[b.tls];const ip=(await dns.resolve4(b.broker))[0];
 client=mqtt.connect({protocol:'mqtts',host:ip,port:Number(b.port),servername:b.broker,ca:tc.cadata,cert:tc.certdata,key:tc.keydata,rejectUnauthorized:true,username:a.user,password:a.password,clientId:'jaylab-zigbee-observe-'+process.pid,clean:true,reconnectPeriod:0,connectTimeout:8000});
 client.on('error',e=>{console.log(JSON.stringify({kind:'error',code:e.code||'MQTT_ERROR'}));process.exitCode=1;finish();});
 client.on('connect',()=>client.subscribe('zigbee2mqtt/#',{qos:0},e=>{if(e){process.exitCode=1;finish();}else console.log(JSON.stringify({kind:'subscribed',observedUtc:new Date().toISOString(),topic:'zigbee2mqtt/#',serverVerification:true}));}));
 client.on('message',(topic,buffer,packet)=>{
  received++;if(packet.retain)retained++;let data;try{data=JSON.parse(buffer.toString())}catch{if(buffer.toString()==='online'||buffer.toString()==='offline')data=buffer.toString();else return;}
  const name=topic.slice('zigbee2mqtt/'.length);
  if(name==='bridge/state'){const state=typeof data==='string'?data:data?.state;if(state==='online'&&!packet.retain)bridgeOnlineAt=Date.now();return;}
  if(name==='bridge/devices'&&Array.isArray(data)){devicesInfo=data.map(d=>({name:d.friendly_name,ieee:d.ieee_address,type:d.type,model:d.definition?.model,vendor:d.definition?.vendor,interviewCompleted:d.interview_completed}));return;}
  if(name==='bridge/info'&&data){info={version:data.version,permitJoin:data.permit_join,coordinatorType:data.coordinator?.type,coordinatorFirmware:data.coordinator?.meta?.revision};return;}
  if(name.includes('/'))return;
  if(!data||typeof data!=='object'||!('linkquality'in data)){unknown++;return;}
  const row=devices.get(name)||{name,messages:0,retainedMessages:0,afterStartupGrace:0,lastObservedUtc:null,lastLqi:null,fields:[]};
  row.messages++;if(packet.retain)row.retainedMessages++;
  if(!packet.retain&&bridgeOnlineAt&&Date.now()-bridgeOnlineAt>30000)row.afterStartupGrace++;
  row.lastObservedUtc=new Date().toISOString();row.lastLqi=data.linkquality;row.fields=Object.keys(data).sort();if(data.last_seen)row.deviceLastSeen=data.last_seen;devices.set(name,row);
 });
 timer=setTimeout(finish,duration*1000);tick=setInterval(()=>summary(),30000);
}
let finished=false;function finish(){if(finished)return;finished=true;clearTimeout(timer);clearInterval(tick);summary(true);if(client)client.end(true);}
main().catch(()=>{console.log('{"kind":"error","code":"LOCAL_CONFIGURATION_ERROR"}');process.exitCode=1;finish();});
