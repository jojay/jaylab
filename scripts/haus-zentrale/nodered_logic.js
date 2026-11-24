// Reine ES2020-Verarbeitungslogik für Node-RED-Function-Nodes (eigenständig, ohne externe Abhängigkeiten).
// Deutsche Texte und Kommentare in Rechtschreibung von vor 1996.

function resolveNowMs(nowMs) {
  return typeof nowMs === 'number' && Number.isFinite(nowMs) ? nowMs : Date.now();
}

function isFiniteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function roundMilli(value) {
  return Math.round(Math.max(0, value) * 1000) / 1000;
}

function lookupEntry(collection, key) {
  if (!collection || typeof collection !== 'object' || typeof key !== 'string' || !key) {
    return undefined;
  }
  if (typeof collection.get === 'function') {
    return collection.get(key);
  }
  return Object.prototype.hasOwnProperty.call(collection, key) ? collection[key] : undefined;
}

function getOrCreateEntry(collection, key, factory) {
  if (typeof collection.get === 'function' && typeof collection.set === 'function') {
    let entry = collection.get(key);
    if (!entry) {
      entry = factory();
      collection.set(key, entry);
    }
    return entry;
  }
  if (!Object.prototype.hasOwnProperty.call(collection, key) || !collection[key] || typeof collection[key] !== 'object') {
    collection[key] = factory();
  }
  return collection[key];
}

function normalizePayload(payload) {
  if (payload === null || payload === undefined) {
    return [];
  }
  if (Array.isArray(payload)) {
    return payload.filter((item) => item !== null && typeof item === 'object' && !Array.isArray(item));
  }
  if (typeof payload === 'object') {
    return [payload];
  }
  return [];
}

function buildPowerMeterPoints(events, stateStore, plugsById, nowMs) {
  const ts = new Date(resolveNowMs(nowMs));
  const list = normalizePayload(events);
  const store = stateStore && typeof stateStore === 'object' ? stateStore : {};
  const touchedIds = [];
  const seen = new Set();

  for (const ev of list) {
    const deviceId = ev.deviceId;
    if (typeof deviceId !== 'string' || !deviceId) {
      continue;
    }
    const plug = lookupEntry(plugsById, deviceId);
    if (!plug) {
      continue;
    }

    const stateObj = ev.state && typeof ev.state === 'object' ? ev.state : null;
    const stateType = stateObj ? stateObj['@type'] : undefined;
    const isPowerMeter = ev.id === 'PowerMeter' || stateType === 'powerMeterState';
    const isPowerSwitch = ev.id === 'PowerSwitch' || stateType === 'powerSwitchState';
    if (!isPowerMeter && !isPowerSwitch) {
      continue;
    }

    const entry = getOrCreateEntry(store, deviceId, () => ({}));
    if (isPowerMeter) {
      if (stateObj && isFiniteNumber(stateObj.powerConsumption)) {
        entry.power = stateObj.powerConsumption;
      } else {
        delete entry.power;
      }
      if (stateObj && isFiniteNumber(stateObj.energyConsumption)) {
        entry.energyWh = stateObj.energyConsumption;
      } else {
        delete entry.energyWh;
      }
    } else if (isPowerSwitch) {
      const switchState = stateObj ? stateObj.switchState : undefined;
      if (switchState === 'ON') {
        entry.switchOn = 1;
      } else if (switchState === 'OFF') {
        entry.switchOn = 0;
      } else {
        delete entry.switchOn;
      }
    }

    if (!seen.has(deviceId)) {
      seen.add(deviceId);
      touchedIds.push(deviceId);
    }
  }

  const points = [];
  for (const deviceId of touchedIds) {
    const entry = lookupEntry(store, deviceId);
    const plug = lookupEntry(plugsById, deviceId);
    if (!entry || !plug) {
      continue;
    }

    const fields = {};
    if (entry.switchOn === 0 || entry.switchOn === 1) {
      fields.switchOn = entry.switchOn;
    }
    if (isFiniteNumber(entry.power)) {
      fields.power = entry.power;
    }
    if (isFiniteNumber(entry.energyWh)) {
      fields.energyWh = entry.energyWh;
    }
    if (Object.keys(fields).length === 0) {
      continue;
    }

    const deviceName = typeof plug === 'string'
      ? plug
      : (plug.canonicalName || plug.deviceName || plug.name || deviceId);
    const room = typeof plug === 'string'
      ? ''
      : (plug.room || plug.matrixRoom || plug.shcRoom || '');

    points.push({
      measurement: 'powerMeter',
      tags: {
        deviceId,
        deviceName: String(deviceName),
        room: String(room),
      },
      fields,
      timestamp: ts,
    });
  }

  return points;
}

