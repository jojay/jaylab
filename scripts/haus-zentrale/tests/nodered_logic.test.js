'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const DEVICES_PATH = path.join(__dirname, '..', 'devices.json');
const LOGIC_PATH = path.join(__dirname, '..', 'nodered_logic.js');

const devicesCatalog = JSON.parse(fs.readFileSync(DEVICES_PATH, 'utf8'));
const logic = require('../nodered_logic.js');

const {
  normalizePayload,
  buildPowerMeterPoints,
  stepApplianceState,
  buildRoomClimatePoints,
  buildSecurityPoints,
  buildDeviceHealthPoints,
  buildContactStatusPoints,
} = logic;

const plugsById = Object.fromEntries(devicesCatalog.smartPlugs.map((p) => [p.deviceId, p]));
const rccById = Object.fromEntries(devicesCatalog.roomClimateControls.map((r) => [r.deviceId, r]));
const contactsById = Object.fromEntries(devicesCatalog.contacts.map((c) => [c.deviceId, c]));

const WASCHMASCHINE_ID = 'hdm:HomeMaticIP:3014F711A0000493985923FF';
const CREALITY_ID = 'hdm:ZigBee:842712fffebbc43f';
const SPRINGER_ID = 'hdm:HomeMaticIP:3014F711A00004953859DEF1';

test('normalizePayload normalizes single objects, arrays, and filters null/undefined', () => {
  assert.deepEqual(normalizePayload(null), []);
  assert.deepEqual(normalizePayload(undefined), []);
  assert.deepEqual(normalizePayload(''), []);
  assert.deepEqual(normalizePayload(42), []);

  const single = { id: 'PowerMeter', deviceId: WASCHMASCHINE_ID };
  assert.deepEqual(normalizePayload(single), [single]);

  const mixed = [single, null, undefined, 'bad', 123, [1, 2], { id: 'PowerSwitch' }];
  assert.deepEqual(normalizePayload(mixed), [single, { id: 'PowerSwitch' }]);
});

test('buildPowerMeterPoints merges PowerMeter and PowerSwitch via stateStore including zero values', () => {
  const stateStore = {};
  const t1 = 1700000000000;

  const pmOnly = buildPowerMeterPoints(
    [
      {
        '@type': 'DeviceServiceData',
        id: 'PowerMeter',
        deviceId: CREALITY_ID,
        state: {
          '@type': 'powerMeterState',
          powerConsumption: 0,
          energyConsumption: 0,
        },
      },
    ],
    stateStore,
    plugsById,
    t1,
  );

  assert.equal(pmOnly.length, 1);
  assert.equal(pmOnly[0].measurement, 'powerMeter');
  assert.deepEqual(pmOnly[0].tags, {
    deviceId: CREALITY_ID,
    deviceName: 'Creality',
    room: 'Keller',
  });
  assert.deepEqual(pmOnly[0].fields, {
    power: 0,
    energyWh: 0,
  });
  assert.deepEqual(pmOnly[0].timestamp, new Date(t1));

  const t2 = t1 + 5000;
  const psFollowUp = buildPowerMeterPoints(
    {
      '@type': 'DeviceServiceData',
      id: 'PowerSwitch',
      deviceId: CREALITY_ID,
      state: {
        '@type': 'powerSwitchState',
        switchState: 'ON',
      },
    },
    stateStore,
    plugsById,
    t2,
  );

  assert.equal(psFollowUp.length, 1);
  assert.deepEqual(psFollowUp[0].fields, {
    switchOn: 1,
    power: 0,
    energyWh: 0,
  });
  assert.deepEqual(psFollowUp[0].timestamp, new Date(t2));
});

