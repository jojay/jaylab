'use strict';

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const SHC_CONFIG_ID = '361e3c3baf324236';
const INFLUX_CONFIG_ID = '2be7c8fd.d795c8';
const INFLUX_BUCKET = 'shcbucket';

const TAB_TEMPERATUR = 'fbc07e693f44bb3f';
const TAB_VENTILSTELLUNG = '1d5dba1e404f98a8';
const TAB_FENSTERKONTAKT = 'a141daf87ef3ad4d';

const TAB_HZ_PLUGS = 'hz_tab_plugs';
const TAB_HZ_CLIMATE = 'hz_tab_climate';
const TAB_HZ_SEC_HEALTH = 'hz_tab_sec_health';

const DUPLICATE_DOOR_NODE_ID = 'f82cb486c4c879d5';

const LEGACY_IDS = {
  tempFault: '3e26163357085eb5',
  tempInject: 'f3d793a5792cb934',
  tempJoin: '04f8f732185167fb',
  tempInflux: '15280adaaa202494',
  valveFault: '539efa3c598f68b8',
  valveInject: 'c68eed6494d4878b',
  valveJoin: 'fbfc6f9be4eef383',
  contactInject: 'fa1db6e376b7e8e7',
};

const MISSING_TRVS = [
  {
    tempNodeId: 'hz_temp_eg_schlafzimmer',
    valveNodeId: 'hz_valve_eg_schlafzimmer',
    deviceId: 'hdm:HomeMaticIP:3014F711A000005D5859748B',
    deviceString:
      'HT-EG-Schlafzimmer|hdm:HomeMaticIP:3014F711A000005D5859748B|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E1:Schlaf',
    tempY: 920,
    valveY: 820,
  },
  {
    tempNodeId: 'hz_temp_ankleidezimmer',
    valveNodeId: 'hz_valve_ankleidezimmer',
    deviceId: 'hdm:HomeMaticIP:3014F711A0000053985846BB',
    deviceString:
      'HT-Ankleidezimmer|hdm:HomeMaticIP:3014F711A0000053985846BB|TRV|BatteryLevel,ValveTappet,TemperatureLevel|E3:Ankleidezimmer',
    tempY: 1000,
    valveY: 900,
  },
];

function loadDefaultDevices() {
  return JSON.parse(fs.readFileSync(path.join(__dirname, 'devices.json'), 'utf8'));
}

function loadDefaultLogicSource() {
  return fs.readFileSync(path.join(__dirname, 'nodered_logic.js'), 'utf8');
}

function extractDeviceId(shcNode) {
  if (!shcNode || typeof shcNode.device !== 'string') {
    return '';
  }
  const parts = shcNode.device.split('|');
  return parts.length >= 2 ? parts[1] : '';
}

function resolveInfluxOrg(flows) {
  const preferred = flows.find(
    (n) => n.id === LEGACY_IDS.tempInflux && typeof n.org === 'string' && n.org.trim() !== '',
  );
  if (preferred) {
    return preferred.org;
  }
  const fallback = flows.find(
    (n) =>
      n.type === 'influxdb batch' &&
      n.influxdb === INFLUX_CONFIG_ID &&
      typeof n.org === 'string' &&
      n.org.trim() !== '',
  );
  if (fallback) {
    return fallback.org;
  }
  throw new Error('Kein gültiger org-Wert in einem bestehenden influxdb-batch-Node gefunden.');
}

function sanitizeInjectNode(node) {
  node.payloadType = 'str';
  node.payload = '';
  if (Array.isArray(node.props)) {
    node.props = node.props.map((prop) => {
      if (prop && prop.p === 'payload') {
        const cleaned = { p: 'payload' };
        if (Object.hasOwn(prop, 'vt')) {
          cleaned.vt = 'str';
        }
        if (Object.hasOwn(prop, 'v')) {
          cleaned.v = '';
        }
        return cleaned;
      }
      return prop;
    });
  } else {
    node.props = [{ p: 'payload' }, { p: 'topic', vt: 'str' }];
  }
}

function appendUniqueWire(node, targetId) {
  if (!node) {
    return;
  }
  if (!Array.isArray(node.wires) || node.wires.length === 0) {
    node.wires = [[]];
  }
  if (!Array.isArray(node.wires[0])) {
    node.wires[0] = [];
  }
  if (!node.wires[0].includes(targetId)) {
    node.wires[0].push(targetId);
  }
}

function makeTabNode(id, label, info) {
  return {
    id,
    type: 'tab',
    label,
    disabled: false,
    info,
    env: [],
  };
}

function makeInjectNode({ id, z, name, repeat, once, onceDelay, x, y, wires }) {
  return {
    id,
    type: 'inject',
    z,
    name,
    props: [{ p: 'payload' }, { p: 'topic', vt: 'str' }],
    repeat,
    crontab: '',
    once,
    onceDelay,
    topic: '',
    payload: '',
    payloadType: 'str',
    x,
    y,
    wires,
  };
}

function makeShcDeviceNode({ id, z, poll, device, service, name, x, y, wires }) {
  return {
    id,
    type: 'shc-device',
    z,
    shc: SHC_CONFIG_ID,
    poll,
    device,
    service,
    state: '',
    name,
    x,
    y,
    wires,
  };
}

function makeFunctionNode({ id, z, name, func, x, y, wires }) {
  return {
    id,
    type: 'function',
    z,
    name,
    func,
    outputs: 1,
    timeout: 0,
    noerr: 0,
    initialize: '',
    finalize: '',
    libs: [],
    x,
    y,
    wires,
  };
}