function stepApplianceState(deviceId, sample, ctx, config, nowMs) {
  if (typeof deviceId !== 'string' || !deviceId || !sample || typeof sample !== 'object' || !config || typeof config !== 'object') {
    return [];
  }

  const ms = resolveNowMs(nowMs);
  const ts = new Date(ms);
  const store = ctx && typeof ctx === 'object' ? ctx : {};

  const s = getOrCreateEntry(store, deviceId, () => ({
    stateCode: null,
    aboveStartSinceMs: null,
    belowStopSinceMs: null,
    cycleStartMs: null,
    cycleStartWh: null,
    doneSinceMs: null,
    cycleEnergyWh: 0,
    cycleDurationMin: 0,
    finishedAtEpoch: 0,
    lastEmitMs: null,
  }));

  const power = isFiniteNumber(sample.power) ? sample.power : undefined;
  const energyWh = isFiniteNumber(sample.energyWh) ? sample.energyWh : undefined;
  const switchKnown = sample.switchOn === 0 || sample.switchOn === 1 || typeof sample.switchOn === 'boolean';
  const switchOnVal = (sample.switchOn === 1 || sample.switchOn === true)
    ? 1
    : ((sample.switchOn === 0 || sample.switchOn === false) ? 0 : undefined);

  const startThresholdW = isFiniteNumber(config.startThresholdW) ? config.startThresholdW : 10;
  const startHoldMs = (isFiniteNumber(config.startHoldSec) ? config.startHoldSec : 60) * 1000;
  const stopThresholdW = isFiniteNumber(config.stopThresholdW) ? config.stopThresholdW : 4;
  const stopHoldMs = (isFiniteNumber(config.stopHoldSec) ? config.stopHoldSec : 300) * 1000;
  const doneAutoResetMs = (isFiniteNumber(config.doneAutoResetMin) ? config.doneAutoResetMin : 240) * 60000;
  const runningLabel = typeof config.runningLabel === 'string' && config.runningLabel ? config.runningLabel : 'Läuft';
  const deviceName = (typeof config.deviceName === 'string' && config.deviceName)
    || (typeof config.canonicalName === 'string' && config.canonicalName)
    || (typeof sample.deviceName === 'string' && sample.deviceName)
    || deviceId;

  const prevStateCode = s.stateCode;

  if (s.stateCode === null) {
    if (switchOnVal === 0) {
      s.stateCode = 0;
    } else if (switchOnVal === 1) {
      s.stateCode = 1;
    } else if (power !== undefined && power >= startThresholdW) {
      s.stateCode = 1;
    } else {
      return [];
    }
  }

  function beginRun() {
    s.stateCode = 2;
    s.cycleStartMs = ms;
    s.cycleStartWh = energyWh !== undefined ? energyWh : null;
    s.cycleEnergyWh = 0;
    s.cycleDurationMin = 0;
    s.aboveStartSinceMs = null;
    s.belowStopSinceMs = null;
    s.doneSinceMs = null;
  }

  if (switchKnown && switchOnVal === 0) {
    s.stateCode = 0;
    s.aboveStartSinceMs = null;
    s.belowStopSinceMs = null;
    s.doneSinceMs = null;
    s.cycleStartMs = null;
    s.cycleStartWh = null;
  } else {
    if (s.stateCode === 0) {
      s.stateCode = 1;
      s.aboveStartSinceMs = null;
      s.belowStopSinceMs = null;
      s.doneSinceMs = null;
    }

    if (s.stateCode === 1) {
      if (power !== undefined) {
        if (power >= startThresholdW) {
          if (s.aboveStartSinceMs === null) {
            s.aboveStartSinceMs = ms;
          }
          if (ms - s.aboveStartSinceMs >= startHoldMs) {
            beginRun();
          }
        } else {
          s.aboveStartSinceMs = null;
        }
      }
    } else if (s.stateCode === 2) {
      if (s.cycleStartMs !== null) {
        s.cycleDurationMin = roundMilli((ms - s.cycleStartMs) / 60000);
      }
      if (energyWh !== undefined) {
        if (s.cycleStartWh === null) {
          s.cycleStartWh = energyWh;
        }
        s.cycleEnergyWh = roundMilli(energyWh - s.cycleStartWh);
      }
      if (power !== undefined) {
        if (power < stopThresholdW) {
          if (s.belowStopSinceMs === null) {
            s.belowStopSinceMs = ms;
          }
          if (ms - s.belowStopSinceMs >= stopHoldMs) {
            s.stateCode = 3;
            s.finishedAtEpoch = Math.floor(ms / 1000);
            s.doneSinceMs = ms;
            s.belowStopSinceMs = null;
            s.aboveStartSinceMs = null;
          }
        } else {
          s.belowStopSinceMs = null;
        }
      }
    } else if (s.stateCode === 3) {
      if (power !== undefined) {
        if (power >= startThresholdW) {
          if (s.aboveStartSinceMs === null) {
            s.aboveStartSinceMs = ms;
          }
          if (ms - s.aboveStartSinceMs >= startHoldMs) {
            beginRun();
          }
        } else {
          s.aboveStartSinceMs = null;
        }
      }
      if (s.stateCode === 3 && s.doneSinceMs !== null && ms - s.doneSinceMs >= doneAutoResetMs) {
        s.stateCode = 1;
        s.doneSinceMs = null;
      }
    }
  }

  const stateChanged = s.stateCode !== prevStateCode;
  const heartbeatDue = s.lastEmitMs === null || ms - s.lastEmitMs >= 300000;
  if (!stateChanged && !heartbeatDue) {
    return [];
  }

  s.lastEmitMs = ms;

  let stateText = 'Aus';
  if (s.stateCode === 1) {
    stateText = 'Bereit';
  } else if (s.stateCode === 2) {
    stateText = runningLabel;
  } else if (s.stateCode === 3) {
    stateText = 'Fertig';
  }

  return [
    {
      measurement: 'applianceState',
      tags: {
        deviceId,
        deviceName: String(deviceName),
      },
      fields: {
        stateCode: s.stateCode,
        stateText,
        cycleEnergyWh: s.cycleEnergyWh,
        cycleDurationMin: s.cycleDurationMin,
        finishedAtEpoch: s.finishedAtEpoch,
      },
      timestamp: ts,
    },
  ];
}

