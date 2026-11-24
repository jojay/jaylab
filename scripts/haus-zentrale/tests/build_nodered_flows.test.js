'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');

const DEVICES_PATH = path.join(__dirname, '..', 'devices.json');
const LOGIC_PATH = path.join(__dirname, '..', 'nodered_logic.js');
const PATCHER_PATH = path.join(__dirname, '..', 'build_nodered_flows.js');

const devicesCatalog = JSON.parse(fs.readFileSync(DEVICES_PATH, 'utf8'));
const logicSource = fs.readFileSync(LOGIC_PATH, 'utf8');

const { patchFlows, validatePatchedFlows } = require('../build_nodered_flows.js');

function createOriginalFlowsFixture(orgValue = 'test-org') {
  const tempDevices = [
    { id: '5f97c41d3a4569c7', device: 'HT-Wohnzimmer|hdm:HomeMaticIP:3014F711A000005BB85F9E0D|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Wohn/Esszimmer' },
    { id: '5d49c9fd7d72aaa1', device: 'Raumthermostat|hdm:HomeMaticIP:3014F711A000289BB85F32B0|THB|BatteryLevel,TemperatureLevel,HumidityLevel|E2:Wohn/Esszimmer' },
    { id: '9f30184fc909eb59', device: 'HT-Arbeitszimmer|hdm:HomeMaticIP:3014F711A000005D585C78C6|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Arbeitszimmer' },
    { id: '67388eb46f124452', device: 'HT-Umkleidezimmer|hdm:HomeMaticIP:3014F711A000005D585C79B6|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Umkleideraum' },
    { id: '44afb5753fe484e9', device: 'HT-Badezimmer|hdm:HomeMaticIP:3014F711A000005D58597571|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E3:Badezimmer' },
    { id: '309a166e4ef1cd0e', device: 'HT-Esseck|hdm:HomeMaticIP:3014F711A000005BB85F9F08|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Wohn/Esszimmer' },
    { id: '25a6533482b563ab', device: 'HT-Vincent|hdm:HomeMaticIP:3014F711A000005398584A0F|TRV|BatteryLevel,ValveTappet,TemperatureLevel|Vincent' },
    { id: '78697b9bd0e99270', device: 'HT-Samuel|hdm:HomeMaticIP:3014F711A000005398584BCF|TRV|BatteryLevel,ValveTappet,TemperatureLevel|Samuel' },
    { id: 'a3c68622a76a26b4', device: 'HT-Lea-Arbeitszimmer|hdm:HomeMaticIP:3014F711A0000053985B4092|TRV|BatteryLevel,ValveTappet,TemperatureLevel|Lea Arbeitszimmer ' },
  ];

  const valveDevices = [
    { id: '89033076a542889c', device: 'HT-Badezimmer|hdm:HomeMaticIP:3014F711A000005D58597571|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E3:Badezimmer' },
    { id: '3388d55b3421d4cf', device: 'HT-Wohnzimmer|hdm:HomeMaticIP:3014F711A000005BB85F9E0D|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Wohn/Esszimmer' },
    { id: 'afdf2b1d5f371f93', device: 'HT-Esseck|hdm:HomeMaticIP:3014F711A000005BB85F9F08|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Wohn/Esszimmer' },
    { id: '6ec2592b04e9d330', device: 'HT-Umkleidezimmer|hdm:HomeMaticIP:3014F711A000005D585C79B6|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Umkleideraum' },
    { id: '0b3c93dc51445532', device: 'HT-Arbeitszimmer|hdm:HomeMaticIP:3014F711A000005D585C78C6|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E2:Arbeitszimmer' },
    { id: '984a0e410ce1ebcc', device: 'HT-Vincent|hdm:HomeMaticIP:3014F711A000005398584A0F|TRV|BatteryLevel,ValveTappet,TemperatureLevel|Vincent' },
    { id: '86f378bad18b550c', device: 'HT-Samuel|hdm:HomeMaticIP:3014F711A000005398584BCF|TRV|BatteryLevel,ValveTappet,TemperatureLevel|Samuel' },
    { id: '405be4b2560a6778', device: 'HT-Lea-Arbeitszimmer|hdm:HomeMaticIP:3014F711A0000053985B4092|TRV|BatteryLevel,ValveTappet,TemperatureLevel|Lea Arbeitszimmer ' },
  ];

  const contactDevices = [
    { id: 'b9a2034c5406d6f8', device: 'Fenster-Arbeitszimmer|hdm:HomeMaticIP:3014F711A000009D585A160F|SWD|ShutterContact,BatteryLevel|E2:Arbeitszimmer' },
    { id: '4fe805aa1e07904b', device: 'Fenster-Bad|hdm:HomeMaticIP:3014F711A000009D585A25E5|SWD|ShutterContact,BatteryLevel|E3:Badezimmer' },
    { id: '8645791dd7a94f61', device: 'Fenster-Esszimmer|hdm:HomeMaticIP:3014F711A000009D5858CD31|SWD|ShutterContact,BatteryLevel|E2:Wohn/Esszimmer' },
    { id: 'f82cb486c4c879d5', device: 'Tür Hauseingang|hdm:HomeMaticIP:3014F711A000009D585A1652|SWD|ShutterContact,BatteryLevel|E0:Haus-Foyer' },
    { id: '691fcfeae11cdd82', device: 'Fenster-EG-Schlafzimmer|hdm:HomeMaticIP:3014F711A000009D585A191E|SWD|ShutterContact,BatteryLevel|E1:Schlaf' },
    { id: 'bdde6a3c77ae108e', device: 'Tür Hauseingang|hdm:HomeMaticIP:3014F711A000009D585A1652|SWD|ShutterContact,BatteryLevel|E0:Haus-Foyer' },
    { id: '8c3b70dd63074028', device: 'Garagentor|hdm:HomeMaticIP:3014F711A000009D585A1636|SWD|ShutterContact,BatteryLevel|E0:Wagenhalle' },
  ];

  return [
    { id: 'fbc07e693f44bb3f', type: 'tab', label: 'Temperatur', disabled: false, info: '', env: [] },
    { id: '1d5dba1e404f98a8', type: 'tab', label: 'Ventilstellung', disabled: false, info: '', env: [] },
    { id: '63f27dde43843cb0', type: 'tab', label: 'Alarm', disabled: false, info: '', env: [] },
    { id: 'a141daf87ef3ad4d', type: 'tab', label: 'Fensterkontakt', disabled: false, info: '', env: [] },
    { id: '361e3c3baf324236', type: 'shc-config', shcip: '192.168.40.231', clientname: 'jaylab', state: 'PAIRED' },
    { id: '2be7c8fd.d795c8', type: 'influxdb', name: 'influxdb', influxdbVersion: '2.0', url: 'https://example.invalid', rejectUnauthorized: true },

    // Temperatur
    {
      id: '3e26163357085eb5',
      type: 'shc-fault',
      z: 'fbc07e693f44bb3f',
      shc: '361e3c3baf324236',
      name: 'debug',
      debug: true,
      x: 110,
      y: 580,
      wires: [tempDevices.map((d) => d.id)],
    },
    {
      id: 'f3d793a5792cb934',
      type: 'inject',
      z: 'fbc07e693f44bb3f',
      name: '',
      props: [{ p: 'payload' }, { p: 'topic', vt: 'str' }],
      repeat: '',
      crontab: '',
      once: false,
      onceDelay: 0.1,
      topic: '',
      payloadType: 'date',
      x: 120,
      y: 320,
      wires: [tempDevices.map((d) => d.id)],
    },
    ...tempDevices.map((d, idx) => ({
      id: d.id,
      type: 'shc-device',
      z: 'fbc07e693f44bb3f',
      shc: '361e3c3baf324236',
      poll: true,
      device: d.device,
      service: 'TemperatureLevel',
      state: '',
      name: '',
      x: 630,
      y: 200 + idx * 80,
      wires: [['04f8f732185167fb']],
    })),
    {
      id: '04f8f732185167fb',
      type: 'join',
      z: 'fbc07e693f44bb3f',
      name: 'bundleforbatch',
      mode: 'custom',
      build: 'array',
      property: 'payload',
      propertyType: 'msg',
      key: 'topic',
      joiner: '\\n',
      joinerType: 'str',
      accumulate: false,
      timeout: '60',
      count: '6',
      x: 1020,
      y: 760,
      wires: [['b4ddb98221589a12']],
    },
    {
      id: 'b4ddb98221589a12',
      type: 'function',
      z: 'fbc07e693f44bb3f',
      name: 'extractTemperature',
      func: 'return msg;',
      outputs: 1,
      noerr: 0,
      initialize: '',
      finalize: '',
      libs: [],
      x: 1270,
      y: 760,
      wires: [['15280adaaa202494']],
    },
    {
      id: '15280adaaa202494',
      type: 'influxdb batch',
      z: 'fbc07e693f44bb3f',
      influxdb: '2be7c8fd.d795c8',
      precision: '',
      retentionPolicy: '',
      name: 'batch-out',
      database: 'database',
      precisionV18FluxV20: 's',
      retentionPolicyV18Flux: '',
      org: orgValue,
      bucket: 'shcbucket',
      x: 1480,
      y: 760,
      wires: [],
    },

    // Ventilstellung
    {
      id: '539efa3c598f68b8',
      type: 'shc-fault',
      z: '1d5dba1e404f98a8',
      shc: '361e3c3baf324236',
      name: 'debug',
      debug: true,
      x: 110,
      y: 460,
      wires: [valveDevices.map((d) => d.id)],
    },
    {
      id: 'c68eed6494d4878b',
      type: 'inject',
      z: '1d5dba1e404f98a8',
      name: '',
      props: [{ p: 'payload' }, { p: 'topic', vt: 'str' }],
      repeat: '',
      crontab: '',
      once: false,
      onceDelay: 0.1,
      topic: '',
      payloadType: 'date',
      x: 120,
      y: 200,
      wires: [valveDevices.map((d) => d.id)],
    },
    ...valveDevices.map((d, idx) => ({
      id: d.id,
      type: 'shc-device',
      z: '1d5dba1e404f98a8',
      shc: '361e3c3baf324236',
      poll: true,
      device: d.device,
      service: 'ValveTappet',
      state: '',
      name: '',
      x: 630,
      y: 160 + idx * 80,
      wires: [['fbfc6f9be4eef383']],
    })),
    {
      id: 'fbfc6f9be4eef383',
      type: 'join',
      z: '1d5dba1e404f98a8',
      name: 'bundleforbatch',
      mode: 'custom',
      build: 'array',
      property: 'payload',
      propertyType: 'msg',
      key: 'topic',
      joiner: '\\n',
      joinerType: 'str',
      accumulate: false,
      timeout: '60',
      count: '5',
      x: 1040,
      y: 720,
      wires: [['32e58a640af51ea7']],
    },
    {
      id: '32e58a640af51ea7',
      type: 'function',
      z: '1d5dba1e404f98a8',
      name: 'extractValveTapperState',
      func: 'return msg;',
      outputs: 1,
      noerr: 0,
      initialize: '',
      finalize: '',
      libs: [],
      x: 1270,
      y: 720,
      wires: [['75da03b2dcac6c63']],
    },
    {
      id: '75da03b2dcac6c63',
      type: 'influxdb batch',
      z: '1d5dba1e404f98a8',
      influxdb: '2be7c8fd.d795c8',
      precision: '',
      retentionPolicy: '',
      name: 'batch-out',
      database: 'database',
      precisionV18FluxV20: 's',
      retentionPolicyV18Flux: '',
      org: orgValue,
      bucket: 'shcbucket',
      x: 1480,
      y: 720,
      wires: [],
    },

    // Fensterkontakt
    {
      id: '97d340e2df33ba59',
      type: 'shc-fault',
      z: 'a141daf87ef3ad4d',
      shc: '361e3c3baf324236',
      name: '',
      debug: true,
      x: 120,
      y: 400,
      wires: [['b9a2034c5406d6f8']],
    },
    {
      id: 'fa1db6e376b7e8e7',
      type: 'inject',
      z: 'a141daf87ef3ad4d',
      name: '',
      props: [{ p: 'payload' }, { p: 'topic', vt: 'str' }],
      repeat: '',
      crontab: '',
      once: false,
      onceDelay: 0.1,
      topic: '',
      payloadType: 'date',
      x: 120,
      y: 480,
      wires: [contactDevices.map((d) => d.id)],
    },
    ...contactDevices.map((d, idx) => ({
      id: d.id,
      type: 'shc-device',
      z: 'a141daf87ef3ad4d',
      shc: '361e3c3baf324236',
      poll: true,
      device: d.device,
      service: 'ShutterContact',
      state: '',
      name: '',
      x: 470,
      y: 340 + idx * 60,
      wires: [['db05161ccdbe3e39']],
    })),
    {
      id: 'db05161ccdbe3e39',
      type: 'join',
      z: 'a141daf87ef3ad4d',
      name: 'bundleforbatch',
      mode: 'custom',
      build: 'array',
      property: 'payload',
      propertyType: 'msg',
      key: 'topic',
      joiner: '\\n',
      joinerType: 'str',
      accumulate: false,
      timeout: '',
      count: '1',
      x: 1100,
      y: 440,
      wires: [['80647d7c85b12d47']],
    },
    {
      id: '80647d7c85b12d47',
      type: 'function',
      z: 'a141daf87ef3ad4d',
      name: 'getWindowEvent',
      func: 'return msg;',
      outputs: 1,
      noerr: 0,
      initialize: '',
      finalize: '',
      libs: [],
      x: 1310,
      y: 440,
      wires: [['94e9b1f46330ce94']],
    },
    {
      id: '94e9b1f46330ce94',
      type: 'influxdb batch',
      z: 'a141daf87ef3ad4d',
      influxdb: '2be7c8fd.d795c8',
      precision: '',
      retentionPolicy: '',
      name: 'batch-out',
      database: 'database',
      precisionV18FluxV20: 's',
      retentionPolicyV18Flux: '',
      org: orgValue,
      bucket: 'shcbucket',
      x: 1540,
      y: 440,
      wires: [],
    },

    // Alarm (untouched legacy tab)
    {
      id: '398d69eb70550590',
      type: 'inject',
      z: '63f27dde43843cb0',
      name: '',
      props: [{ p: 'payload' }, { p: 'topic', vt: 'str' }],
      repeat: '',
      crontab: '',
      once: false,
      onceDelay: 0.1,
      topic: '',
      payloadType: 'date',
      x: 160,
      y: 360,
      wires: [['9b659b8027c6a06d']],
    },
    {
      id: '9b659b8027c6a06d',
      type: 'shc-device',
      z: '63f27dde43843cb0',
      shc: '361e3c3baf324236',
      poll: true,
      device: '-IntrusionDetectionSystem-|intrusionDetectionSystem|INTRUSION_DETECTION_SYSTEM|IntrusionDetectionControl|undefined',
      service: 'IntrusionDetectionControl',
      state: '',
      name: '',
      x: 420,
      y: 360,
      wires: [['0a8797c132205798']],
    },
    {
      id: '0a8797c132205798',
      type: 'switch',
      z: '63f27dde43843cb0',
      name: 'CheckState',
      property: 'payload.state.value',
      propertyType: 'msg',
      rules: [{ t: 'eq', v: 'SYSTEM_ARMED', vt: 'str' }, { t: 'eq', v: 'SYSTEM_DISARMED', vt: 'str' }],
      outputs: 2,
      x: 690,
      y: 360,
      wires: [['e3261aa5f20f7580'], ['e3261aa5f20f7580']],
    },
    {
      id: 'e3261aa5f20f7580',
      type: 'debug',
      z: '63f27dde43843cb0',
      name: '',
      active: true,
      tosidebar: true,
      console: false,
      tostatus: false,
      complete: 'payload',
      targetType: 'msg',
      x: 910,
      y: 360,
      wires: [],
    },
  ];
}