function makeInfluxBatchNode({ id, z, name, org, x, y }) {
  return {
    id,
    type: 'influxdb batch',
    z,
    influxdb: INFLUX_CONFIG_ID,
    precision: '',
    retentionPolicy: '',
    name,
    database: 'database',
    precisionV18FluxV20: 's',
    retentionPolicyV18Flux: '',
    org,
    bucket: INFLUX_BUCKET,
    x,
    y,
    wires: [],
  };
}

function buildEmbeddedFunc(logicSource, headerCode, bodyCode) {
  return `${logicSource.trim()}\n\n${headerCode.trim()}\n\n${bodyCode.trim()}\n`;
}

function buildSmartPlugsMap(devicesConfig) {
  const entries = {};
  for (const plug of devicesConfig.smartPlugs) {
    entries[plug.deviceId] = {
      deviceId: plug.deviceId,
      canonicalName: plug.canonicalName,
      room: plug.room,
      applianceConfig: plug.applianceConfig,
    };
  }
  return entries;
}

function buildRccMap(devicesConfig) {
  const entries = {};
  for (const rcc of devicesConfig.roomClimateControls) {
    entries[rcc.deviceId] = {
      deviceId: rcc.deviceId,
      matrixRoom: rcc.matrixRoom,
      shcRoom: rcc.shcRoom,
    };
  }
  return entries;
}

function buildContactsMap(devicesConfig) {
  const entries = {};
  for (const contact of devicesConfig.contacts) {
    entries[contact.deviceId] = {
      deviceId: contact.deviceId,
      canonicalName: contact.canonicalName,
      shcRoom: contact.shcRoom,
      matrixRoom: contact.matrixRoom,
    };
  }
  return entries;
}

function buildHealthOverrides(devicesConfig) {
  const allowed = new Set(devicesConfig.physicalShcModels);
  const overrides = {};
  for (const s of devicesConfig.climateSensors) {
    if (allowed.has(s.model)) {
      overrides[s.deviceId] = { deviceName: s.canonicalName, room: s.room };
    }
  }
  for (const c of devicesConfig.contacts) {
    overrides[c.deviceId] = { deviceName: c.canonicalName, room: c.matrixRoom || c.shcRoom };
  }
  for (const p of devicesConfig.smartPlugs) {
    if (allowed.has(p.model)) {
      overrides[p.deviceId] = { deviceName: p.canonicalName, room: p.room };
    }
  }
  const cam = devicesConfig.systemDevices && devicesConfig.systemDevices.camera3yes;
  if (cam && allowed.has(cam.model)) {
    overrides[cam.deviceId] = { deviceName: cam.canonicalName, room: cam.room };
  }
  return overrides;
}

function createPlugsTabNodes(devicesConfig, logicSource, org) {
  const plugsById = buildSmartPlugsMap(devicesConfig);
  const func = buildEmbeddedFunc(
    logicSource,
    `const SMART_PLUGS_BY_ID = ${JSON.stringify(plugsById, null, 2)};`,
    `
const nowMs = Date.now();
const events = normalizePayload(msg && msg.payload);
if (events.length === 0) {
  return null;
}

let powerStore = flow.get('hzPowerStateStore');
if (!powerStore || typeof powerStore !== 'object' || Array.isArray(powerStore)) {
  powerStore = {};
}

let applianceCtx = flow.get('hzApplianceStateCtx');
if (!applianceCtx || typeof applianceCtx !== 'object' || Array.isArray(applianceCtx)) {
  applianceCtx = {};
}

const touchedIds = [];
const seenIds = new Set();
for (const ev of events) {
  const devId = ev.deviceId;
  if (typeof devId !== 'string' || !Object.prototype.hasOwnProperty.call(SMART_PLUGS_BY_ID, devId)) {
    continue;
  }
  const stObj = ev.state && typeof ev.state === 'object' ? ev.state : null;
  const stType = stObj ? stObj['@type'] : undefined;
  const isPlugEvent =
    ev.id === 'PowerMeter' ||
    ev.id === 'PowerSwitch' ||
    stType === 'powerMeterState' ||
    stType === 'powerSwitchState';
  if (isPlugEvent && !seenIds.has(devId)) {
    seenIds.add(devId);
    touchedIds.push(devId);
  }
}

const powerPoints = buildPowerMeterPoints(events, powerStore, SMART_PLUGS_BY_ID, nowMs);
const appliancePoints = [];

for (const devId of touchedIds) {
  const plug = SMART_PLUGS_BY_ID[devId];
  if (!plug || !plug.applianceConfig) {
    continue;
  }
  const current = powerStore[devId];
  if (!current || typeof current !== 'object') {
    continue;
  }
  const hasPower = typeof current.power === 'number' && Number.isFinite(current.power);
  const hasSwitch = current.switchOn === 0 || current.switchOn === 1;
  if (!hasPower && !hasSwitch) {
    continue;
  }
  const sample = {
    power: hasPower ? current.power : undefined,
    energyWh: typeof current.energyWh === 'number' && Number.isFinite(current.energyWh) ? current.energyWh : undefined,
    switchOn: hasSwitch ? current.switchOn : undefined,
  };
  const cfg = Object.assign({}, plug.applianceConfig, { deviceName: plug.canonicalName });
  const pts = stepApplianceState(devId, sample, applianceCtx, cfg, nowMs);
  for (const p of pts) {
    appliancePoints.push(p);
  }
}

flow.set('hzPowerStateStore', powerStore);
flow.set('hzApplianceStateCtx', applianceCtx);

const outPoints = powerPoints.concat(appliancePoints);
if (outPoints.length === 0) {
  return null;
}
msg.payload = outPoints;
return msg;
`,
  );

  return [
    makeTabNode(
      TAB_HZ_PLUGS,
      'Steckdosen & Geräte',
      'Rein lesende Erfassung aller 4 Smart-Steckdosen (powerMeter) sowie Zustandsautomat für Waschmaschine und Creality (applianceState).',
    ),
    makeInjectNode({
      id: 'hz_plugs_inject',
      z: TAB_HZ_PLUGS,
      name: 'Poll Steckdosen (60s)',
      repeat: '60',
      once: true,
      onceDelay: '5',
      x: 150,
      y: 160,
      wires: [['hz_plugs_shc_powermeter', 'hz_plugs_shc_powerswitch']],
    }),
    makeShcDeviceNode({
      id: 'hz_plugs_shc_powermeter',
      z: TAB_HZ_PLUGS,
      poll: true,
      device: 'all|all|all|PowerMeter|',
      service: 'PowerMeter',
      name: 'Alle PowerMeter',
      x: 420,
      y: 120,
      wires: [['hz_plugs_fn']],
    }),
    makeShcDeviceNode({
      id: 'hz_plugs_shc_powerswitch',
      z: TAB_HZ_PLUGS,
      poll: true,
      device: 'all|all|all|PowerSwitch|',
      service: 'PowerSwitch',
      name: 'Alle PowerSwitch',
      x: 420,
      y: 200,
      wires: [['hz_plugs_fn']],
    }),
    makeFunctionNode({
      id: 'hz_plugs_fn',
      z: TAB_HZ_PLUGS,
      name: 'Verarbeite powerMeter & applianceState',
      func,
      x: 730,
      y: 160,
      wires: [['hz_plugs_influx']],
    }),
    makeInfluxBatchNode({
      id: 'hz_plugs_influx',
      z: TAB_HZ_PLUGS,
      name: 'batch-out (Steckdosen)',
      org,
      x: 1030,
      y: 160,
    }),
  ];
}

