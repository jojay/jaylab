'use strict';

// Execute inside CT 105 with node on stdin; no credentials leave that container.
const fs = require('fs');
const crypto = require('crypto');
const dns = require('dns').promises;
const { BoschSmartHomeBridgeBuilder } = require('/home/jay/.node-red/node_modules/bosch-smart-home-bridge');
const base = '/home/jay/.node-red';

async function main() {
    const config = JSON.parse(fs.readFileSync(`${base}/.config.projects.json`));
    const project = config.activeProject;
    if (!project || !/^[a-zA-Z0-9_-]+$/.test(project)) throw new Error('Invalid active project');
    const directory = `${base}/projects/${project}`;
    const flows = JSON.parse(fs.readFileSync(`${directory}/flows.json`));
    let credentials = JSON.parse(fs.readFileSync(`${directory}/flows_cred.json`));
    if (credentials.$) {
        const key = crypto.createHash('sha256').update(config.projects[project].credentialSecret).digest();
        const decipher = crypto.createDecipheriv('aes-256-ctr', key, Buffer.from(credentials.$.slice(0, 32), 'hex'));
        credentials = JSON.parse(decipher.update(credentials.$.slice(32), 'base64', 'utf8') + decipher.final('utf8'));
    }
    const node = flows.find(value => value.type === 'shc-config');
    if (!node || node.state !== 'PAIRED') throw new Error('No paired SHC configuration');
    const credential = credentials[node.id];
    // IPv6 records exist, but that path has not passed the live check.
    const addresses = await dns.resolve4('shc.jaylab.local');
    if (addresses.length !== 1 || !addresses[0].startsWith('192.168.40.')) throw new Error('Unexpected SHC address');
    const testedHost = addresses[0];
    const quiet = { fine() {}, debug() {}, info() {}, warn() {}, error() {}, log() {} };
    const client = BoschSmartHomeBridgeBuilder.builder()
        .withHost(testedHost)
        .withClientCert(credential.cert)
        .withClientPrivateKey(credential.key)
        .withLogger(quiet)
        .withIgnoreCertificateCheck(false)
        .build().getBshcClient();
    console.log(JSON.stringify({ project, configuredHost: node.shcip, testedName: 'shc.jaylab.local', testedHost, family: 4 }));
    // Only GET methods. Do not pair, subscribe, deploy flows, or trigger scenarios.
    for (const method of ['getInformation', 'getRooms', 'getDevices', 'getDeviceServices', 'getScenarios']) {
        try {
            const response = await new Promise((resolve, reject) => client[method]().subscribe(resolve, reject));
            const data = response.parsedResponse || response._parsedResponse;
            if (!data) throw new Error('Empty response');
            console.log(JSON.stringify({ method, ok: true, count: Array.isArray(data) ? data.length : undefined }));
        } catch (error) {
            // Never serialize the original error or request: they may contain credentials.
            console.log(JSON.stringify({ method, ok: false, errorType: error.errorType, code: error.cause?.code }));
            process.exitCode = 1;
        }
    }
}

const watchdog = setTimeout(() => { console.log('{"ok":false,"code":"TIMEOUT"}'); process.exit(1); }, 30000);
main().catch(() => { console.log('{"ok":false,"code":"LOCAL_CONFIGURATION_ERROR"}'); process.exitCode = 1; })
    .finally(() => clearTimeout(watchdog));