function createFlowMock(initial = {}) {
  const store = new Map(Object.entries(initial));
  return {
    get(key) {
      return store.get(key);
    },
    set(key, val) {
      store.set(key, val);
    },
  };
}

function runNodeRedFunc(funcBody, msg, flowMock, nowMs = 1700000000000) {
  let currentMs = nowMs;
  class MockDate extends Date {
    constructor(...args) {
      if (args.length === 0) {
        super(currentMs);
      } else {
        super(...args);
      }
    }
    static now() {
      return currentMs;
    }
  }
  const wrapped = `(function(msg, flow, Date) { 'use strict';\n${funcBody}\n})`;
  const script = new vm.Script(wrapped);
  const fn = script.runInNewContext({
    Math,
    Number,
    Object,
    Array,
    String,
    Set,
    Map,
    JSON,
    Boolean,
  });
  return {
    invoke(nextMsg, overrideMs) {
      if (typeof overrideMs === 'number') {
        currentMs = overrideMs;
      }
      const res = fn(nextMsg, flowMock, MockDate);
      return res === null || res === undefined ? res : structuredClone(res);
    },
  };
}

test('all poll injects send empty string (Review Focus #1)', () => {
  const orig = createOriginalFlowsFixture('test-org');
  const patched = patchFlows(orig, devicesCatalog, logicSource);

  const validation = validatePatchedFlows(patched, devicesCatalog);
  assert.equal(validation.ok, true, `Validation errors: ${validation.errors.join('; ')}`);

  const protectedTabs = new Set([
    'fbc07e693f44bb3f',
    '1d5dba1e404f98a8',
    'a141daf87ef3ad4d',
    'hz_tab_plugs',
    'hz_tab_climate',
    'hz_tab_sec_health',
  ]);
  const injects = patched.filter((n) => n.type === 'inject' && protectedTabs.has(n.z));
  assert.equal(injects.length, 8);

  for (const id of ['f3d793a5792cb934', 'c68eed6494d4878b', 'fa1db6e376b7e8e7']) {
    const node = injects.find((n) => n.id === id);
    assert.ok(node, `Missing legacy inject ${id}`);
  }

  for (const inj of injects) {
    assert.equal(inj.payloadType, 'str', `Inject ${inj.id} must have payloadType=str`);
    assert.equal(inj.payload, '', `Inject ${inj.id} must have empty string payload`);
    if (Array.isArray(inj.props)) {
      const payloadProp = inj.props.find((p) => p.p === 'payload');
      if (payloadProp && Object.hasOwn(payloadProp, 'vt')) {
        assert.equal(payloadProp.vt, 'str');
      }
      if (payloadProp && Object.hasOwn(payloadProp, 'v')) {
        assert.equal(payloadProp.v, '');
      }
    }
  }
});