function createClimateTabNodes(devicesConfig, logicSource, org) {
  const rccById = buildRccMap(devicesConfig);
  const func = buildEmbeddedFunc(
    logicSource,
    `const RCC_BY_ID = ${JSON.stringify(rccById, null, 2)};`,
    `
const nowMs = Date.now();
const points = buildRoomClimatePoints(msg && msg.payload, RCC_BY_ID, nowMs);
if (points.length === 0) {
  return null;
}
msg.payload = points;
return msg;
`,
  );

  return [
    makeTabNode(
      TAB_HZ_CLIMATE,
      'Raumklima (Soll)',
      'Rein lesende Erfassung aller 9 RoomClimateControl-Instanzen in Measurement roomClimate.',
    ),
    makeInjectNode({
      id: 'hz_climate_inject',
      z: TAB_HZ_CLIMATE,
      name: 'Poll Raumklima (300s)',
      repeat: '300',
      once: true,
      onceDelay: '8',
      x: 150,
      y: 160,
      wires: [['hz_climate_shc_rcc']],
    }),
    makeShcDeviceNode({
      id: 'hz_climate_shc_rcc',
      z: TAB_HZ_CLIMATE,
      poll: true,
      device: 'all|all|all|RoomClimateControl|',
      service: 'RoomClimateControl',
      name: 'Alle RoomClimateControl',
      x: 430,
      y: 160,
      wires: [['hz_climate_fn']],
    }),
    makeFunctionNode({
      id: 'hz_climate_fn',
      z: TAB_HZ_CLIMATE,
      name: 'Verarbeite roomClimate',
      func,
      x: 720,
      y: 160,
      wires: [['hz_climate_influx']],
    }),
    makeInfluxBatchNode({
      id: 'hz_climate_influx',
      z: TAB_HZ_CLIMATE,
      name: 'batch-out (Raumklima)',
      org,
      x: 1000,
      y: 160,
    }),
  ];
}

