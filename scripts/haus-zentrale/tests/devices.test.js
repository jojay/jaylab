'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const DEVICES_PATH = path.join(__dirname, '..', 'devices.json');

function loadDevices() {
  return JSON.parse(fs.readFileSync(DEVICES_PATH, 'utf8'));
}

test('top-level schema contains all required sections', () => {
  const data = loadDevices();
  for (const key of [
    'climateSensors',
    'roomClimateControls',
    'contacts',
    'smartPlugs',
    'systemDevices',
    'physicalShcModels',
    'matrixRooms',
  ]) {
    assert.ok(Object.hasOwn(data, key), `Missing top-level key: ${key}`);
  }
});

test('climateSensors has 17 entries (11 shcbucket, 6 zigbee2mqtt), 10 valves, 7 humidity sensors', () => {
  const { climateSensors } = loadDevices();
  assert.equal(climateSensors.length, 17);

  const shcSensors = climateSensors.filter((s) => s.bucket === 'shcbucket');
  const zigbeeSensors = climateSensors.filter((s) => s.bucket === 'zigbee2mqtt');
  assert.equal(shcSensors.length, 11);
  assert.equal(zigbeeSensors.length, 6);

  for (const s of climateSensors) {
    for (const field of [
      'deviceId',
      'bucket',
      'canonicalName',
      'shcName',
      'room',
      'model',
      'color',
      'hasValve',
      'hasHumidity',
    ]) {
      assert.ok(Object.hasOwn(s, field), `Sensor ${s.deviceId} missing ${field}`);
    }
    assert.notEqual(s.canonicalName, 'Ela-Wandheizung');
  }

  const valves = climateSensors.filter((s) => s.hasValve === true);
  assert.equal(valves.length, 10);
  assert.ok(valves.every((s) => s.model === 'TRV'));

  const thb = climateSensors.find((s) => s.deviceId === 'hdm:HomeMaticIP:3014F711A000289BB85F32B0');
  assert.ok(thb);
  assert.equal(thb.model, 'THB');
  assert.equal(thb.hasValve, false);
  assert.equal(thb.hasHumidity, true);

  const humiditySensors = climateSensors.filter((s) => s.hasHumidity === true);
  assert.equal(humiditySensors.length, 7);
});

test('climateSensors colors are valid pairwise distinct hex codes and preserve the 12 legacy colors', () => {
  const { climateSensors } = loadDevices();
  const hexRe = /^#[0-9A-F]{6}$/;
  const colors = climateSensors.map((s) => s.color);

  for (const color of colors) {
    assert.match(color, hexRe, `Invalid hex color: ${color}`);
  }
  assert.equal(new Set(colors).size, 17, 'Climate sensor colors must be pairwise distinct');

  const expectedLegacy = {
    'hdm:HomeMaticIP:3014F711A000005D585C78C6': { canonicalName: 'Arbeitszimmer', color: '#73BF69' },
    'hdm:HomeMaticIP:3014F711A000005D58597571': { canonicalName: 'Badezimmer (SHC)', color: '#F2495C' },
    'hdm:HomeMaticIP:3014F711A000005BB85F9F08': { canonicalName: 'Esseck', color: '#B877D9' },
    'hdm:HomeMaticIP:3014F711A000289BB85F32B0': { canonicalName: 'Raumthermostat', color: '#3274D9' },
    'hdm:HomeMaticIP:3014F711A000005D585C79B6': { canonicalName: 'Umkleidezimmer OG', color: '#FADE2A' },
    'hdm:HomeMaticIP:3014F711A000005BB85F9E0D': { canonicalName: 'Wohnzimmer', color: '#5794F2' },
    'zigbee2mqtt/0x00158d00091adbe3': { canonicalName: 'Badezimmer (Aqara)', color: '#C0D8FF' },
    'zigbee2mqtt/0x00158d00091c96be': { canonicalName: 'Küche (Aqara)', color: '#9FDD12' },
    'zigbee2mqtt/0x00158d00091adb08': { canonicalName: 'Schlafzimmer Eltern', color: '#CA95E5' },
    'zigbee2mqtt/0x00158d00091a463f': { canonicalName: 'Schlafzimmer Samuel', color: '#EAB839' },
    'zigbee2mqtt/0x00158d00091a459e': { canonicalName: 'Schlafzimmer Vincent', color: '#37872D' },
    'zigbee2mqtt/0x00158d00091a4176': { canonicalName: 'Tiefkeller', color: '#0BD7CD' },
  };

  const byId = new Map(climateSensors.map((s) => [s.deviceId, s]));
  for (const [id, expected] of Object.entries(expectedLegacy)) {
    const sensor = byId.get(id);
    assert.ok(sensor, `Missing legacy climate sensor: ${id}`);
    assert.equal(sensor.canonicalName, expected.canonicalName);
    assert.equal(sensor.color, expected.color);
  }
});

