import pathlib,subprocess,json,shlex
config=str(pathlib.Path(__file__).resolve().parents[1]/'.local/access/ssh_config_wsl')
source=r'''
const fs=require('fs'),crypto=require('crypto');
const b='/home/jay/.node-red',p=JSON.parse(fs.readFileSync(b+'/.config.projects.json')),n=p.activeProject;
const f=JSON.parse(fs.readFileSync(`${b}/projects/${n}/flows.json`));let c=JSON.parse(fs.readFileSync(`${b}/projects/${n}/flows_cred.json`));
if(c.$){const d=crypto.createDecipheriv('aes-256-ctr',crypto.createHash('sha256').update(p.projects[n].credentialSecret).digest(),Buffer.from(c.$.slice(0,32),'hex'));c=JSON.parse(d.update(c.$.slice(32),'base64','utf8')+d.final('utf8'));}
const x=f.find(x=>x.type==='mqtt-broker');process.stdout.write(JSON.stringify({user:c[x.id].user,password:c[x.id].password}));
'''
remote=r'''
import sys,json,socket,struct
credentials=json.load(sys.stdin)
def field(text):
 data=text.encode();return struct.pack('!H',len(data))+data
def connect(auth):
 flags=0xc2 if auth else 2
 body=field('MQTT')+bytes([4,flags])+struct.pack('!H',0)+field('jaylab-check-local')
 if auth:body+=field(credentials['user'])+field(credentials['password'])
 n=len(body);length=bytearray()
 while True:
  b=n%128;n//=128;length.append(b|(128 if n else 0))
  if not n:break
 with socket.create_connection(('127.0.0.1',1883),timeout=6) as s:
  s.sendall(bytes([0x10])+length+body);answer=b''
  while len(answer)<4:
   data=s.recv(4-len(answer))
   if not data:break
   answer+=data
  s.sendall(b'\xe0\x00')
  return answer[3] if len(answer)==4 and answer[:2]==b'\x20\x02' else -1
positive=connect(True);negative=connect(False)
print(json.dumps({'authenticatedConnack':positive,'anonymousConnack':negative,'transport':'SSH + CT loopback','published':False}))
sys.exit(0 if positive==0 and negative in [4,5] else 1)
'''
# Secret stdout is captured in memory and forwarded to the other verified SSH endpoint.
a=subprocess.run(['ssh','-F',config,'jaylab-proxmox','pct exec 105 -- node -'],input=source,capture_output=True,text=True,timeout=20)
if a.returncode:raise SystemExit('MQTT credential source failed; no retry')
try:json.loads(a.stdout)
except Exception:raise SystemExit('Invalid MQTT credential response')
b=subprocess.run(['ssh','-F',config,'jaylab-proxmox3','pct exec 107 -- python3 -c '+shlex.quote(remote)],input=a.stdout,capture_output=True,text=True,timeout=20)
try:result=json.loads(b.stdout)
except Exception:raise SystemExit('MQTT protocol check failed; no raw output emitted')
print(json.dumps(result));raise SystemExit(b.returncode)
