'use strict';
const fs=require('fs'),crypto=require('crypto'),dns=require('dns').promises,mqtt=require('/home/jay/.node-red/node_modules/mqtt');
async function main(){
 const base='/home/jay/.node-red',pc=JSON.parse(fs.readFileSync(base+'/.config.projects.json')),project=pc.activeProject;
 const flows=JSON.parse(fs.readFileSync(`${base}/projects/${project}/flows.json`));let creds=JSON.parse(fs.readFileSync(`${base}/projects/${project}/flows_cred.json`));
 if(creds.$){const key=crypto.createHash('sha256').update(pc.projects[project].credentialSecret).digest();const d=crypto.createDecipheriv('aes-256-ctr',key,Buffer.from(creds.$.slice(0,32),'hex'));creds=JSON.parse(d.update(creds.$.slice(32),'base64','utf8')+d.final('utf8'));}
 const broker=flows.find(n=>n.type==='mqtt-broker'),auth=creds[broker.id],tc=creds[broker.tls],tls=flows.find(n=>n.id===broker.tls);
 if(tls.verifyservercert!==true)throw Error('Server verification disabled');
 const addresses=await dns.resolve4(broker.broker);if(addresses.length!==1)throw Error('Unexpected broker resolution');const ip=addresses[0];
 async function connect(test){return new Promise(resolve=>{
  let done=false;const options={protocol:'mqtts',host:ip,port:Number(broker.port),servername:tls.servername||broker.broker,ca:tc.cadata,cert:tc.certdata,key:tc.keydata,rejectUnauthorized:true,username:auth.user,password:auth.password,clientId:'jaylab-tls-check-'+process.pid+'-'+test,clean:true,keepalive:0,reconnectPeriod:0,connectTimeout:6000};
  if(test==='no-certificate'){delete options.cert;delete options.key;}
  if(test==='no-password'){delete options.username;delete options.password;}
  const client=mqtt.connect(options);
  const finish=result=>{if(done)return;done=true;client.end(true);resolve({test,...result});};
  client.on('connect',()=>finish({connected:true}));client.on('error',e=>finish({connected:false,code:e.code||'MQTT_ERROR'}));client.on('close',()=>finish({connected:false,code:'CLOSED_WITHOUT_CONNACK'}));
 });}
 const results=[];for(const test of ['valid','no-certificate','no-password'])results.push(await connect(test));
 console.log(JSON.stringify({broker:broker.broker,address:ip,serverVerification:true,published:false,results}));
 if(!results[0].connected||results[1].connected||results[2].connected)process.exitCode=1;
}
const timer=setTimeout(()=>{console.log('{"ok":false,"code":"TIMEOUT"}');process.exit(1)},25000);
main().catch(()=>{console.log('{"ok":false,"code":"MQTT_TLS_CHECK_FAILED"}');process.exitCode=1}).finally(()=>clearTimeout(timer));