function buildRoomClimatePoints(events, rccById, nowMs) {
  const ts = new Date(resolveNowMs(nowMs));
  const list = normalizePayload(events);
  const points = [];

  for (const ev of list) {
    if (typeof ev.deviceId !== 'string' || !ev.deviceId || !ev.state || typeof ev.state !== 'object') {
      continue;
    }
    const isRcc = !ev.id || ev.id === 'RoomClimateControl' || ev.state['@type'] === 'climateControlState';
    if (!isRcc) {
      continue;
    }
    const rcc = lookupEntry(rccById, ev.deviceId);
    if (!rcc) {
      continue;
    }

    const room = typeof rcc === 'string'
      ? rcc
      : (rcc.matrixRoom || rcc.room || rcc.shcRoom || '');

    const fields = {
      hasDemand: ev.state.hasDemand === true ? 1 : 0,
      boostMode: ev.state.boostMode === true ? 1 : 0,
      ventilationMode: ev.state.ventilationMode === true ? 1 : 0,
      summerMode: ev.state.summerMode === true ? 1 : 0,
      operationMode: typeof ev.state.operationMode === 'string' && ev.state.operationMode
        ? ev.state.operationMode
        : 'UNKNOWN',
    };
    if (isFiniteNumber(ev.state.setpointTemperature)) {
      fields.setpoint = ev.state.setpointTemperature;
    }

    points.push({
      measurement: 'roomClimate',
      tags: {
        deviceId: ev.deviceId,
        room: String(room),
      },
      fields,
      timestamp: ts,
    });
  }

  return points;
}