test('ShutterContact isolation preserves exact 6 legacy contacts and puts all 9 in contactStatus (Review Focus #4)', () => {
  const orig = createOriginalFlowsFixture('test-org');
  const patched = patchFlows(orig, devicesCatalog, logicSource);

  assert.equal(
    patched.some((n) => n.id === 'f82cb486c4c879d5'),
    false,
    'Duplicate node f82cb486c4c879d5 must be removed',
  );

  const legacyInj = patched.find((n) => n.id === 'fa1db6e376b7e8e7');
  assert.ok(legacyInj);
  assert.equal(legacyInj.repeat, '900');
  assert.equal(legacyInj.once, true);
  assert.equal(legacyInj.onceDelay, '20');
  assert.equal(legacyInj.wires[0].includes('f82cb486c4c879d5'), false);

  const legacyContacts = patched.filter((n) => n.z === 'a141daf87ef3ad4d' && n.type === 'shc-device');
  assert.equal(legacyContacts.length, 6);

  const legacyDeviceIds = new Set(legacyContacts.map((n) => n.device.split('|')[1]));
  const expectedLegacyIds = new Set(
    devicesCatalog.contacts.filter((c) => c.legacyShutterContact).map((c) => c.deviceId),
  );
  assert.deepEqual(legacyDeviceIds, expectedLegacyIds);

  for (const newContact of devicesCatalog.contacts.filter((c) => !c.legacyShutterContact)) {
    assert.equal(legacyDeviceIds.has(newContact.deviceId), false);
  }

  const contactsFn = patched.find((n) => n.id === 'hz_contacts_fn' && n.z === 'hz_tab_sec_health');
  assert.ok(contactsFn);
  for (const contact of devicesCatalog.contacts) {
    assert.ok(contactsFn.func.includes(contact.deviceId), `Missing ${contact.deviceId} in hz_contacts_fn`);
  }
});