test('roomClimateControls has 9 entries with shcRoom and matrixRoom', () => {
  const { roomClimateControls } = loadDevices();
  assert.equal(roomClimateControls.length, 9);
  for (const rcc of roomClimateControls) {
    assert.ok(rcc.deviceId.startsWith('roomClimateControl_hz_'));
    assert.equal(typeof rcc.shcRoom, 'string');
    assert.equal(typeof rcc.matrixRoom, 'string');
  }
});

test('contacts has 9 entries with exact 6 legacyShutterContact=true and 3 false', () => {
  const { contacts } = loadDevices();
  assert.equal(contacts.length, 9);

  for (const c of contacts) {
    for (const field of [
      'deviceId',
      'shcName',
      'canonicalName',
      'shcRoom',
      'matrixRoom',
      'legacyShutterContact',
    ]) {
      assert.ok(Object.hasOwn(c, field), `Contact ${c.deviceId} missing ${field}`);
    }
    assert.equal(typeof c.legacyShutterContact, 'boolean');
  }

  const legacyNames = contacts
    .filter((c) => c.legacyShutterContact === true)
    .map((c) => c.canonicalName)
    .sort();
  assert.deepEqual(legacyNames, [
    'Fenster Arbeitszimmer',
    'Fenster Bad',
    'Fenster EG Schlafzimmer',
    'Fenster Esszimmer',
    'Garagentor',
    'Tür Hauseingang',
  ]);

  const newNames = contacts
    .filter((c) => c.legacyShutterContact === false)
    .map((c) => c.canonicalName)
    .sort();
  assert.deepEqual(newNames, ['Fenster Samuel', 'Fenster Vincent', 'Werkstattfenster']);
});