function buildSecurityPoints(events, nowMs) {
  const ts = new Date(resolveNowMs(nowMs));
  const list = normalizePayload(events);
  const points = [];

  for (const ev of list) {
    if (!ev.state || typeof ev.state !== 'object') {
      continue;
    }
    const stateType = ev.state['@type'];
    const svcId = ev.id;

    if (svcId === 'IntrusionDetectionControl' || stateType === 'intrusionDetectionControlState') {
      const val = ev.state.value;
      if (typeof val !== 'string' || !val) {
        continue;
      }
      let armed = 0;
      if (val === 'SYSTEM_ARMED') {
        armed = 1;
      } else if (val === 'SYSTEM_ARMING') {
        armed = 2;
      }
      points.push({
        measurement: 'securityStatus',
        tags: {
          deviceId: typeof ev.deviceId === 'string' && ev.deviceId ? ev.deviceId : 'intrusionDetectionSystem',
          service: 'IntrusionDetectionControl',
        },
        fields: {
          armed,
          statusText: val,
        },
        timestamp: ts,
      });
    } else if (svcId === 'SurveillanceAlarm' || stateType === 'surveillanceAlarmState') {
      const val = ev.state.value;
      if (typeof val !== 'string' || !val) {
        continue;
      }
      points.push({
        measurement: 'securityStatus',
        tags: {
          deviceId: typeof ev.deviceId === 'string' && ev.deviceId ? ev.deviceId : 'intrusionDetectionSystem',
          service: 'SurveillanceAlarm',
        },
        fields: {
          alarmActive: val === 'ALARM_OFF' ? 0 : 1,
          statusText: val,
        },
        timestamp: ts,
      });
    } else if (svcId === 'PresenceSimulationConfiguration' || stateType === 'presenceSimulationConfigurationState') {
      if (typeof ev.state.enabled !== 'boolean') {
        continue;
      }
      const enabled = ev.state.enabled === true;
      points.push({
        measurement: 'securityStatus',
        tags: {
          deviceId: typeof ev.deviceId === 'string' && ev.deviceId ? ev.deviceId : 'presenceSimulationService',
          service: 'PresenceSimulationConfiguration',
        },
        fields: {
          presenceSimEnabled: enabled ? 1 : 0,
          statusText: enabled ? 'ENABLED' : 'DISABLED',
        },
        timestamp: ts,
      });
    }
  }

  return points;
}

function extractFaultLabel(entry, serviceId) {
  if (typeof entry === 'string') {
    return entry;
  }
  if (entry && typeof entry === 'object') {
    return entry.description || entry.message || entry.type || entry.faultType || entry.code || entry.category || serviceId || 'FAULT';
  }
  return serviceId || 'FAULT';
}