test('Temperatur and Ventilstellung add missing TRVs, update join count/timeout, and leave original input & Alarm intact', () => {
  const orig = createOriginalFlowsFixture('test-org');
  const snapshotBefore = JSON.stringify(orig);

  const patched = patchFlows(orig, devicesCatalog, logicSource);
  assert.equal(JSON.stringify(orig), snapshotBefore, 'patchFlows must not mutate originalFlows');

  // Temperatur (11 devices, join count 11, timeout 30)
  const tempDevices = patched.filter((n) => n.z === 'fbc07e693f44bb3f' && n.type === 'shc-device');
  assert.equal(tempDevices.length, 11);
  const tempJoin = patched.find((n) => n.id === '04f8f732185167fb');
  assert.equal(tempJoin.count, '11');
  assert.equal(tempJoin.timeout, '30');

  const tempInj = patched.find((n) => n.id === 'f3d793a5792cb934');
  const tempFault = patched.find((n) => n.id === '3e26163357085eb5');
  for (const trvId of [
    'hdm:HomeMaticIP:3014F711A000005D5859748B',
    'hdm:HomeMaticIP:3014F711A0000053985846BB',
  ]) {
    const dev = tempDevices.find((n) => n.device.split('|')[1] === trvId);
    assert.ok(dev, `Missing TRV ${trvId} in Temperatur`);
    assert.equal(dev.service, 'TemperatureLevel');
    assert.equal(dev.poll, true);
    assert.ok(dev.wires[0].includes('04f8f732185167fb'));
    assert.ok(tempInj.wires[0].includes(dev.id));
    assert.ok(tempFault.wires[0].includes(dev.id));
  }

  // Ventilstellung (10 devices, join count 10, timeout 30)
  const valveDevices = patched.filter((n) => n.z === '1d5dba1e404f98a8' && n.type === 'shc-device');
  assert.equal(valveDevices.length, 10);
  const valveJoin = patched.find((n) => n.id === 'fbfc6f9be4eef383');
  assert.equal(valveJoin.count, '10');
  assert.equal(valveJoin.timeout, '30');

  const valveInj = patched.find((n) => n.id === 'c68eed6494d4878b');
  const valveFault = patched.find((n) => n.id === '539efa3c598f68b8');
  for (const trvId of [
    'hdm:HomeMaticIP:3014F711A000005D5859748B',
    'hdm:HomeMaticIP:3014F711A0000053985846BB',
  ]) {
    const dev = valveDevices.find((n) => n.device.split('|')[1] === trvId);
    assert.ok(dev, `Missing TRV ${trvId} in Ventilstellung`);
    assert.equal(dev.service, 'ValveTappet');
    assert.equal(dev.poll, true);
    assert.ok(dev.wires[0].includes('fbfc6f9be4eef383'));
    assert.ok(valveInj.wires[0].includes(dev.id));
    assert.ok(valveFault.wires[0].includes(dev.id));
  }

  // Alarm untouched
  const origAlarm = orig.filter((n) => n.z === '63f27dde43843cb0');
  const patchedAlarm = patched.filter((n) => n.z === '63f27dde43843cb0');
  assert.deepEqual(patchedAlarm, origAlarm);
});

