"""Run inside CT 110; regular credentials arrive through SSH stdin only."""
import base64
import http.cookiejar
import json
import urllib.error
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main(payload):
    origin = 'http://127.0.0.1:8086'
    cookies = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}), NoRedirect(),
        urllib.request.HTTPCookieProcessor(cookies))
    headers = {}
    if payload['mode'] == 'token':
        headers['Authorization'] = 'Token ' + payload['secret']
    else:
        basic = base64.b64encode((payload['user'] + ':' + payload['secret']).encode()).decode()
        request = urllib.request.Request(origin + '/api/v2/signin', data=b'',
                                         headers={'Authorization': 'Basic ' + basic}, method='POST')
        with opener.open(request, timeout=8) as response:
            print(json.dumps({'operation': 'signin', 'status': response.status}))
    try:
        for endpoint in ['orgs', 'buckets']:
            request = urllib.request.Request(origin + '/api/v2/' + endpoint, headers=headers)
            with opener.open(request, timeout=8) as response:
                data = json.load(response)
                print(json.dumps({'operation': endpoint, 'status': response.status,
                                  'names': [row.get('name') for row in data.get(endpoint, [])]}))
    finally:
        if payload['mode'] != 'token' and len(cookies):
            request = urllib.request.Request(origin + '/api/v2/signout', data=b'', method='POST')
            with opener.open(request, timeout=8) as response:
                print(json.dumps({'operation': 'signout', 'status': response.status}))


# The fixed bootstrap supplies payload. Never print exceptions or credentials.
try:
    main(payload)
except urllib.error.HTTPError as error:
    print(json.dumps({'ok': False, 'httpStatus': error.code}))
    raise SystemExit(1)
except Exception:
    print('{"ok":false,"code":"INFLUX_ACCESS_FAILED"}')
    raise SystemExit(1)