function buildDeviceHealthPoints(devices, services, physicalModels, nameOverrides, nowMs) {
  const ts = new Date(resolveNowMs(nowMs));
  const deviceList = normalizePayload(devices);
  const serviceList = normalizePayload(services);

  const allowedModels = physicalModels instanceof Set
    ? physicalModels
    : new Set(Array.isArray(physicalModels) ? physicalModels : []);
  if (allowedModels.size === 0) {
    return [];
  }

  const faultsByDevice = new Map();
  for (const svc of serviceList) {
    if (typeof svc.deviceId !== 'string' || !svc.deviceId) {
      continue;
    }
    const entries = svc.faults && Array.isArray(svc.faults.entries) ? svc.faults.entries : [];
    if (entries.length === 0) {
      continue;
    }
    let bucket = faultsByDevice.get(svc.deviceId);
    if (!bucket) {
      bucket = { count: 0, labels: [] };
      faultsByDevice.set(svc.deviceId, bucket);
    }
    bucket.count += entries.length;
    for (const entry of entries) {
      const label = extractFaultLabel(entry, svc.id);
      if (label) {
        bucket.labels.push(String(label));
      }
    }
  }

  const points = [];
  for (const device of deviceList) {
    if (typeof device.id !== 'string' || !device.id || !allowedModels.has(device.deviceModel)) {
      continue;
    }

    const override = lookupEntry(nameOverrides, device.id);
    let deviceName = device.name || device.id;
    let overrideRoom;
    if (typeof override === 'string' && override) {
      deviceName = override;
    } else if (override && typeof override === 'object') {
      deviceName = override.deviceName || override.canonicalName || override.name || deviceName;
      overrideRoom = override.room || override.matrixRoom || override.shcRoom;
    }

    const room = overrideRoom || device.room || device.roomName || device.roomId || 'Unbekannt';
    const statusText = typeof device.status === 'string' && device.status ? device.status : 'UNDEFINED';
    const available = statusText === 'AVAILABLE' ? 1 : 0;

    const faultInfo = faultsByDevice.get(device.id);
    const faultCount = faultInfo ? faultInfo.count : 0;
    const faultSummary = faultCount === 0
      ? 'OK'
      : (faultInfo.labels.length > 0 ? faultInfo.labels.join(', ') : 'FAULT');

    points.push({
      measurement: 'deviceHealth',
      tags: {
        deviceId: device.id,
        deviceName: String(deviceName),
        deviceModel: String(device.deviceModel),
        room: String(room),
      },
      fields: {
        available,
        statusText,
        faultCount,
        faultSummary,
      },
      timestamp: ts,
    });
  }

  return points;
}

function buildContactStatusPoints(contactEvents, deviceStatusById, contactsById, nowMs) {
  const ts = new Date(resolveNowMs(nowMs));
  const list = normalizePayload(contactEvents);
  const points = [];

  for (const ev of list) {
    const deviceId = ev.deviceId;
    if (typeof deviceId !== 'string' || !deviceId) {
      continue;
    }
    const stateObj = ev.state && typeof ev.state === 'object' ? ev.state : null;
    const isShutter = !ev.id || ev.id === 'ShutterContact' || (stateObj && stateObj['@type'] === 'shutterContactState');
    if (!isShutter) {
      continue;
    }

    const contact = lookupEntry(contactsById, deviceId);
    if (!contact) {
      continue;
    }

    const statusEntry = lookupEntry(deviceStatusById, deviceId);
    const devStatus = statusEntry && typeof statusEntry === 'object' ? statusEntry.status : statusEntry;
    const isKnownUnavailable = devStatus !== undefined && devStatus !== null && devStatus !== 'AVAILABLE';
    const available = devStatus === 'AVAILABLE' ? 1 : 0;
    const rawState = stateObj ? stateObj.value : undefined;

    let state;
    if (isKnownUnavailable) {
      state = 'UNAVAILABLE';
    } else if (rawState === 'OPEN' || rawState === 'CLOSED') {
      state = rawState;
    } else {
      continue;
    }

    const isOpen = available === 1 && state === 'OPEN' ? 1 : 0;
    const deviceName = typeof contact === 'string'
      ? contact
      : (contact.canonicalName || contact.deviceName || contact.shcName || deviceId);
    const room = typeof contact === 'string'
      ? ''
      : (contact.matrixRoom || contact.shcRoom || '');

    points.push({
      measurement: 'contactStatus',
      tags: {
        deviceId,
        deviceName: String(deviceName),
        room: String(room),
      },
      fields: {
        state,
        isOpen,
        available,
      },
      timestamp: ts,
    });
  }

  return points;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    normalizePayload,
    buildPowerMeterPoints,
    stepApplianceState,
    buildRoomClimatePoints,
    buildSecurityPoints,
    buildDeviceHealthPoints,
    buildContactStatusPoints,
  };
}