function createSecHealthTabNodes(devicesConfig, logicSource, org) {
  const secFunc = buildEmbeddedFunc(
    logicSource,
    '// Messung securityStatus ohne zusätzliche Konfiguration.',
    `
const nowMs = Date.now();
const points = buildSecurityPoints(msg && msg.payload, nowMs);
if (points.length === 0) {
  return null;
}
msg.payload = points;
return msg;
`,
  );

  const physicalModels = devicesConfig.physicalShcModels;
  const healthOverrides = buildHealthOverrides(devicesConfig);
  const healthFunc = buildEmbeddedFunc(
    logicSource,
    `const PHYSICAL_SHC_MODELS = ${JSON.stringify(physicalModels, null, 2)};\nconst HEALTH_NAME_OVERRIDES = ${JSON.stringify(healthOverrides, null, 2)};`,
    `
const nowMs = Date.now();
const rawPayload = msg && msg.payload;
const items = normalizePayload(rawPayload);
if (items.length === 0) {
  return null;
}

let devicesSnapshot = flow.get('hzDevicesSnapshot');
let servicesSnapshot = flow.get('hzServicesSnapshot');
let deviceStatusById = flow.get('hzDeviceStatusById');
if (!deviceStatusById || typeof deviceStatusById !== 'object' || Array.isArray(deviceStatusById)) {
  deviceStatusById = {};
}

const first = items[0];
const looksLikeDevices =
  first['@type'] === 'device' ||
  (typeof first.deviceModel === 'string' && !Object.prototype.hasOwnProperty.call(first, 'deviceId'));
const looksLikeServices =
  first['@type'] === 'DeviceServiceData' ||
  (typeof first.deviceId === 'string' && typeof first.id === 'string');

if (looksLikeDevices) {
  const isIncrementalDeviceUpdate =
    !Array.isArray(rawPayload) ||
    (Array.isArray(devicesSnapshot) && devicesSnapshot.length > 1 && items.length === 1);

  if (!isIncrementalDeviceUpdate) {
    devicesSnapshot = items;
    deviceStatusById = {};
  } else {
    const byId = new Map();
    if (Array.isArray(devicesSnapshot)) {
      for (const d of devicesSnapshot) {
        if (d && typeof d.id === 'string') {
          byId.set(d.id, d);
        }
      }
    }
    for (const d of items) {
      if (d && typeof d.id === 'string') {
        byId.set(d.id, d);
      }
    }
    devicesSnapshot = Array.from(byId.values());
  }
  for (const d of items) {
    if (d && typeof d.id === 'string' && typeof d.status === 'string') {
      deviceStatusById[d.id] = d.status;
    }
  }
  flow.set('hzDevicesSnapshot', devicesSnapshot);
  flow.set('hzDeviceStatusById', deviceStatusById);
} else if (looksLikeServices) {
  const isIncrementalServiceUpdate =
    !Array.isArray(rawPayload) ||
    (Array.isArray(servicesSnapshot) && servicesSnapshot.length > 1 && items.length === 1);

  if (!isIncrementalServiceUpdate) {
    servicesSnapshot = items;
  } else {
    const byKey = new Map();
    if (Array.isArray(servicesSnapshot)) {
      for (const s of servicesSnapshot) {
        if (s && typeof s.deviceId === 'string' && typeof s.id === 'string') {
          byKey.set(s.deviceId + '|' + s.id, s);
        }
      }
    }
    for (const s of items) {
      if (s && typeof s.deviceId === 'string' && typeof s.id === 'string') {
        byKey.set(s.deviceId + '|' + s.id, s);
      }
    }
    servicesSnapshot = Array.from(byKey.values());
  }
  flow.set('hzServicesSnapshot', servicesSnapshot);
} else {
  return null;
}

if (
  !Array.isArray(devicesSnapshot) ||
  devicesSnapshot.length === 0 ||
  !Array.isArray(servicesSnapshot) ||
  servicesSnapshot.length === 0
) {
  return null;
}

const points = buildDeviceHealthPoints(
  devicesSnapshot,
  servicesSnapshot,
  PHYSICAL_SHC_MODELS,
  HEALTH_NAME_OVERRIDES,
  nowMs
);
if (points.length === 0) {
  return null;
}
msg.payload = points;
return msg;
`,
  );

  const contactsById = buildContactsMap(devicesConfig);
  const contactsFunc = buildEmbeddedFunc(
    logicSource,
    `const CONTACTS_BY_ID = ${JSON.stringify(contactsById, null, 2)};`,
    `
const nowMs = Date.now();
const deviceStatusById = flow.get('hzDeviceStatusById') || {};
const points = buildContactStatusPoints(msg && msg.payload, deviceStatusById, CONTACTS_BY_ID, nowMs);
if (points.length === 0) {
  return null;
}
msg.payload = points;
return msg;
`,
  );

  return [
    makeTabNode(
      TAB_HZ_SEC_HEALTH,
      'Sicherheit & Gesundheit',
      'Rein lesende Erfassung von securityStatus, deviceHealth (25 physische Geräte) und contactStatus (alle 9 Kontakte).',
    ),
    // Sicherheit
    makeInjectNode({
      id: 'hz_sec_inject',
      z: TAB_HZ_SEC_HEALTH,
      name: 'Poll Sicherheit (300s)',
      repeat: '300',
      once: true,
      onceDelay: '10',
      x: 150,
      y: 140,
      wires: [['hz_sec_shc_intrusion', 'hz_sec_shc_alarm', 'hz_sec_shc_presence']],
    }),
    makeShcDeviceNode({
      id: 'hz_sec_shc_intrusion',
      z: TAB_HZ_SEC_HEALTH,
      poll: true,
      device: '-IntrusionDetectionSystem-|intrusionDetectionSystem|INTRUSION_DETECTION_SYSTEM|IntrusionDetectionControl,SurveillanceAlarm|Haus',
      service: 'IntrusionDetectionControl',
      name: 'Alarmsystem (Scharfschaltung)',
      x: 450,
      y: 80,
      wires: [['hz_sec_fn']],
    }),
    makeShcDeviceNode({
      id: 'hz_sec_shc_alarm',
      z: TAB_HZ_SEC_HEALTH,
      poll: true,
      device: '-IntrusionDetectionSystem-|intrusionDetectionSystem|INTRUSION_DETECTION_SYSTEM|IntrusionDetectionControl,SurveillanceAlarm|Haus',
      service: 'SurveillanceAlarm',
      name: 'Alarmsystem (Alarmzustand)',
      x: 450,
      y: 140,
      wires: [['hz_sec_fn']],
    }),
    makeShcDeviceNode({
      id: 'hz_sec_shc_presence',
      z: TAB_HZ_SEC_HEALTH,
      poll: true,
      device: '-PresenceSimulationService-|presenceSimulationService|PRESENCE_SIMULATION_SERVICE|PresenceSimulationConfiguration|Haus',
      service: 'PresenceSimulationConfiguration',
      name: 'Anwesenheitssimulation',
      x: 450,
      y: 200,
      wires: [['hz_sec_fn']],
    }),
    makeFunctionNode({
      id: 'hz_sec_fn',
      z: TAB_HZ_SEC_HEALTH,
      name: 'Verarbeite securityStatus',
      func: secFunc,
      x: 760,
      y: 140,
      wires: [['hz_sec_influx']],
    }),
    makeInfluxBatchNode({
      id: 'hz_sec_influx',
      z: TAB_HZ_SEC_HEALTH,
      name: 'batch-out (Sicherheit)',
      org,
      x: 1050,
      y: 140,
    }),

    // Gerätegesundheit
    makeInjectNode({
      id: 'hz_health_inject',
      z: TAB_HZ_SEC_HEALTH,
      name: 'Poll Gerätegesundheit (600s)',
      repeat: '600',
      once: true,
      onceDelay: '12',
      x: 170,
      y: 340,
      wires: [['hz_health_shc_devices', 'hz_health_shc_services']],
    }),
    makeShcDeviceNode({
      id: 'hz_health_shc_devices',
      z: TAB_HZ_SEC_HEALTH,
      poll: false,
      device: 'all|all|all||',
      service: '',
      name: 'Alle SHC-Geräte (getDevice)',
      x: 460,
      y: 300,
      wires: [['hz_health_fn']],
    }),
    makeShcDeviceNode({
      id: 'hz_health_shc_services',
      z: TAB_HZ_SEC_HEALTH,
      poll: false,
      device: 'all|all|all|all|',
      service: 'all',
      name: 'Alle SHC-Dienste (getDeviceServices)',
      x: 470,
      y: 380,
      wires: [['hz_health_fn']],
    }),
    makeFunctionNode({
      id: 'hz_health_fn',
      z: TAB_HZ_SEC_HEALTH,
      name: 'Verarbeite deviceHealth',
      func: healthFunc,
      x: 760,
      y: 340,
      wires: [['hz_health_influx']],
    }),
    makeInfluxBatchNode({
      id: 'hz_health_influx',
      z: TAB_HZ_SEC_HEALTH,
      name: 'batch-out (Gerätegesundheit)',
      org,
      x: 1060,
      y: 340,
    }),

    // Vollständige Kontakte (alle 9 Kontakte -> contactStatus)
    makeInjectNode({
      id: 'hz_contacts_inject',
      z: TAB_HZ_SEC_HEALTH,
      name: 'Poll Alle Kontakte (900s)',
      repeat: '900',
      once: true,
      onceDelay: '15',
      x: 160,
      y: 520,
      wires: [['hz_contacts_shc_all']],
    }),
    makeShcDeviceNode({
      id: 'hz_contacts_shc_all',
      z: TAB_HZ_SEC_HEALTH,
      poll: true,
      device: 'all|all|all|ShutterContact|',
      service: 'ShutterContact',
      name: 'Alle ShutterContact (9 Kontakte)',
      x: 460,
      y: 520,
      wires: [['hz_contacts_fn']],
    }),
    makeFunctionNode({
      id: 'hz_contacts_fn',
      z: TAB_HZ_SEC_HEALTH,
      name: 'Verarbeite contactStatus',
      func: contactsFunc,
      x: 760,
      y: 520,
      wires: [['hz_contacts_influx']],
    }),
    makeInfluxBatchNode({
      id: 'hz_contacts_influx',
      z: TAB_HZ_SEC_HEALTH,
      name: 'batch-out (Kontakte)',
      org,
      x: 1050,
      y: 520,
    }),
  ];
}

