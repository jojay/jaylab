'use strict';
const fs=require('fs'),http=require('http'),crypto=require('crypto');
const yaml=require('/opt/zigbee2mqtt/node_modules/js-yaml'),mqtt=require('/opt/zigbee2mqtt/node_modules/mqtt'),WebSocket=require('/opt/zigbee2mqtt/node_modules/ws');
async function main(){
 const base='/opt/zigbee2mqtt',c=yaml.load(fs.readFileSync(base+'/data/configuration.yaml','utf8'));
 if(c.mqtt.reject_unauthorized!==true||!c.mqtt.server.startsWith('mqtts://'))throw Error('MQTT verification not configured');
 const cert=new crypto.X509Certificate(fs.readFileSync(c.mqtt.cert));
 const db=fs.readFileSync(base+'/data/database.db','utf8').split('\n').filter(Boolean).map(JSON.parse);
 const httpStatus=await new Promise((resolve,reject)=>http.get('http://127.0.0.1:8080/',r=>{r.resume();resolve(r.statusCode)}).on('error',reject));
 const websocket=await new Promise(resolve=>{
  const auth=typeof c.frontend==='object'?c.frontend.auth_token:null;const address='ws://127.0.0.1:8080/api'+(auth?'?token='+encodeURIComponent(auth):'');
  const ws=new WebSocket(address);let done=false;const finish=r=>{if(done)return;done=true;clearTimeout(timer);ws.terminate();resolve(r)};
  const timer=setTimeout(()=>finish(false),4000);ws.on('message',()=>finish(true));ws.on('error',()=>finish(false));
 });
 const connected=await new Promise(resolve=>{
  const client=mqtt.connect(c.mqtt.server,{username:c.mqtt.user,password:c.mqtt.password,ca:fs.readFileSync(c.mqtt.ca),cert:fs.readFileSync(c.mqtt.cert),key:fs.readFileSync(c.mqtt.key),rejectUnauthorized:true,clientId:'jaylab-zigbee-check-'+process.pid,reconnectPeriod:0,connectTimeout:6000});let done=false;
  const finish=r=>{if(done)return;done=true;client.end(true);resolve(r)};client.on('connect',()=>finish(true));client.on('error',()=>finish(false));client.on('close',()=>finish(false));
 });
 console.log(JSON.stringify({observedUtc:new Date().toISOString(),version:JSON.parse(fs.readFileSync(base+'/package.json')).version,frontendHttp:httpStatus,frontendWebsocket:websocket,mqttTlsConnected:connected,mqttServerVerification:true,serialPath:c.serial.port,serialPresent:fs.existsSync(c.serial.port),permitJoin:c.permit_join,clientCertificateExpires:cert.validTo,devices:db.filter(d=>d.type!=='Coordinator').map(d=>({ieee:d.ieeeAddr,type:d.type,model:d.modelId,interviewCompleted:d.interviewCompleted,lastSeenUtc:d.lastSeen?new Date(d.lastSeen).toISOString():null}))}));
 if(httpStatus!==200||!websocket||!connected)process.exitCode=1;
}
const timer=setTimeout(()=>{console.log('{"ok":false,"code":"ZIGBEE_CHECK_TIMEOUT"}');process.exit(1)},15000);
main().catch(()=>{console.log('{"ok":false,"code":"ZIGBEE_CHECK_FAILED"}');process.exitCode=1}).finally(()=>clearTimeout(timer));