test('buildPowerMeterPoints handles null PowerMeter for Springer (Review Focus #2)', () => {
  const stateStore = {};
  const nowMs = 1700000100000;

  // Null PowerMeter alone without PowerSwitch must not emit an empty point or NaN
  const emptyOnly = buildPowerMeterPoints(
    [{ id: 'PowerMeter', deviceId: SPRINGER_ID, state: null }],
    stateStore,
    plugsById,
    nowMs,
  );
  assert.deepEqual(emptyOnly, []);

  // Merged batch with PowerSwitch OFF + PowerMeter state null
  const pts = buildPowerMeterPoints(
    [
      { id: 'PowerMeter', deviceId: SPRINGER_ID, state: null },
      {
        id: 'PowerSwitch',
        deviceId: SPRINGER_ID,
        state: { '@type': 'powerSwitchState', switchState: 'OFF' },
      },
    ],
    stateStore,
    plugsById,
    nowMs,
  );

  assert.equal(pts.length, 1);
  assert.equal(pts[0].measurement, 'powerMeter');
  assert.equal(pts[0].tags.deviceId, SPRINGER_ID);
  assert.equal(pts[0].tags.deviceName, 'Springer');
  assert.equal(pts[0].tags.room, 'E1 Schlafzimmer Eltern');
  assert.deepEqual(pts[0].fields, { switchOn: 0 });
  assert.equal(Object.hasOwn(pts[0].fields, 'power'), false);
  assert.equal(Object.hasOwn(pts[0].fields, 'energyWh'), false);
  assert.deepEqual(pts[0].timestamp, new Date(nowMs));

  // Non-finite numbers in PowerMeter must also be rejected and stale power cleared on null
  const t2 = nowMs + 10000;
  buildPowerMeterPoints(
    [
      {
        id: 'PowerMeter',
        deviceId: SPRINGER_ID,
        state: { powerConsumption: 1200, energyConsumption: 500 },
      },
    ],
    stateStore,
    plugsById,
    t2,
  );
  const t3 = t2 + 10000;
  const afterDrop = buildPowerMeterPoints(
    [
      {
        id: 'PowerMeter',
        deviceId: SPRINGER_ID,
        state: { powerConsumption: Number.NaN, energyConsumption: null },
      },
      {
        id: 'PowerSwitch',
        deviceId: SPRINGER_ID,
        state: { switchState: 'OFF' },
      },
    ],
    stateStore,
    plugsById,
    t3,
  );
  assert.equal(afterDrop.length, 1);
  assert.deepEqual(afterDrop[0].fields, { switchOn: 0 });
});