function patchLegacyTabTrvs(flows, byId, { tabId, service, injectId, faultId, joinId, joinCount }) {
  const injectNode = byId.get(injectId);
  if (injectNode) {
    sanitizeInjectNode(injectNode);
  }
  const faultNode = byId.get(faultId);
  const joinNode = byId.get(joinId);
  if (joinNode) {
    joinNode.count = String(joinCount);
    joinNode.timeout = '30';
  }

  for (const trv of MISSING_TRVS) {
    const targetId = service === 'TemperatureLevel' ? trv.tempNodeId : trv.valveNodeId;
    const targetY = service === 'TemperatureLevel' ? trv.tempY : trv.valveY;
    const existing = flows.find(
      (n) => n.z === tabId && n.type === 'shc-device' && extractDeviceId(n) === trv.deviceId && n.service === service,
    );
    const nodeId = existing ? existing.id : targetId;
    if (!existing) {
      const newNode = makeShcDeviceNode({
        id: nodeId,
        z: tabId,
        poll: true,
        device: trv.deviceString,
        service,
        name: '',
        x: 630,
        y: targetY,
        wires: [[joinId]],
      });
      flows.push(newNode);
      byId.set(nodeId, newNode);
    } else {
      appendUniqueWire(existing, joinId);
    }
    appendUniqueWire(injectNode, nodeId);
    appendUniqueWire(faultNode, nodeId);
  }
}