test('dynamic org, unique IDs, valid wires, and strict idempotency across repeated patchFlows calls', () => {
  const customOrg = 'runtime-org-123';
  const orig = createOriginalFlowsFixture(customOrg);

  const patchedOnce = patchFlows(orig, devicesCatalog, logicSource);
  const patchedTwice = patchFlows(patchedOnce, devicesCatalog, logicSource);

  assert.deepEqual(patchedTwice, patchedOnce, 'Second patchFlows pass must be strictly idempotent');

  const patcherSource = fs.readFileSync(PATCHER_PATH, 'utf8');
  assert.equal(patcherSource.includes(customOrg), false);

  const ids = patchedOnce.map((n) => n.id);
  assert.equal(new Set(ids).size, ids.length, 'All node IDs must be unique');

  const idSet = new Set(ids);
  for (const node of patchedOnce) {
    if (Array.isArray(node.wires)) {
      for (const port of node.wires) {
        for (const target of port) {
          assert.ok(idSet.has(target), `Dangling wire target ${target} on node ${node.id}`);
        }
      }
    }
  }

  const newTabs = new Set(['hz_tab_plugs', 'hz_tab_climate', 'hz_tab_sec_health']);
  const newBatches = patchedOnce.filter((n) => n.type === 'influxdb batch' && newTabs.has(n.z));
  assert.equal(newBatches.length, 5);
  for (const batch of newBatches) {
    assert.equal(batch.influxdb, '2be7c8fd.d795c8');
    assert.equal(batch.bucket, 'shcbucket');
    assert.equal(batch.org, customOrg);
    assert.equal(batch.precisionV18FluxV20, 's');
  }
});

test('validatePatchedFlows rejects unsafe poll injects, duplicate ShutterContact, missing org, dangling wires, and bad onceDelay order', () => {
  const base = patchFlows(createOriginalFlowsFixture('test-org'), devicesCatalog, logicSource);

  // 1. Unsafe boolean inject
  const badBool = structuredClone(base);
  const plugInj = badBool.find((n) => n.id === 'hz_plugs_inject');
  plugInj.payloadType = 'bool';
  plugInj.payload = true;
  assert.equal(validatePatchedFlows(badBool, devicesCatalog).ok, false);

  // 2. Date payloadType in touched legacy inject
  const badDate = structuredClone(base);
  const tempInj = badDate.find((n) => n.id === 'f3d793a5792cb934');
  tempInj.payloadType = 'date';
  assert.equal(validatePatchedFlows(badDate, devicesCatalog).ok, false);

  // 3. Re-added duplicate f82cb486c4c879d5
  const badDup = structuredClone(base);
  badDup.push({
    id: 'f82cb486c4c879d5',
    type: 'shc-device',
    z: 'a141daf87ef3ad4d',
    shc: '361e3c3baf324236',
    poll: true,
    device: 'Tür Hauseingang|hdm:HomeMaticIP:3014F711A000009D585A1652|SWD|ShutterContact|E0:Haus-Foyer',
    service: 'ShutterContact',
    wires: [['db05161ccdbe3e39']],
  });
  assert.equal(validatePatchedFlows(badDup, devicesCatalog).ok, false);

  // 4. New contact accidentally added into Fensterkontakt
  const badExtraContact = structuredClone(base);
  badExtraContact.push({
    id: 'hz_bad_contact',
    type: 'shc-device',
    z: 'a141daf87ef3ad4d',
    shc: '361e3c3baf324236',
    poll: true,
    device: 'Werkstattfenster|hdm:HomeMaticIP:3014F711A000009398584454|SWD|ShutterContact|Keller',
    service: 'ShutterContact',
    wires: [['db05161ccdbe3e39']],
  });
  assert.equal(validatePatchedFlows(badExtraContact, devicesCatalog).ok, false);

  // 5. Dangling wire
  const badWire = structuredClone(base);
  badWire.find((n) => n.id === 'hz_climate_inject').wires = [['missing_node_id']];
  assert.equal(validatePatchedFlows(badWire, devicesCatalog).ok, false);

  // 6. Missing org
  const badOrg = structuredClone(base);
  badOrg.find((n) => n.id === 'hz_climate_influx').org = '';
  assert.equal(validatePatchedFlows(badOrg, devicesCatalog).ok, false);

  // 7. Wrong startup onceDelay order (contacts before health getDevice)
  const badDelay = structuredClone(base);
  badDelay.find((n) => n.id === 'hz_contacts_inject').onceDelay = '10';
  assert.equal(validatePatchedFlows(badDelay, devicesCatalog).ok, false);

  // 8. Broken syntax in generated func
  const badFunc = structuredClone(base);
  badFunc.find((n) => n.id === 'hz_climate_fn').func = 'const x = (;';
  assert.equal(validatePatchedFlows(badFunc, devicesCatalog).ok, false);

  // 9. poll: true on deviceHealth all-devices / all-services nodes must be rejected
  const badHealthPoll = structuredClone(base);
  badHealthPoll.find((n) => n.id === 'hz_health_shc_devices').poll = true;
  assert.equal(validatePatchedFlows(badHealthPoll, devicesCatalog).ok, false);
});