test('stepApplianceState Waschmaschine full lifecycle, short peak rejection, and debounce (Review Focus #3)', () => {
  const baseCfg = plugsById[WASCHMASCHINE_ID].applianceConfig;
  const cfg = { ...baseCfg, deviceName: 'Waschmaschine' };
  const ctx = {};
  let t = 1700000000000;

  // Initial OFF -> Aus (0)
  let pts = stepApplianceState(WASCHMASCHINE_ID, { power: 0, energyWh: 1000, switchOn: 0 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].measurement, 'applianceState');
  assert.deepEqual(pts[0].tags, { deviceId: WASCHMASCHINE_ID, deviceName: 'Waschmaschine' });
  assert.deepEqual(pts[0].fields, {
    stateCode: 0,
    stateText: 'Aus',
    cycleEnergyWh: 0,
    cycleDurationMin: 0,
    finishedAtEpoch: 0,
  });

  // Switch ON with idle power -> Bereit (1)
  t += 10000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 1.5, energyWh: 1000, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 1);
  assert.equal(pts[0].fields.stateText, 'Bereit');

  // Short peak (< 60s) must stay Bereit (1)
  t += 10000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 25, energyWh: 1000, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);
  t += 40000; // 40s < 60s
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 25, energyWh: 1000, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);
  t += 5000; // drops below 10 W
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 2, energyWh: 1000, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  // Sustained >= 10 W for 60s -> Läuft (2)
  t += 10000;
  const startHoldT = t;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 500, energyWh: 1000, switchOn: 1 }, ctx, cfg, startHoldT);
  assert.equal(pts.length, 0);

  t = startHoldT + 59000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 500, energyWh: 1008, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  t = startHoldT + 60000;
  const runStartT = t;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 500, energyWh: 1010, switchOn: 1 }, ctx, cfg, runStartT);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 2);
  assert.equal(pts[0].fields.stateText, 'Läuft');
  assert.equal(pts[0].fields.cycleEnergyWh, 0);
  assert.equal(pts[0].fields.finishedAtEpoch, 0);

  // Review Focus #3a: 120 s at 2 W (< 4 W) < 300 s must NOT stop Läuft, and recovery resets timer
  t = runStartT + 100000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 2, energyWh: 1200, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  t = runStartT + 220000; // 120 s below stopThresholdW
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 2, energyWh: 1200, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  // Power recovers >= 4 W -> debounce timer resets
  t = runStartT + 225000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 150, energyWh: 1210, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  // Drop again; after 299 s must still be Läuft (heartbeat at >= 300 s since runStartT proves stateCode === 2)
  t = runStartT + 300000; // 300 s since runStartT -> heartbeat!
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 2, energyWh: 1350, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 2);
  assert.equal(pts[0].fields.stateText, 'Läuft');
  assert.equal(pts[0].fields.cycleEnergyWh, 340);
  assert.equal(pts[0].fields.cycleDurationMin, 5);

  const dropStartT = t;
  t = dropStartT + 299000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 2, energyWh: 1350, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  // >= 300 s below stopThresholdW -> Fertig (3)
  t = dropStartT + 300000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 2, energyWh: 1460, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 3);
  assert.equal(pts[0].fields.stateText, 'Fertig');
  assert.equal(pts[0].fields.cycleEnergyWh, 450);
  assert.equal(pts[0].fields.cycleDurationMin, 10);
  assert.equal(pts[0].fields.finishedAtEpoch, Math.floor(t / 1000));

  // Review Focus #3c (switchOn === 0 sets Fertig immediately to Aus)
  t += 10000;
  pts = stepApplianceState(WASCHMASCHINE_ID, { power: 0, energyWh: 1460, switchOn: 0 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 0);
  assert.equal(pts[0].fields.stateText, 'Aus');
});