function patchFlows(originalFlows, devicesConfig, logicSource) {
  if (!Array.isArray(originalFlows)) {
    throw new Error('originalFlows muß ein Array von Node-RED-Nodes sein.');
  }
  const cfg = devicesConfig || loadDefaultDevices();
  const src = typeof logicSource === 'string' ? logicSource : loadDefaultLogicSource();
  const cloned = JSON.parse(JSON.stringify(originalFlows));
  const org = resolveInfluxOrg(cloned);

  // Idempotenz & Bereinigung: bestehende hz_*-Nodes und das Duplikat f82cb486c4c879d5 entfernen
  const flows = cloned.filter((n) => {
    if (!n || typeof n.id !== 'string') {
      return false;
    }
    if (n.id === DUPLICATE_DOOR_NODE_ID || n.id.startsWith('hz_')) {
      return false;
    }
    return true;
  });

  for (const node of flows) {
    if (Array.isArray(node.wires)) {
      node.wires = node.wires.map((port) =>
        Array.isArray(port)
          ? port.filter((target) => target !== DUPLICATE_DOOR_NODE_ID && typeof target === 'string' && !target.startsWith('hz_'))
          : [],
      );
    }
  }

  const byId = new Map(flows.map((n) => [n.id, n]));

  // 1. Tab Temperatur
  patchLegacyTabTrvs(flows, byId, {
    tabId: TAB_TEMPERATUR,
    service: 'TemperatureLevel',
    injectId: LEGACY_IDS.tempInject,
    faultId: LEGACY_IDS.tempFault,
    joinId: LEGACY_IDS.tempJoin,
    joinCount: '11',
  });

  // 2. Tab Ventilstellung
  patchLegacyTabTrvs(flows, byId, {
    tabId: TAB_VENTILSTELLUNG,
    service: 'ValveTappet',
    injectId: LEGACY_IDS.valveInject,
    faultId: LEGACY_IDS.valveFault,
    joinId: LEGACY_IDS.valveJoin,
    joinCount: '10',
  });

  // 3. Tab Fensterkontakt: Duplikat bereits entfernt; Inject absichern & auf 900s stellen
  const legacyContactInject = byId.get(LEGACY_IDS.contactInject);
  if (legacyContactInject) {
    sanitizeInjectNode(legacyContactInject);
    legacyContactInject.repeat = '900';
    legacyContactInject.once = true;
    legacyContactInject.onceDelay = '20';
  }

  // 4. Drei neue Tabs deterministisch anfügen
  flows.push(
    ...createPlugsTabNodes(cfg, src, org),
    ...createClimateTabNodes(cfg, src, org),
    ...createSecHealthTabNodes(cfg, src, org),
  );

  return flows;
}

function validateInjectSafeEmptyString(inj, errors) {
  if (inj.payloadType !== 'str' || inj.payload !== '') {
    errors.push(`Inject-Node ${inj.id} (Tab ${inj.z}) muß strikt payloadType='str' und payload='' setzen.`);
  }
  if (Array.isArray(inj.props)) {
    for (const prop of inj.props) {
      if (prop && prop.p === 'payload') {
        if (Object.hasOwn(prop, 'vt') && prop.vt !== 'str') {
          errors.push(`Inject-Node ${inj.id} besitzt abweichendes props.vt='${prop.vt}'.`);
        }
        if (Object.hasOwn(prop, 'v') && prop.v !== '') {
          errors.push(`Inject-Node ${inj.id} besitzt nicht-leeres props.v.`);
        }
      }
    }
  }
}