test('smartPlugs has 4 entries, canonical Springer name, and exact applianceConfig', () => {
  const { smartPlugs } = loadDevices();
  assert.equal(smartPlugs.length, 4);

  for (const p of smartPlugs) {
    for (const field of [
      'deviceId',
      'shcName',
      'canonicalName',
      'room',
      'model',
      'color',
      'applianceConfig',
    ]) {
      assert.ok(Object.hasOwn(p, field), `Plug ${p.deviceId} missing ${field}`);
    }
    assert.match(p.color, /^#[0-9A-F]{6}$/);
    assert.notEqual(p.canonicalName, 'Ela-Wandheizung');
  }

  const byId = new Map(smartPlugs.map((p) => [p.deviceId, p]));
  const springer = byId.get('hdm:HomeMaticIP:3014F711A00004953859DEF1');
  assert.ok(springer);
  assert.equal(springer.canonicalName, 'Springer');
  assert.equal(springer.shcName, 'Ela-Wandheizung');
  assert.equal(springer.applianceConfig, null);

  const waschmaschine = byId.get('hdm:HomeMaticIP:3014F711A0000493985923FF');
  assert.ok(waschmaschine);
  assert.deepEqual(waschmaschine.applianceConfig, {
    startThresholdW: 10,
    startHoldSec: 60,
    stopThresholdW: 4,
    stopHoldSec: 300,
    doneAutoResetMin: 240,
    runningLabel: 'Läuft',
  });

  const creality = byId.get('hdm:ZigBee:842712fffebbc43f');
  assert.ok(creality);
  assert.deepEqual(creality.applianceConfig, {
    startThresholdW: 15,
    startHoldSec: 60,
    stopThresholdW: 8,
    stopHoldSec: 300,
    doneAutoResetMin: 240,
    runningLabel: 'Druckt',
  });

  const kompressor = byId.get('hdm:HomeMaticIP:3014F711A0000495385A125B');
  assert.ok(kompressor);
  assert.equal(kompressor.applianceConfig, null);
});

test('systemDevices and physicalShcModels cover all 25 physical SHC devices', () => {
  const { climateSensors, contacts, smartPlugs, systemDevices, physicalShcModels } = loadDevices();

  assert.deepEqual(physicalShcModels, ['TRV', 'THB', 'SWD', 'PSM', 'PLUG_COMPACT', 'CAMERA_EYES']);

  for (const key of ['intrusionDetectionSystem', 'presenceSimulationService', 'camera3yes']) {
    const dev = systemDevices[key];
    assert.ok(dev, `Missing systemDevices.${key}`);
    for (const field of ['deviceId', 'shcName', 'canonicalName', 'model', 'room']) {
      assert.ok(Object.hasOwn(dev, field), `systemDevices.${key} missing ${field}`);
    }
  }

  const physicalCount =
    climateSensors.filter((s) => physicalShcModels.includes(s.model)).length +
    contacts.length +
    smartPlugs.filter((p) => physicalShcModels.includes(p.model)).length +
    (physicalShcModels.includes(systemDevices.camera3yes.model) ? 1 : 0);

  assert.equal(physicalCount, 25);
});

test('matrixRooms has 11 rooms in exact floor order and valid sensor/control mappings', () => {
  const { climateSensors, roomClimateControls, contacts, matrixRooms } = loadDevices();
  assert.equal(matrixRooms.length, 11);

  const expectedOrder = [
    'E3 Badezimmer',
    'E3 Ankleidezimmer',
    'E2 Wohn-/Eßzimmer',
    'E2 Arbeitszimmer',
    'E2 Umkleideraum',
    'E2 Küche',
    'E1 Schlafzimmer Eltern',
    'Lea Arbeitszimmer',
    'Samuel',
    'Vincent',
    'Keller / Tiefkeller',
  ];

  assert.deepEqual(
    matrixRooms.map((r) => r.matrixRoom),
    expectedOrder,
  );
  assert.deepEqual(
    matrixRooms.map((r) => r.sortOrder),
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  );

  const byRoom = new Map(matrixRooms.map((r) => [r.matrixRoom, r]));

  const wohn = byRoom.get('E2 Wohn-/Eßzimmer');
  assert.equal(wohn.primaryTempId, 'hdm:HomeMaticIP:3014F711A000289BB85F32B0');
  assert.deepEqual(wohn.fallbackTempIds, [
    'hdm:HomeMaticIP:3014F711A000005BB85F9E0D',
    'hdm:HomeMaticIP:3014F711A000005BB85F9F08',
  ]);
  assert.deepEqual(wohn.valveIds, [
    'hdm:HomeMaticIP:3014F711A000005BB85F9E0D',
    'hdm:HomeMaticIP:3014F711A000005BB85F9F08',
  ]);
  assert.equal(wohn.humidityId, 'hdm:HomeMaticIP:3014F711A000289BB85F32B0');
  assert.equal(wohn.rccId, 'roomClimateControl_hz_1');

  const dualSensorRooms = [
    {
      room: 'E3 Badezimmer',
      aqaraId: 'zigbee2mqtt/0x00158d00091adbe3',
      shcId: 'hdm:HomeMaticIP:3014F711A000005D58597571',
    },
    {
      room: 'E1 Schlafzimmer Eltern',
      aqaraId: 'zigbee2mqtt/0x00158d00091adb08',
      shcId: 'hdm:HomeMaticIP:3014F711A000005D5859748B',
    },
    {
      room: 'Samuel',
      aqaraId: 'zigbee2mqtt/0x00158d00091a463f',
      shcId: 'hdm:HomeMaticIP:3014F711A000005398584BCF',
    },
    {
      room: 'Vincent',
      aqaraId: 'zigbee2mqtt/0x00158d00091a459e',
      shcId: 'hdm:HomeMaticIP:3014F711A000005398584A0F',
    },
  ];

  for (const spec of dualSensorRooms) {
    const entry = byRoom.get(spec.room);
    assert.ok(entry, `Missing dual-sensor room: ${spec.room}`);
    assert.equal(entry.primaryTempId, spec.aqaraId);
    assert.deepEqual(entry.fallbackTempIds, [spec.shcId]);
    assert.equal(entry.humidityId, spec.aqaraId);
  }

  // Referential integrity across all climate sensors, valves, humidity, RCCs, and contacts
  const sensorIds = new Set(climateSensors.map((s) => s.deviceId));
  const rccIds = new Set(roomClimateControls.map((r) => r.deviceId));
  const contactIds = new Set(contacts.map((c) => c.deviceId));

  const seenSensors = new Set();
  const seenValves = new Set();
  const seenHumidity = new Set();
  const seenRccs = new Set();
  const seenContacts = new Set();

  for (const r of matrixRooms) {
    assert.ok(sensorIds.has(r.primaryTempId));
    seenSensors.add(r.primaryTempId);
    for (const fid of r.fallbackTempIds) {
      assert.ok(sensorIds.has(fid));
      seenSensors.add(fid);
    }
    for (const vid of r.valveIds) {
      assert.ok(sensorIds.has(vid));
      seenValves.add(vid);
    }
    if (r.humidityId !== null) {
      assert.ok(sensorIds.has(r.humidityId));
      seenHumidity.add(r.humidityId);
    }
    if (r.rccId !== null) {
      assert.ok(rccIds.has(r.rccId));
      seenRccs.add(r.rccId);
    }
    if (r.contactId !== null) {
      assert.ok(contactIds.has(r.contactId));
      seenContacts.add(r.contactId);
    }
  }

  assert.equal(seenSensors.size, 17);
  assert.equal(seenValves.size, 10);
  assert.equal(seenHumidity.size, 7);
  assert.equal(seenRccs.size, 9);
  assert.equal(seenContacts.size, 7);
});