test('stepApplianceState clamps negative energy on meter reset and auto-resets Fertig after 240 min (Review Focus #3b & #3c)', () => {
  const baseCfg = plugsById[CREALITY_ID].applianceConfig;
  const cfg = { ...baseCfg, deviceName: 'Creality' };
  const ctx = {};
  let t = 1700000000000;

  // Fresh ctx restart recognition: switchOn === 1 and power >= 15 W reaches Druckt (2) within 60 s
  let pts = stepApplianceState(CREALITY_ID, { power: 120, energyWh: 5000, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 1);
  assert.equal(pts[0].fields.stateText, 'Bereit');

  t += 60000;
  pts = stepApplianceState(CREALITY_ID, { power: 120, energyWh: 5005, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 2);
  assert.equal(pts[0].fields.stateText, 'Druckt');

  // Drop below 8 W and meter resets below cycleStartWh (5005 -> 120)
  t += 60000;
  pts = stepApplianceState(CREALITY_ID, { power: 3, energyWh: 120, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);

  t += 300000;
  pts = stepApplianceState(CREALITY_ID, { power: 3, energyWh: 120, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 3);
  assert.equal(pts[0].fields.stateText, 'Fertig');
  assert.equal(pts[0].fields.cycleEnergyWh, 0);
  assert.ok(pts[0].fields.cycleEnergyWh >= 0);
  const doneAt = t;

  // Before 240 min (239 min): remains Fertig (heartbeat emitted at >= 300s)
  t = doneAt + 239 * 60000;
  pts = stepApplianceState(CREALITY_ID, { power: 3, energyWh: 120, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 3);
  assert.equal(pts[0].fields.stateText, 'Fertig');

  // At 240 min: auto-resets to Bereit (1)
  t = doneAt + 240 * 60000;
  pts = stepApplianceState(CREALITY_ID, { power: 3, energyWh: 120, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 1);
  assert.equal(pts[0].fields.stateText, 'Bereit');

  // Direct restart from Fertig (3) when a new load begins without power-off
  t += 10000;
  pts = stepApplianceState(CREALITY_ID, { power: 80, energyWh: 200, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0); // 0s < 60s -> still Bereit
  t += 60000;
  pts = stepApplianceState(CREALITY_ID, { power: 80, energyWh: 202, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 2);
  assert.equal(pts[0].fields.stateText, 'Druckt');

  // Finish again and immediately start another load while still in Fertig (3)
  t += 60000;
  stepApplianceState(CREALITY_ID, { power: 2, energyWh: 250, switchOn: 1 }, ctx, cfg, t);
  t += 300000;
  pts = stepApplianceState(CREALITY_ID, { power: 2, energyWh: 250, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts[0].fields.stateCode, 3);

  t += 10000;
  pts = stepApplianceState(CREALITY_ID, { power: 90, energyWh: 250, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 0);
  t += 60000;
  pts = stepApplianceState(CREALITY_ID, { power: 90, energyWh: 255, switchOn: 1 }, ctx, cfg, t);
  assert.equal(pts.length, 1);
  assert.equal(pts[0].fields.stateCode, 2);
  assert.equal(pts[0].fields.stateText, 'Druckt');
});

test('stepApplianceState isolates multiple devices in shared ctx and handles 5-min heartbeat strictly', () => {
  const ctx = {};
  const waschCfg = { ...plugsById[WASCHMASCHINE_ID].applianceConfig, deviceName: 'Waschmaschine' };
  const crealCfg = { ...plugsById[CREALITY_ID].applianceConfig, deviceName: 'Creality' };
  const t0 = 1700000000000;

  const w0 = stepApplianceState(WASCHMASCHINE_ID, { power: 0, energyWh: 100, switchOn: 0 }, ctx, waschCfg, t0);
  const c0 = stepApplianceState(CREALITY_ID, { power: 2, energyWh: 200, switchOn: 1 }, ctx, crealCfg, t0);
  assert.equal(w0[0].fields.stateCode, 0);
  assert.equal(c0[0].fields.stateCode, 1);

  assert.deepEqual(
    stepApplianceState(CREALITY_ID, { power: 2, energyWh: 200, switchOn: 1 }, ctx, crealCfg, t0 + 299999),
    [],
  );
  const hb = stepApplianceState(CREALITY_ID, { power: 2, energyWh: 200, switchOn: 1 }, ctx, crealCfg, t0 + 300000);
  assert.equal(hb.length, 1);
  assert.equal(hb[0].fields.stateCode, 1);
  assert.deepEqual(hb[0].timestamp, new Date(t0 + 300000));
});

test('buildRoomClimatePoints maps roomClimateControl_hz_1 and all RCC fields cleanly', () => {
  const nowMs = 1700000200000;
  const pts = buildRoomClimatePoints(
    [
      {
        '@type': 'DeviceServiceData',
        id: 'RoomClimateControl',
        deviceId: 'roomClimateControl_hz_1',
        state: {
          '@type': 'climateControlState',
          operationMode: 'AUTOMATIC',
          setpointTemperature: 21.5,
          ventilationMode: false,
          boostMode: true,
          summerMode: false,
          hasDemand: true,
        },
      },
      {
        '@type': 'DeviceServiceData',
        id: 'RoomClimateControl',
        deviceId: 'roomClimateControl_hz_15',
        state: {
          '@type': 'climateControlState',
          operationMode: 'MANUAL',
          setpointTemperature: 19,
          ventilationMode: true,
          boostMode: false,
          summerMode: true,
          hasDemand: false,
        },
      },
      {
        '@type': 'DeviceServiceData',
        id: 'RoomClimateControl',
        deviceId: 'roomClimateControl_unknown',
        state: { setpointTemperature: 20 },
      },
      {
        '@type': 'DeviceServiceData',
        id: 'RoomClimateControl',
        deviceId: 'roomClimateControl_hz_2',
        state: null,
      },
    ],
    rccById,
    nowMs,
  );

  assert.equal(pts.length, 2);
  assert.deepEqual(pts[0], {
    measurement: 'roomClimate',
    tags: {
      deviceId: 'roomClimateControl_hz_1',
      room: 'E2 Wohn-/Eßzimmer',
    },
    fields: {
      setpoint: 21.5,
      hasDemand: 1,
      boostMode: 1,
      ventilationMode: 0,
      summerMode: 0,
      operationMode: 'AUTOMATIC',
    },
    timestamp: new Date(nowMs),
  });
  assert.deepEqual(pts[1].tags, {
    deviceId: 'roomClimateControl_hz_15',
    room: 'Lea Arbeitszimmer',
  });
  assert.deepEqual(pts[1].fields, {
    setpoint: 19,
    hasDemand: 0,
    boostMode: 0,
    ventilationMode: 1,
    summerMode: 1,
    operationMode: 'MANUAL',
  });

  // Non-finite setpointTemperature must be omitted without NaN/null
  const noSetpoint = buildRoomClimatePoints(
    {
      id: 'RoomClimateControl',
      deviceId: 'roomClimateControl_hz_3',
      state: {
        setpointTemperature: null,
        hasDemand: false,
        boostMode: false,
        ventilationMode: false,
        summerMode: true,
        operationMode: 'AUTOMATIC',
      },
    },
    rccById,
    nowMs,
  );
  assert.equal(noSetpoint.length, 1);
  assert.equal(noSetpoint[0].tags.room, 'E1 Schlafzimmer Eltern');
  assert.equal(Object.hasOwn(noSetpoint[0].fields, 'setpoint'), false);
  assert.equal(noSetpoint[0].fields.summerMode, 1);
});

test('buildSecurityPoints maps IntrusionDetectionControl, SurveillanceAlarm, and PresenceSimulationConfiguration', () => {
  const nowMs = 1700000300000;
  const pts = buildSecurityPoints(
    [
      {
        id: 'IntrusionDetectionControl',
        deviceId: 'intrusionDetectionSystem',
        state: { value: 'SYSTEM_DISARMED' },
      },
      {
        id: 'IntrusionDetectionControl',
        deviceId: 'intrusionDetectionSystem',
        state: { value: 'SYSTEM_ARMED' },
      },
      {
        id: 'IntrusionDetectionControl',
        deviceId: 'intrusionDetectionSystem',
        state: { value: 'SYSTEM_ARMING' },
      },
      {
        id: 'SurveillanceAlarm',
        deviceId: 'intrusionDetectionSystem',
        state: { value: 'ALARM_OFF' },
      },
      {
        id: 'SurveillanceAlarm',
        deviceId: 'intrusionDetectionSystem',
        state: { value: 'ALARM_ON' },
      },
      {
        id: 'PresenceSimulationConfiguration',
        deviceId: 'presenceSimulationService',
        state: { enabled: true },
      },
      {
        id: 'PresenceSimulationConfiguration',
        deviceId: 'presenceSimulationService',
        state: { enabled: false },
      },
      {
        id: 'IntrusionDetectionControl',
        deviceId: 'intrusionDetectionSystem',
        state: null,
      },
    ],
    nowMs,
  );

  assert.equal(pts.length, 7);
  assert.deepEqual(pts[0], {
    measurement: 'securityStatus',
    tags: { deviceId: 'intrusionDetectionSystem', service: 'IntrusionDetectionControl' },
    fields: { armed: 0, statusText: 'SYSTEM_DISARMED' },
    timestamp: new Date(nowMs),
  });
  assert.deepEqual(pts[1].fields, { armed: 1, statusText: 'SYSTEM_ARMED' });
  assert.deepEqual(pts[2].fields, { armed: 2, statusText: 'SYSTEM_ARMING' });
  assert.deepEqual(pts[3], {
    measurement: 'securityStatus',
    tags: { deviceId: 'intrusionDetectionSystem', service: 'SurveillanceAlarm' },
    fields: { alarmActive: 0, statusText: 'ALARM_OFF' },
    timestamp: new Date(nowMs),
  });
  assert.deepEqual(pts[4].fields, { alarmActive: 1, statusText: 'ALARM_ON' });
  assert.deepEqual(pts[5], {
    measurement: 'securityStatus',
    tags: { deviceId: 'presenceSimulationService', service: 'PresenceSimulationConfiguration' },
    fields: { presenceSimEnabled: 1, statusText: 'ENABLED' },
    timestamp: new Date(nowMs),
  });
  assert.deepEqual(pts[6].fields, { presenceSimEnabled: 0, statusText: 'DISABLED' });
});

test('buildDeviceHealthPoints filters 25 physical devices from 38 SHC objects, applies Springer override, and aggregates faults', () => {
  const nowMs = 1700000400000;
  const physicalDevices = [
    ...devicesCatalog.climateSensors
      .filter((s) => devicesCatalog.physicalShcModels.includes(s.model))
      .map((s) => ({
        id: s.deviceId,
        name: s.shcName,
        deviceModel: s.model,
        status: 'AVAILABLE',
        room: s.room,
      })),
    ...devicesCatalog.contacts.map((c) => ({
      id: c.deviceId,
      name: c.shcName,
      deviceModel: 'SWD',
      status:
        c.canonicalName === 'Tür Hauseingang'
          ? 'UNAVAILABLE'
          : c.canonicalName === 'Garagentor'
            ? 'UNDEFINED'
            : 'AVAILABLE',
      room: c.matrixRoom || c.shcRoom,
    })),
    ...devicesCatalog.smartPlugs.map((p) => ({
      id: p.deviceId,
      name: p.shcName, // raw SHC name Ela-Wandheizung for Springer!
      deviceModel: p.model,
      status: p.deviceId === SPRINGER_ID ? 'UNDEFINED' : 'AVAILABLE',
      room: p.room,
    })),
    {
      id: devicesCatalog.systemDevices.camera3yes.deviceId,
      name: devicesCatalog.systemDevices.camera3yes.shcName,
      deviceModel: devicesCatalog.systemDevices.camera3yes.model,
      status: 'UNAVAILABLE',
      room: devicesCatalog.systemDevices.camera3yes.room,
    },
  ];

  const nonPhysicalDevices = [
    ...devicesCatalog.roomClimateControls.map((r) => ({
      id: r.deviceId,
      name: '-RoomClimateControl-',
      deviceModel: 'ROOM_CLIMATE_CONTROL',
      status: 'AVAILABLE',
      room: r.matrixRoom,
    })),
    { id: 'ventilationService', name: '-VentilationService-', deviceModel: 'VENTILATION_SERVICE', status: 'AVAILABLE' },
    { id: 'intrusionDetectionSystem', name: '-IntrusionDetectionSystem-', deviceModel: 'INTRUSION_DETECTION_SYSTEM', status: 'AVAILABLE' },
    { id: 'presenceSimulationService', name: '-PresenceSimulationService-', deviceModel: 'PRESENCE_SIMULATION_SERVICE', status: 'AVAILABLE' },
    { id: 'hueBridgeManager', name: '-HueBridgeManager-', deviceModel: 'HUE_BRIDGE_MANAGER', status: 'AVAILABLE' },
  ];

  const all38 = [...physicalDevices, ...nonPhysicalDevices];
  assert.equal(all38.length, 38);

  const camId = devicesCatalog.systemDevices.camera3yes.deviceId;
  const doorId = 'hdm:HomeMaticIP:3014F711A000009D585A1652';
  const services = [
    {
      deviceId: camId,
      id: 'CameraNotification',
      faults: { entries: [{ type: 'COMMUNICATION_ERROR', description: 'Kamera nicht erreichbar' }] },
    },
    {
      deviceId: camId,
      id: 'PrivacyMode',
      faults: { entries: [{ type: 'INTERNAL_ERROR' }] },
    },
    {
      deviceId: doorId,
      id: 'BatteryLevel',
      faults: { entries: [{ type: 'LOW_BATTERY' }] },
    },
  ];

  const nameOverrides = {
    [SPRINGER_ID]: 'Springer',
    [camId]: 'Außenkamera 3yes',
  };

  const pts = buildDeviceHealthPoints(
    all38,
    services,
    devicesCatalog.physicalShcModels,
    nameOverrides,
    nowMs,
  );

  assert.equal(pts.length, 25);
  for (const p of pts) {
    assert.equal(p.measurement, 'deviceHealth');
    assert.ok(devicesCatalog.physicalShcModels.includes(p.tags.deviceModel));
    assert.notEqual(p.tags.deviceName, 'Ela-Wandheizung');
    assert.deepEqual(p.timestamp, new Date(nowMs));
  }

  const byId = Object.fromEntries(pts.map((p) => [p.tags.deviceId, p]));
  assert.deepEqual(byId[SPRINGER_ID].tags, {
    deviceId: SPRINGER_ID,
    deviceName: 'Springer',
    deviceModel: 'PSM',
    room: 'E1 Schlafzimmer Eltern',
  });
  assert.deepEqual(byId[SPRINGER_ID].fields, {
    available: 0,
    statusText: 'UNDEFINED',
    faultCount: 0,
    faultSummary: 'OK',
  });

  assert.deepEqual(byId[camId].fields, {
    available: 0,
    statusText: 'UNAVAILABLE',
    faultCount: 2,
    faultSummary: 'Kamera nicht erreichbar, INTERNAL_ERROR',
  });

  assert.deepEqual(byId[doorId].fields, {
    available: 0,
    statusText: 'UNAVAILABLE',
    faultCount: 1,
    faultSummary: 'LOW_BATTERY',
  });

  assert.deepEqual(byId[WASCHMASCHINE_ID].fields, {
    available: 1,
    statusText: 'AVAILABLE',
    faultCount: 0,
    faultSummary: 'OK',
  });
});

test('buildContactStatusPoints enforces UNAVAILABLE when status !== AVAILABLE (Review Focus #5)', () => {
  const nowMs = 1700000500000;
  const DOOR_ID = 'hdm:HomeMaticIP:3014F711A000009D585A1652'; // Tür Hauseingang
  const GARAGE_ID = 'hdm:HomeMaticIP:3014F711A000009D585A1636'; // Garagentor
  const WERKSTATT_ID = 'hdm:HomeMaticIP:3014F711A000009398584454'; // Werkstattfenster
  const ESS_ID = 'hdm:HomeMaticIP:3014F711A000009D5858CD31'; // Fenster Esszimmer

  const deviceStatusById = {
    [DOOR_ID]: 'UNAVAILABLE',
    [GARAGE_ID]: 'UNDEFINED',
    [WERKSTATT_ID]: 'AVAILABLE',
    [ESS_ID]: 'AVAILABLE',
  };

  const contactEvents = [
    { id: 'ShutterContact', deviceId: DOOR_ID, state: { value: 'OPEN' } },
    { id: 'ShutterContact', deviceId: GARAGE_ID, state: { value: 'CLOSED' } },
    { id: 'ShutterContact', deviceId: WERKSTATT_ID, state: { value: 'OPEN' } },
    { id: 'ShutterContact', deviceId: ESS_ID, state: { value: 'CLOSED' } },
  ];

  const pts = buildContactStatusPoints(contactEvents, deviceStatusById, contactsById, nowMs);
  assert.equal(pts.length, 4);

  const byId = Object.fromEntries(pts.map((p) => [p.tags.deviceId, p]));

  assert.deepEqual(byId[DOOR_ID], {
    measurement: 'contactStatus',
    tags: {
      deviceId: DOOR_ID,
      deviceName: 'Tür Hauseingang',
      room: 'E0:Haus-Foyer',
    },
    fields: {
      state: 'UNAVAILABLE',
      isOpen: 0,
      available: 0,
    },
    timestamp: new Date(nowMs),
  });

  assert.deepEqual(byId[GARAGE_ID], {
    measurement: 'contactStatus',
    tags: {
      deviceId: GARAGE_ID,
      deviceName: 'Garagentor',
      room: 'E0:Wagenhalle',
    },
    fields: {
      state: 'UNAVAILABLE',
      isOpen: 0,
      available: 0,
    },
    timestamp: new Date(nowMs),
  });

  assert.deepEqual(byId[WERKSTATT_ID], {
    measurement: 'contactStatus',
    tags: {
      deviceId: WERKSTATT_ID,
      deviceName: 'Werkstattfenster',
      room: 'Keller / Tiefkeller',
    },
    fields: {
      state: 'OPEN',
      isOpen: 1,
      available: 1,
    },
    timestamp: new Date(nowMs),
  });

  assert.deepEqual(byId[ESS_ID], {
    measurement: 'contactStatus',
    tags: {
      deviceId: ESS_ID,
      deviceName: 'Fenster Esszimmer',
      room: 'E2 Wohn-/Eßzimmer',
    },
    fields: {
      state: 'CLOSED',
      isOpen: 0,
      available: 1,
    },
    timestamp: new Date(nowMs),
  });

  // Null state on UNAVAILABLE contact still emits UNAVAILABLE cleanly
  const nullStatePts = buildContactStatusPoints(
    { id: 'ShutterContact', deviceId: DOOR_ID, state: null },
    deviceStatusById,
    contactsById,
    nowMs,
  );
  assert.equal(nullStatePts.length, 1);
  assert.deepEqual(nullStatePts[0].fields, {
    state: 'UNAVAILABLE',
    isOpen: 0,
    available: 0,
  });

  // Null state on AVAILABLE contact does not emit contradictory available:1 / UNAVAILABLE
  assert.deepEqual(
    buildContactStatusPoints(
      { id: 'ShutterContact', deviceId: WERKSTATT_ID, state: null },
      deviceStatusById,
      contactsById,
      nowMs,
    ),
    [],
  );
});

test('nodered_logic.js has no node.warn or require() and executes cleanly in Node-RED VM context', () => {
  const source = fs.readFileSync(LOGIC_PATH, 'utf8');
  assert.equal(/\bnode\.warn\b/.test(source), false, 'Must not contain node.warn');
  assert.equal(/\brequire\s*\(/.test(source), false, 'Must not contain require()');

  const sandbox = {
    Date,
    Math,
    Number,
    Object,
    Array,
    String,
    Set,
    Map,
    JSON,
    result: null,
  };
  const wrapped = `(function() { 'use strict';\n${source}\nreturn { normalizePayload, buildPowerMeterPoints, stepApplianceState, buildRoomClimatePoints, buildSecurityPoints, buildDeviceHealthPoints, buildContactStatusPoints };\n})()`;
  const script = new vm.Script(wrapped);
  const fns = script.runInNewContext(sandbox);

  assert.equal(typeof fns.normalizePayload, 'function');
  const out = fns.buildSecurityPoints(
    [{ id: 'SurveillanceAlarm', deviceId: 'intrusionDetectionSystem', state: { value: 'ALARM_OFF' } }],
    1700000000000,
  );
  assert.equal(out.length, 1);
  assert.equal(out[0].fields.alarmActive, 0);
});
