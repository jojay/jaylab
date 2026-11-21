import json,ssl,urllib.request,urllib.error,hashlib
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):return None
context=ssl.create_default_context(cadata=payload['ca']);opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect(),urllib.request.HTTPSHandler(context=context))
origin='https://localhost:1880'
def call(token=None,method='GET',invalid_version=False):
 headers={}
 if token:headers['Authorization']='Bearer '+token
 data=None
 if method=='POST':data=b'[]';headers['Content-Type']='application/json'
 if invalid_version:headers['Node-RED-API-Version']='v99-jaylab-safety-check'
 request=urllib.request.Request(origin+'/flows',data=data,headers=headers,method=method)
 try:
  with opener.open(request,timeout=10) as response:return response.status,response.read()
 except urllib.error.HTTPError as error:return error.code,b''
try:
 status,body=call(payload['token']);nodes=json.loads(body) if status==200 else []
 before=hashlib.sha256(body).hexdigest()
 anonymous,_=call();invalid,_=call('0'*64);write,_=call(payload['token'],'POST',True)
 after_status,after=call(payload['token'])
 result={'tlsVerified':True,'authenticatedGet':status,'flowNodes':len(nodes) if isinstance(nodes,list) else None,'anonymousGet':anonymous,'invalidTokenGet':invalid,'writeDenied':write,'flowsUnchanged':after_status==200 and hashlib.sha256(after).hexdigest()==before}
 print(json.dumps(result))
 if not(status==200 and anonymous in [401,403] and invalid in [401,403] and write in [401,403] and result['flowsUnchanged']):raise SystemExit(1)
except Exception:
 print('{"ok":false,"code":"NODERED_API_CHECK_FAILED"}');raise SystemExit(1)