test('all generated Function-Node func strings compile cleanly in vm.Script and execute end-to-end with mock msg/flow', () => {
  const patched = patchFlows(createOriginalFlowsFixture('test-org'), devicesCatalog, logicSource);
  const newTabs = new Set(['hz_tab_plugs', 'hz_tab_climate', 'hz_tab_sec_health']);
  const newFuncs = patched.filter((n) => n.type === 'function' && newTabs.has(n.z));
  assert.equal(newFuncs.length, 5);

  for (const fnNode of newFuncs) {
    assert.equal(/\bnode\.warn\b/.test(fnNode.func), false, `${fnNode.id} must not use node.warn`);
    assert.equal(/\brequire\s*\(/.test(fnNode.func), false, `${fnNode.id} must not use require()`);
    assert.equal(fnNode.func.includes('Ela-Wandheizung'), false, `${fnNode.id} must not expose raw Ela-Wandheizung`);
    assert.doesNotThrow(
      () => new vm.Script(`(async function(msg, flow) {\n${fnNode.func}\n})`),
      `${fnNode.id} failed vm.Script compile`,
    );
  }

  // 1. Test hz_plugs_fn
  const plugsFlow = createFlowMock();
  const plugsFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_plugs_fn').func, {}, plugsFlow, 1700000000000);
  const WASCH_ID = 'hdm:HomeMaticIP:3014F711A0000493985923FF';
  const CREALITY_ID = 'hdm:ZigBee:842712fffebbc43f';
  const SPRINGER_ID = 'hdm:HomeMaticIP:3014F711A00004953859DEF1';

  assert.equal(plugsFn.invoke({ payload: null }), null);

  const pmOut = plugsFn.invoke({
    payload: [
      { id: 'PowerMeter', deviceId: WASCH_ID, state: { powerConsumption: 0, energyConsumption: 1000 } },
      { id: 'PowerMeter', deviceId: CREALITY_ID, state: { powerConsumption: 80, energyConsumption: 2000 } },
      { id: 'PowerMeter', deviceId: SPRINGER_ID, state: null },
    ],
  }, 1700000005000);
  assert.ok(pmOut);
  assert.equal(pmOut.payload.some((p) => p.measurement === 'powerMeter' && p.tags.deviceId === WASCH_ID), true);
  assert.equal(pmOut.payload.some((p) => p.tags.deviceId === SPRINGER_ID), false);
  const crealityInit = pmOut.payload.find((p) => p.measurement === 'applianceState' && p.tags.deviceId === CREALITY_ID);
  assert.ok(crealityInit);
  assert.equal(crealityInit.fields.stateCode, 1);

  const psOut = plugsFn.invoke({
    payload: [
      { id: 'PowerSwitch', deviceId: WASCH_ID, state: { switchState: 'ON' } },
      { id: 'PowerSwitch', deviceId: CREALITY_ID, state: { switchState: 'ON' } },
      { id: 'PowerSwitch', deviceId: SPRINGER_ID, state: { switchState: 'OFF' } },
    ],
  }, 1700000006000);
  assert.ok(psOut);
  const springerPt = psOut.payload.find((p) => p.measurement === 'powerMeter' && p.tags.deviceId === SPRINGER_ID);
  assert.ok(springerPt);
  assert.equal(springerPt.tags.deviceName, 'Springer');
  assert.deepEqual(springerPt.fields, { switchOn: 0 });
  const waschState0 = psOut.payload.find((p) => p.measurement === 'applianceState' && p.tags.deviceId === WASCH_ID);
  assert.ok(waschState0);
  assert.equal(waschState0.fields.stateCode, 1);

  // Hold >= 10 W for 60s -> Waschmaschine Läuft (2), Creality Druckt (2)
  plugsFn.invoke({
    payload: [
      { id: 'PowerMeter', deviceId: WASCH_ID, state: { powerConsumption: 500, energyConsumption: 1005 } },
      { id: 'PowerMeter', deviceId: CREALITY_ID, state: { powerConsumption: 95, energyConsumption: 2002 } },
    ],
  }, 1700000010000);
  const runOut = plugsFn.invoke({
    payload: [
      { id: 'PowerMeter', deviceId: WASCH_ID, state: { powerConsumption: 500, energyConsumption: 1020 } },
      { id: 'PowerMeter', deviceId: CREALITY_ID, state: { powerConsumption: 95, energyConsumption: 2005 } },
    ],
  }, 1700000070000);
  assert.ok(runOut);
  const waschRun = runOut.payload.find((p) => p.measurement === 'applianceState' && p.tags.deviceId === WASCH_ID);
  assert.ok(waschRun);
  assert.equal(waschRun.fields.stateCode, 2);
  assert.equal(waschRun.fields.stateText, 'Läuft');
  const crealityRun = runOut.payload.find((p) => p.measurement === 'applianceState' && p.tags.deviceId === CREALITY_ID);
  assert.ok(crealityRun);
  assert.equal(crealityRun.fields.stateCode, 2);
  assert.equal(crealityRun.fields.stateText, 'Druckt');

  // 2. Test hz_climate_fn
  const climateFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_climate_fn').func, {}, createFlowMock(), 1700000008000);
  const rccOut = climateFn.invoke({
    payload: [
      {
        id: 'RoomClimateControl',
        deviceId: 'roomClimateControl_hz_1',
        state: {
          operationMode: 'AUTOMATIC',
          setpointTemperature: 21.5,
          ventilationMode: false,
          boostMode: false,
          summerMode: false,
          hasDemand: true,
        },
      },
    ],
  });
  assert.ok(rccOut);
  assert.equal(rccOut.payload.length, 1);
  assert.equal(rccOut.payload[0].measurement, 'roomClimate');
  assert.equal(rccOut.payload[0].tags.room, 'E2 Wohn-/Eßzimmer');
  assert.equal(rccOut.payload[0].fields.setpoint, 21.5);

  // 3. Test hz_sec_fn
  const secFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_sec_fn').func, {}, createFlowMock(), 1700000010000);
  const secOut = secFn.invoke({
    payload: [
      { id: 'IntrusionDetectionControl', deviceId: 'intrusionDetectionSystem', state: { value: 'SYSTEM_DISARMED' } },
      { id: 'SurveillanceAlarm', deviceId: 'intrusionDetectionSystem', state: { value: 'ALARM_OFF' } },
      { id: 'PresenceSimulationConfiguration', deviceId: 'presenceSimulationService', state: { enabled: false } },
    ],
  });
  assert.ok(secOut);
  assert.equal(secOut.payload.length, 3);
  assert.ok(secOut.payload.every((p) => p.measurement === 'securityStatus'));

  // 4. Test hz_health_fn + hz_contacts_fn sharing the same flow context
  const secHealthFlow = createFlowMock();
  const healthFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_health_fn').func, {}, secHealthFlow, 1700000012000);
  const contactsFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_contacts_fn').func, {}, secHealthFlow, 1700000015000);

  const physicalDevices = [
    ...devicesCatalog.climateSensors
      .filter((s) => devicesCatalog.physicalShcModels.includes(s.model))
      .map((s) => ({ id: s.deviceId, name: s.shcName, deviceModel: s.model, status: 'AVAILABLE', roomId: 'hz_raw' })),
    ...devicesCatalog.contacts.map((c) => ({
      id: c.deviceId,
      name: c.shcName,
      deviceModel: 'SWD',
      status: c.canonicalName === 'Tür Hauseingang' ? 'UNAVAILABLE' : c.canonicalName === 'Garagentor' ? 'UNDEFINED' : 'AVAILABLE',
      roomId: 'hz_raw',
    })),
    ...devicesCatalog.smartPlugs.map((p) => ({
      id: p.deviceId,
      name: p.shcName,
      deviceModel: p.model,
      status: p.deviceId === SPRINGER_ID ? 'UNDEFINED' : 'AVAILABLE',
      roomId: 'hz_raw',
    })),
    {
      id: devicesCatalog.systemDevices.camera3yes.deviceId,
      name: devicesCatalog.systemDevices.camera3yes.shcName,
      deviceModel: devicesCatalog.systemDevices.camera3yes.model,
      status: 'UNAVAILABLE',
      roomId: 'hz_raw',
    },
  ];
  const nonPhysicalDevices = devicesCatalog.roomClimateControls.map((r) => ({
    id: r.deviceId,
    name: '-RoomClimateControl-',
    deviceModel: 'ROOM_CLIMATE_CONTROL',
    status: 'AVAILABLE',
  }));

  // First call with devices waits for services
  assert.equal(healthFn.invoke({ payload: [...physicalDevices, ...nonPhysicalDevices] }, 1700000012000), null);

  // Second call with services emits 25 deviceHealth points with canonical names & rooms
  const healthOut = healthFn.invoke({
    payload: [
      {
        id: 'CameraNotification',
        deviceId: devicesCatalog.systemDevices.camera3yes.deviceId,
        faults: { entries: [{ type: 'COMMUNICATION_ERROR' }] },
      },
    ],
  }, 1700000012050);
  assert.ok(healthOut);
  assert.equal(healthOut.payload.length, 25);

  const springerHealth = healthOut.payload.find((p) => p.tags.deviceId === SPRINGER_ID);
  assert.equal(springerHealth.tags.deviceName, 'Springer');
  assert.equal(springerHealth.tags.room, 'E1 Schlafzimmer Eltern');
  assert.equal(springerHealth.fields.available, 0);

  const camHealth = healthOut.payload.find((p) => p.tags.deviceId === devicesCatalog.systemDevices.camera3yes.deviceId);
  assert.equal(camHealth.tags.deviceName, 'Außenkamera 3yes');
  assert.equal(camHealth.fields.faultCount, 1);

  // Now hz_contacts_fn reads hzDeviceStatusById populated by hz_health_fn
  const allContactEvents = devicesCatalog.contacts.map((c) => ({
    id: 'ShutterContact',
    deviceId: c.deviceId,
    state: { value: 'OPEN' },
  }));
  const contactsOut = contactsFn.invoke({ payload: allContactEvents }, 1700000015000);
  assert.ok(contactsOut);
  assert.equal(contactsOut.payload.length, 9);

  const doorPt = contactsOut.payload.find((p) => p.tags.deviceName === 'Tür Hauseingang');
  assert.deepEqual(doorPt.fields, { state: 'UNAVAILABLE', isOpen: 0, available: 0 });
  const garagePt = contactsOut.payload.find((p) => p.tags.deviceName === 'Garagentor');
  assert.deepEqual(garagePt.fields, { state: 'UNAVAILABLE', isOpen: 0, available: 0 });
  const werkstattPt = contactsOut.payload.find((p) => p.tags.deviceName === 'Werkstattfenster');
  assert.deepEqual(werkstattPt.fields, { state: 'OPEN', isOpen: 1, available: 1 });
});

test('hz_health_fn rejects premature startup emit before non-empty servicesSnapshot and preserves full snapshot on single-device Long-Poll updates', () => {
  const patched = patchFlows(createOriginalFlowsFixture('test-org'), devicesCatalog, logicSource);
  const devNode = patched.find((n) => n.id === 'hz_health_shc_devices');
  const svcNode = patched.find((n) => n.id === 'hz_health_shc_services');
  assert.equal(devNode.poll, false);
  assert.equal(svcNode.poll, false);

  const secHealthFlow = createFlowMock();
  const healthFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_health_fn').func, {}, secHealthFlow, 1700000012000);
  const contactsFn = runNodeRedFunc(patched.find((n) => n.id === 'hz_contacts_fn').func, {}, secHealthFlow, 1700000015000);

  const DOOR_ID = 'hdm:HomeMaticIP:3014F711A000009D585A1652';
  const GARAGE_ID = 'hdm:HomeMaticIP:3014F711A000009D585A1636';
  const WERKSTATT_ID = 'hdm:HomeMaticIP:3014F711A000009398584454';
  const SPRINGER_ID = 'hdm:HomeMaticIP:3014F711A00004953859DEF1';
  const CAM_ID = devicesCatalog.systemDevices.camera3yes.deviceId;

  const all38 = [
    ...devicesCatalog.climateSensors
      .filter((s) => devicesCatalog.physicalShcModels.includes(s.model))
      .map((s) => ({ '@type': 'device', id: s.deviceId, name: s.shcName, deviceModel: s.model, status: 'AVAILABLE', roomId: 'hz_raw' })),
    ...devicesCatalog.contacts.map((c) => ({
      '@type': 'device',
      id: c.deviceId,
      name: c.shcName,
      deviceModel: 'SWD',
      status: c.deviceId === DOOR_ID ? 'UNAVAILABLE' : c.deviceId === GARAGE_ID ? 'UNDEFINED' : 'AVAILABLE',
      roomId: 'hz_raw',
    })),
    ...devicesCatalog.smartPlugs.map((p) => ({
      '@type': 'device',
      id: p.deviceId,
      name: p.shcName,
      deviceModel: p.model,
      status: p.deviceId === SPRINGER_ID ? 'UNDEFINED' : 'AVAILABLE',
      roomId: 'hz_raw',
    })),
    {
      '@type': 'device',
      id: CAM_ID,
      name: devicesCatalog.systemDevices.camera3yes.shcName,
      deviceModel: devicesCatalog.systemDevices.camera3yes.model,
      status: 'UNAVAILABLE',
      roomId: 'hz_raw',
    },
    ...devicesCatalog.roomClimateControls.map((r) => ({
      '@type': 'device',
      id: r.deviceId,
      name: '-RoomClimateControl-',
      deviceModel: 'ROOM_CLIMATE_CONTROL',
      status: 'AVAILABLE',
    })),
    { '@type': 'device', id: 'ventilationService', name: '-VentilationService-', deviceModel: 'VENTILATION_SERVICE', status: 'AVAILABLE' },
    { '@type': 'device', id: 'intrusionDetectionSystem', name: '-IntrusionDetectionSystem-', deviceModel: 'INTRUSION_DETECTION_SYSTEM', status: 'AVAILABLE' },
    { '@type': 'device', id: 'presenceSimulationService', name: '-PresenceSimulationService-', deviceModel: 'PRESENCE_SIMULATION_SERVICE', status: 'AVAILABLE' },
    { '@type': 'device', id: 'hueBridgeManager', name: '-HueBridgeManager-', deviceModel: 'HUE_BRIDGE_MANAGER', status: 'AVAILABLE' },
  ];
  assert.equal(all38.length, 38);

  // (b) Startup devices snapshot before services must emit null (never faultCount: 0), even if an empty services array arrives first
  assert.equal(healthFn.invoke({ payload: all38 }, 1700000012000), null);
  assert.equal(healthFn.invoke({ topic: 'all', payload: [] }, 1700000012010), null);

  // Once non-empty services snapshot arrives, all 25 devices emit with real faultCount
  const initialOut = healthFn.invoke({
    topic: 'all',
    payload: [
      { '@type': 'DeviceServiceData', id: 'CameraNotification', deviceId: CAM_ID, faults: { entries: [{ type: 'COMMUNICATION_ERROR' }] } },
    ],
  }, 1700000012050);
  assert.ok(initialOut);
  assert.equal(initialOut.payload.length, 25);
  assert.equal(initialOut.payload.find((p) => p.tags.deviceId === CAM_ID).fields.faultCount, 1);

  // (a) Single-device Long-Poll as plain object AND as 1-element array must merge incrementally without wiping the 38-device snapshot or hzDeviceStatusById
  const singleObjOut = healthFn.invoke({
    payload: { '@type': 'device', id: GARAGE_ID, name: 'Garagentor', deviceModel: 'SWD', status: 'AVAILABLE' },
  }, 1700000020000);
  assert.ok(singleObjOut);
  assert.equal(singleObjOut.payload.length, 25, 'Plain single-device Long-Poll must keep all 25 physical devices');
  assert.equal(secHealthFlow.get('hzDevicesSnapshot').length, 38);

  const singleArrayOut = healthFn.invoke({
    payload: [{ '@type': 'device', id: DOOR_ID, name: 'Tür Hauseingang', deviceModel: 'SWD', status: 'AVAILABLE' }],
  }, 1700000025000);
  assert.ok(singleArrayOut);
  assert.equal(singleArrayOut.payload.length, 25, '1-element device array Long-Poll must NOT wipe hzDevicesSnapshot');
  assert.equal(secHealthFlow.get('hzDevicesSnapshot').length, 38);

  const statusMap = secHealthFlow.get('hzDeviceStatusById');
  assert.equal(statusMap[GARAGE_ID], 'AVAILABLE');
  assert.equal(statusMap[DOOR_ID], 'AVAILABLE');
  assert.equal(statusMap[WERKSTATT_ID], 'AVAILABLE');
  assert.equal(statusMap[SPRINGER_ID], 'UNDEFINED');
  assert.equal(statusMap[CAM_ID], 'UNAVAILABLE');

  // Verify hz_contacts_fn still sees accurate statuses for other contacts after 1-element Long-Poll
  const contactsOut = contactsFn.invoke({
    payload: [
      { id: 'ShutterContact', deviceId: WERKSTATT_ID, state: { value: 'CLOSED' } },
      { id: 'ShutterContact', deviceId: DOOR_ID, state: { value: 'OPEN' } },
    ],
  }, 1700000026000);
  assert.ok(contactsOut);
  assert.deepEqual(contactsOut.payload.find((p) => p.tags.deviceId === WERKSTATT_ID).fields, {
    state: 'CLOSED',
    isOpen: 0,
    available: 1,
  });
  assert.deepEqual(contactsOut.payload.find((p) => p.tags.deviceId === DOOR_ID).fields, {
    state: 'OPEN',
    isOpen: 1,
    available: 1,
  });
});

test('CLI builds validated flows file and exits non-zero on invalid input', () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hz-flows-'));
  try {
    const inPath = path.join(tmpDir, 'in.json');
    const outPath = path.join(tmpDir, 'out.json');
    fs.writeFileSync(inPath, JSON.stringify(createOriginalFlowsFixture('cli-org'), null, 2), 'utf8');

    const okRes = spawnSync(process.execPath, [PATCHER_PATH, inPath, outPath], { encoding: 'utf8' });
    assert.equal(okRes.status, 0, okRes.stderr);
    const written = JSON.parse(fs.readFileSync(outPath, 'utf8'));
    assert.equal(validatePatchedFlows(written, devicesCatalog).ok, true);

    const badInPath = path.join(tmpDir, 'bad.json');
    const badOutPath = path.join(tmpDir, 'bad-out.json');
    const broken = createOriginalFlowsFixture('cli-org').filter((n) => n.type !== 'influxdb batch');
    fs.writeFileSync(badInPath, JSON.stringify(broken, null, 2), 'utf8');

    const failRes = spawnSync(process.execPath, [PATCHER_PATH, badInPath, badOutPath], { encoding: 'utf8' });
    assert.notEqual(failRes.status, 0);
    assert.equal(fs.existsSync(badOutPath), false);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
});