function validatePatchedFlows(flows, devicesConfig) {
  const cfg = devicesConfig || loadDefaultDevices();
  const errors = [];

  if (!Array.isArray(flows) || flows.length === 0) {
    return { ok: false, errors: ['Flow-Array ist leer oder kein Array.'] };
  }

  const byId = new Map();
  for (const node of flows) {
    if (!node || typeof node.id !== 'string' || node.id === '') {
      errors.push('Node ohne gültige string-ID gefunden.');
      continue;
    }
    if (byId.has(node.id)) {
      errors.push(`Doppelte Node-ID: ${node.id}`);
    } else {
      byId.set(node.id, node);
    }
  }

  if (byId.has(DUPLICATE_DOOR_NODE_ID)) {
    errors.push(`Duplikat-Node ${DUPLICATE_DOOR_NODE_ID} darf nicht mehr vorhanden sein.`);
  }

  const containerIds = new Set(
    flows.filter((n) => n && (n.type === 'tab' || n.type === 'subflow')).map((n) => n.id),
  );

  for (const node of flows) {
    if (!node || typeof node.id !== 'string') {
      continue;
    }
    if (node.z && node.type !== 'tab' && !containerIds.has(node.z)) {
      errors.push(`Node ${node.id} verweist auf unbekannten Tab/Subflow ${node.z}.`);
    }
    if (Array.isArray(node.wires)) {
      for (const port of node.wires) {
        if (!Array.isArray(port)) {
          errors.push(`Ungültige wires-Struktur bei Node ${node.id}.`);
          continue;
        }
        for (const target of port) {
          if (target === DUPLICATE_DOOR_NODE_ID) {
            errors.push(`Node ${node.id} verdrahtet weiterhin auf entferntes Duplikat ${DUPLICATE_DOOR_NODE_ID}.`);
          } else if (!byId.has(target)) {
            errors.push(`Ungültiges Wire-Ziel '${target}' bei Node ${node.id}.`);
          }
        }
      }
    }
  }

  // Review Focus #1: Schreibschutz für alle Injects in geänderten & neuen Tabs sowie keine bool-Injects an shc-device
  const guardedTabs = new Set([
    TAB_TEMPERATUR,
    TAB_VENTILSTELLUNG,
    TAB_FENSTERKONTAKT,
    TAB_HZ_PLUGS,
    TAB_HZ_CLIMATE,
    TAB_HZ_SEC_HEALTH,
  ]);
  for (const id of [LEGACY_IDS.tempInject, LEGACY_IDS.valveInject, LEGACY_IDS.contactInject]) {
    if (!byId.has(id)) {
      errors.push(`Erwarteter Bestands-Inject ${id} fehlt.`);
    }
  }
  for (const node of flows) {
    if (node && node.type === 'inject' && guardedTabs.has(node.z)) {
      validateInjectSafeEmptyString(node, errors);
    }
    if (node && node.type === 'inject' && Array.isArray(node.wires)) {
      const targetsShc = node.wires.some(
        (port) => Array.isArray(port) && port.some((t) => byId.get(t)?.type === 'shc-device'),
      );
      if (targetsShc && (node.payloadType === 'bool' || (node.payloadType === 'num' && Number(node.payload) >= 5 && Number(node.payload) <= 30))) {
        errors.push(`Unsicherer Inject-Typ (${node.payloadType}) an shc-device bei ${node.id}.`);
      }
    }
  }

  // Tab Temperatur
  const tempShc = flows.filter((n) => n.z === TAB_TEMPERATUR && n.type === 'shc-device');
  if (tempShc.length !== 11) {
    errors.push(`Tab Temperatur erwartet 11 shc-device-Nodes, gefunden: ${tempShc.length}.`);
  }
  const tempJoin = byId.get(LEGACY_IDS.tempJoin);
  if (!tempJoin || tempJoin.count !== '11' || tempJoin.timeout !== '30') {
    errors.push(`Join ${LEGACY_IDS.tempJoin} in Temperatur muß count='11' und timeout='30' haben.`);
  }
  const tempInj = byId.get(LEGACY_IDS.tempInject);
  for (const trv of MISSING_TRVS) {
    const dev = tempShc.find((n) => extractDeviceId(n) === trv.deviceId && n.service === 'TemperatureLevel');
    if (!dev || dev.poll !== true || !dev.wires?.[0]?.includes(LEGACY_IDS.tempJoin)) {
      errors.push(`Fehlender TRV ${trv.deviceId} in Temperatur unvollständig verdrahtet.`);
    } else if (!tempInj?.wires?.[0]?.includes(dev.id)) {
      errors.push(`Inject ${LEGACY_IDS.tempInject} verdrahtet nicht auf ${dev.id}.`);
    }
  }

  // Tab Ventilstellung
  const valveShc = flows.filter((n) => n.z === TAB_VENTILSTELLUNG && n.type === 'shc-device');
  if (valveShc.length !== 10) {
    errors.push(`Tab Ventilstellung erwartet 10 shc-device-Nodes, gefunden: ${valveShc.length}.`);
  }
  const valveJoin = byId.get(LEGACY_IDS.valveJoin);
  if (!valveJoin || valveJoin.count !== '10' || valveJoin.timeout !== '30') {
    errors.push(`Join ${LEGACY_IDS.valveJoin} in Ventilstellung muß count='10' und timeout='30' haben.`);
  }
  const valveInj = byId.get(LEGACY_IDS.valveInject);
  for (const trv of MISSING_TRVS) {
    const dev = valveShc.find((n) => extractDeviceId(n) === trv.deviceId && n.service === 'ValveTappet');
    if (!dev || dev.poll !== true || !dev.wires?.[0]?.includes(LEGACY_IDS.valveJoin)) {
      errors.push(`Fehlender TRV ${trv.deviceId} in Ventilstellung unvollständig verdrahtet.`);
    } else if (!valveInj?.wires?.[0]?.includes(dev.id)) {
      errors.push(`Inject ${LEGACY_IDS.valveInject} verdrahtet nicht auf ${dev.id}.`);
    }
  }

  // Review Focus #4: Tab Fensterkontakt streng auf den 6 Alt-Kontakten
  const legacyContacts = flows.filter((n) => n.z === TAB_FENSTERKONTAKT && n.type === 'shc-device');
  const expectedLegacyIds = new Set(cfg.contacts.filter((c) => c.legacyShutterContact).map((c) => c.deviceId));
  const actualLegacyIds = new Set(legacyContacts.map(extractDeviceId));
  if (legacyContacts.length !== 6 || actualLegacyIds.size !== 6) {
    errors.push(`Tab Fensterkontakt muß exakt 6 Kontakte enthalten, gefunden: ${legacyContacts.length}.`);
  }
  for (const id of expectedLegacyIds) {
    if (!actualLegacyIds.has(id)) {
      errors.push(`Alt-Kontakt ${id} fehlt in Tab Fensterkontakt.`);
    }
  }
  for (const c of cfg.contacts.filter((x) => !x.legacyShutterContact)) {
    if (actualLegacyIds.has(c.deviceId)) {
      errors.push(`Neuer Kontakt ${c.deviceId} darf nicht in Tab Fensterkontakt stehen.`);
    }
  }

  // Neue Tabs vorhanden & aktiv
  const newTabs = [TAB_HZ_PLUGS, TAB_HZ_CLIMATE, TAB_HZ_SEC_HEALTH];
  for (const tabId of newTabs) {
    const tab = byId.get(tabId);
    if (!tab || tab.type !== 'tab' || tab.disabled === true) {
      errors.push(`Neuer Tab ${tabId} fehlt oder ist deaktiviert.`);
    }
  }

  // Dynamisches org + InfluxDB-Konfiguration auf allen neuen batch-Nodes
  const refBatch = byId.get(LEGACY_IDS.tempInflux);
  const expectedOrg = refBatch && typeof refBatch.org === 'string' && refBatch.org.trim() !== '' ? refBatch.org : null;
  const newTabSet = new Set(newTabs);
  const newBatches = flows.filter((n) => n.type === 'influxdb batch' && newTabSet.has(n.z));
  if (newBatches.length !== 5) {
    errors.push(`Erwartet 5 neue influxdb-batch-Nodes, gefunden: ${newBatches.length}.`);
  }
  for (const batch of newBatches) {
    if (batch.influxdb !== INFLUX_CONFIG_ID) {
      errors.push(`Influx-Node ${batch.id} verweist nicht auf ${INFLUX_CONFIG_ID}.`);
    }
    if (batch.bucket !== INFLUX_BUCKET) {
      errors.push(`Influx-Node ${batch.id} nutzt nicht Bucket '${INFLUX_BUCKET}'.`);
    }
    if (typeof batch.org !== 'string' || batch.org.trim() === '') {
      errors.push(`Influx-Node ${batch.id} hat keinen org-Wert.`);
    } else if (expectedOrg && batch.org !== expectedOrg) {
      errors.push(`Influx-Node ${batch.id} org stimmt nicht mit Referenz-Node ${LEGACY_IDS.tempInflux} überein.`);
    }
  }

  // Startup-Reihenfolge getDevice (onceDelay 12) vor ShutterContact (onceDelay 15) & kein Long-Poll auf deviceHealth-Sammel-Nodes
  const healthInject = byId.get('hz_health_inject');
  const contactsInject = byId.get('hz_contacts_inject');
  if (!healthInject || !contactsInject) {
    errors.push('Fehlende Inject-Nodes für Gerätegesundheit oder Kontakte.');
  } else if (!(Number(healthInject.onceDelay) < Number(contactsInject.onceDelay))) {
    errors.push('hz_health_inject.onceDelay muß strikt vor hz_contacts_inject.onceDelay liegen.');
  }
  for (const healthShcId of ['hz_health_shc_devices', 'hz_health_shc_services']) {
    const healthShc = byId.get(healthShcId);
    if (!healthShc || healthShc.poll !== false) {
      errors.push(`Gerätegesundheits-Node ${healthShcId} muß poll=false setzen.`);
    }
  }

  // Alle 9 Kontakte in hz_contacts_fn, 4 Steckdosen in hz_plugs_fn, 9 RCCs in hz_climate_fn
  const contactsFn = byId.get('hz_contacts_fn');
  if (!contactsFn || typeof contactsFn.func !== 'string') {
    errors.push('Fehlender Function-Node hz_contacts_fn.');
  } else {
    for (const c of cfg.contacts) {
      if (!contactsFn.func.includes(c.deviceId)) {
        errors.push(`Kontakt ${c.deviceId} fehlt in hz_contacts_fn.`);
      }
    }
  }
  const plugsFn = byId.get('hz_plugs_fn');
  if (plugsFn && typeof plugsFn.func === 'string') {
    for (const p of cfg.smartPlugs) {
      if (!plugsFn.func.includes(p.deviceId)) {
        errors.push(`Steckdose ${p.deviceId} fehlt in hz_plugs_fn.`);
      }
    }
  }
  const climateFn = byId.get('hz_climate_fn');
  if (climateFn && typeof climateFn.func === 'string') {
    for (const r of cfg.roomClimateControls) {
      if (!climateFn.func.includes(r.deviceId)) {
        errors.push(`Raumklimaregler ${r.deviceId} fehlt in hz_climate_fn.`);
      }
    }
  }

  // Alle neuen Function-Nodes: kein node.warn, kein require(), kein Ela-Wandheizung, gültige VM-Syntax
  const newFuncs = flows.filter((n) => n.type === 'function' && newTabSet.has(n.z));
  if (newFuncs.length !== 5) {
    errors.push(`Erwartet 5 neue Function-Nodes, gefunden: ${newFuncs.length}.`);
  }
  for (const fnNode of newFuncs) {
    if (typeof fnNode.func !== 'string' || fnNode.func.trim() === '') {
      errors.push(`Function-Node ${fnNode.id} hat leeres func.`);
      continue;
    }
    if (/\bnode\.warn\b/.test(fnNode.func)) {
      errors.push(`Function-Node ${fnNode.id} enthält unerlaubtes node.warn.`);
    }
    if (/\brequire\s*\(/.test(fnNode.func)) {
      errors.push(`Function-Node ${fnNode.id} enthält unerlaubtes require().`);
    }
    if (fnNode.func.includes('Ela-Wandheizung')) {
      errors.push(`Function-Node ${fnNode.id} enthält unerlaubt Ela-Wandheizung.`);
    }
    try {
      new vm.Script(`(async function(msg, flow) {\n${fnNode.func}\n})`);
    } catch (err) {
      errors.push(`Syntaxfehler in ${fnNode.id}.func: ${err.message}`);
    }
  }

  return { ok: errors.length === 0, errors };
}

function runCli(argv) {
  if (argv.length !== 2) {
    process.stderr.write('Verwendung: node scripts/haus-zentrale/build_nodered_flows.js <input-flows.json> <output-flows.json>\n');
    return 2;
  }
  const [inputPath, outputPath] = argv;
  const originalFlows = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const devicesConfig = loadDefaultDevices();
  const logicSource = loadDefaultLogicSource();

  const patchedFlows = patchFlows(originalFlows, devicesConfig, logicSource);
  const validation = validatePatchedFlows(patchedFlows, devicesConfig);
  if (!validation.ok) {
    for (const err of validation.errors) {
      process.stderr.write(`VALIDIERUNGSFEHLER: ${err}\n`);
    }
    return 1;
  }

  fs.mkdirSync(path.dirname(path.resolve(outputPath)), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(patchedFlows, null, 2)}\n`, 'utf8');
  return 0;
}

if (require.main === module) {
  try {
    process.exitCode = runCli(process.argv.slice(2));
  } catch (err) {
    process.stderr.write(`FEHLER: ${err.message}\n`);
    process.exitCode = 1;
  }
}

module.exports = {
  patchFlows,
  validatePatchedFlows,
};
