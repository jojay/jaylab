# Sonoff ZBDongle-P als Router im bestehenden Zigbee-Netz

Stand: 27. November 2026. **Anleitung, nicht ausgeführt.** Der vorhandene
Coordinator und das produktive Zigbee-Netz wurden hierfür nicht geändert.

## Ziel und Grenzen

Der Betreiber meldet für den ungenutzten Zweitstick die Gehäusekennung
`2APN5ZBD-P`. Das kennzeichnet den Sonoff ZBDongle-P mit TI-CC2652P. Er soll
mit Router-Firmware als zusätzlicher Zigbee-Router dem vorhandenen
Zigbee2MQTT-Netz beitreten.

Als Ausgangslage ist bestätigt, daß der Sensor `Tiefkeller` (Xiaomi
`WSDCGQ11LM`) in Coordinator-Nähe bereits zuverlässig funkt und der Empfang
erst im Tiefkeller abreißt.

Der dokumentierte Coordinator läuft in `proxmox`, CT 121, mit Zigbee2MQTT
1.29.2. Diese Angabe stammt aus dem Zugangsbericht und ist vor dem späteren
Beitritt am laufenden Dienst zu prüfen. Nur den ungenutzten Zweitstick flashen.
Nicht den Coordinator aus CT 121 abziehen oder flashen. Keine zweite
Zigbee2MQTT-Instanz anlegen und weder Kanal noch Netzkennung oder Netzschlüssel
ändern.

Laut [Zigbee2MQTT-Zugang und Empfangsprüfung](ZIGBEE2MQTT-ZUGANG-UND-EMPFANG.md)
steht `permit_join: true` dauerhaft in `configuration.yaml`. Diese Anleitung
steuert den Beitritt ausschließlich über die Zigbee2MQTT-Oberfläche (bei Bedarf
über den dort dokumentierten lokalen SSH-Tunnel) und läßt `configuration.yaml`
unverändert.

Die dokumentierte Zigbee2MQTT-Version ist alt. Ein unbekannter Gerätename in
der Oberfläche ist nicht allein ein Fehlernachweis; entscheidend ist, daß der
neue Eintrag als Router beitritt und die Funkroute bzw. der Empfang geprüft
werden kann. Erscheint kein neuer Router oder ist seine Rolle unklar, vor
weiteren Schritten anhalten und Protokoll sowie Geräteansicht prüfen.

## Voraussetzungen

- Windows-PC in sicherer Funknähe des Coordinators (`proxmox`, CT 121), mit
  aktuellem Chrome oder Edge, einem USB-A-Anschluß und installiertem
  Silicon-Labs-CP210x-VCP-Treiber für die COM-Anschluß-Erkennung des
  ZBDongle-P.
- Der ungenutzte ZBDongle-P mit vor dem Einschalten montierter SMA-Antenne; die
  aktive Zigbee2MQTT-Instanz bleibt unverändert.
- Der Coordinator, Zigbee2MQTT und der Zugang zur Zigbee2MQTT-Oberfläche
  (direkt oder über den dokumentierten SSH-Tunnel) sind erreichbar, damit der
  Router dem bestehenden Netz beitreten kann.
- Eine trockene, dauerhaft mit Strom versorgte Steckdose mit einem dauerhaft
  versorgten 5-V-USB-A-Netzteil (keine Powerbank mit Niedrigstrom-Abschaltung)
  am späteren Aufstellort. Eine USB-A-Verlängerung ist für die Funkposition
  sinnvoll.
- Firmware ausschließlich aus dem unten verlinkten Koenkk-Release.

Der Router-Build für den ZBDongle-P ist
`CC1352P2_CC2652P_launchpad_router_20250403.zip`. Nicht die Dateien für
`ZBDongle-E`, `CC1352P7`, `other` oder `coordinator` verwenden.

## Schritt 1: Firmware laden und prüfen

1. Im Repository-Stamm ein Arbeitsverzeichnis anlegen:

   ```powershell
   New-Item -ItemType Directory -Force .local\zigbee-router
   ```

2. Die ZIP-Datei aus dem
   [offiziellen Koenkk-Release](https://github.com/Koenkk/Z-Stack-firmware/releases/tag/Z-Stack_3.x.0_router_20250403)
   laden. Der passende Eintrag heißt exakt
   `CC1352P2_CC2652P_launchpad_router_20250403.zip`.
3. Den SHA-256-Wert der heruntergeladenen Datei prüfen:

   ```powershell
   Get-FileHash .local\zigbee-router\CC1352P2_CC2652P_launchpad_router_20250403.zip -Algorithm SHA256
   ```

   Erwartet:

   ```text
   86BF0527FBC70B76DF9144FCF6B3A80E18D69AA1EB5AB24BC48A2BB9FCDEE9C2
   ```

   Bei einer Abweichung **nicht flashen**. Die Datei aus dem Release entpacken
   und darin die Datei
   `CC1352P2_CC2652P_launchpad_router_20250403.hex` verwenden.

Der Hash ist der SHA-256-Wert des ZIP-Assets aus den Release-Metadaten. Das
[Zigbee2MQTT-Adapterverzeichnis](https://www.zigbee2mqtt.io/guide/adapters/zstack.html)
ordnet diesen Router-Build ausdrücklich dem ZBDongle-P zu.

## Schritt 2: Den richtigen USB-Anschluß bestimmen

Vor dem Anstecken prüfen, daß die aufschraubbare SMA-Antenne am Zweitstick
montiert ist.

1. Vor dem Anstecken in Windows den Geräte-Manager öffnen und unter
   **Anschlüsse (COM & LPT)** die vorhandenen Geräte notieren.
2. Nur den ungenutzten Zweitstick anstecken. Der neu erscheinende COM-Anschluß
   gehört zum Zweitstick. Bei Zweifel wieder abziehen und vergleichen.
3. Erscheint der Stick statt unter **Anschlüsse (COM & LPT)** unter **Andere
   Geräte** (z. B. als `CP2102N USB to UART Bridge Controller`), zuerst den
   Silicon-Labs-CP210x-VCP-Treiber installieren und danach den COM-Anschluß
   eindeutig prüfen.
4. Sicherstellen, daß ausschließlich dieser Stick für den Flash-Vorgang
   ausgewählt wird. Der produktive Coordinator darf nicht am PC angeschlossen
   und nicht Ziel des Flashers sein.

## Schritt 3: Router-Firmware flashen

1. Mit Chrome oder Edge den
   [SONOFF Dongle Flasher](https://dongle.sonoff.tech/sonoff-dongle-flasher/)
   öffnen.
2. **Connect** wählen und den in Schritt 2 ermittelten COM-Anschluß des
   Zweitsticks freigeben.
3. Die Option **Custom** wählen und die entpackte Datei
   `CC1352P2_CC2652P_launchpad_router_20250403.hex` angeben.
4. Den Flash-Vorgang starten und warten, bis der Flasher den erfolgreichen
   Abschluß meldet. Währenddessen weder Stick noch Browser trennen.

Die aktuelle Zigbee2MQTT-Anleitung beschreibt für den ZBDongle-P ausdrücklich
den Web-Flasher mit einem benutzerdefinierten HEX-Image. Öffnet der Flasher den
COM-Anschluß nicht, stimmt der COM-Anschluß nicht eindeutig, wird die
`.hex`-Datei nicht angenommen oder scheitert Auto-BSL bzw. meldet die Prüfung
einen Fehler: abbrechen, Ursache klären und als Ausweichweg das
[XZG Multi-Tool](https://mt.xyzroe.cc/) oder `cc2538-bsl` verwenden. Das
Gehäuse nicht öffnen und keine Pins überbrücken.

## Schritt 4: Beitritt in Zigbee2MQTT prüfen und Router aufstellen

1. Erst **nach** erfolgreichem Abschluß des Flash-Vorgangs in der
   Zigbee2MQTT-Oberfläche den Beitritt neuer Geräte erlauben. (Hinweis: Bei
   bestehendem `permit_join: true` in `configuration.yaml` bleibt diese Datei
   unverändert.)
2. Da der Windows-PC in sicherer Funknähe des Coordinators steht, den Zweitstick
   unmittelbar danach direkt am PC kurz ab- und wieder anstecken, damit er mit
   der Router-Firmware neu startet und dem Netz beitritt.
3. In Zigbee2MQTT prüfen, daß ein neuer Eintrag erscheint und als Router
   erkennbar ist. Diesem Eintrag sofort einen **eindeutigen Gerätenamen**
   (z. B. `Router Keller`) vergeben, um ihn von bestehenden Routern zu
   unterscheiden und später gezielt „Permit join“ für diesen Router auswählen zu
   können. Danach die Join-Freigabe in der Oberfläche wieder schließen (wirkt
   bei `permit_join: true` in `configuration.yaml` nur bis zum nächsten
   Dienstneustart). Bei ausbleibendem Eintrag die Join-Freigabe schließen und
   zuerst Dienstprotokoll und Geräteliste prüfen. Nicht wiederholt blind flashen
   oder den Zigbee-Koordinator zurücksetzen.
4. Den Stick vom PC trennen und mit montierter SMA-Antenne an einem dauerhaft
   versorgten 5-V-USB-A-Netzteil am geplanten Zwischenpunkt mit noch
   erreichbarem Zigbee-Funkweg aufstellen, nicht hinter Metall oder in einem
   abgeschirmten Schaltschrank. Er benötigt danach keinen Raspberry Pi oder
   anderen Rechner. Eine USB-A-Verlängerung kann den Abstand zu Metall,
   Rechnern und USB-3-Geräten verbessern.
5. **Vor** dem Test von `Tiefkeller` am endgültigen Aufstellort in Zigbee2MQTT
   (Geräteansicht/LQI und Netzwerkkarte) prüfen, daß der Router selbst eine
   stabile Funkverbindung zum bestehenden Netz hält. Ein Standort außerhalb
   jeder Coordinator-Reichweite kann keine Lücke überbrücken.

Beim ZBDongle-P ist die rote LED eine Betriebsanzeige; laut
[Adapterbeschreibung](https://www.zigbee2mqtt.io/guide/adapters/zstack.html)
zeigt sie mit Router-Firmware nicht zuverlässig den Netzwerkbeitritt an.

## Schritt 5: Empfang abnehmen

### Stufe 1: Normales Aufwecken

1. Den Sensor `Tiefkeller` ohne Zurücksetzen normal aufwecken bzw. auslösen.
2. Einen frischen, nicht-retained Bericht, einen vorgerückten `lastSeen`-Wert
   sowie `linkquality` prüfen. Ein alter Cachewert oder ein Geräte-Eintrag
   allein belegt keinen Empfang.
3. Die lesende Beobachtung kann mit folgendem Skript wiederholt werden:

   ```powershell
   pwsh -NoProfile -File scripts/Observe-JaylabZigbee.ps1 -Seconds 180
   ```

   Die vorhandene Dokumentation beschreibt die Grenzen dieser Prüfung in
   [Zigbee2MQTT-Zugang und Empfangsprüfung](ZIGBEE2MQTT-ZUGANG-UND-EMPFANG.md).
   Nach dem Umstellen des Routers kann die Funkroute verzögert wechseln.
   Fehlende Sofortwirkung ist kein Grund, den Sensor zurückzusetzen oder das
   Zigbee-Netz neu aufzubauen.

### Stufe 2: Gezieltes Neu-Verbinden am neuen Router (falls Empfang ausbleibt)

Xiaomi-`WSDCGQ11LM`-Sensoren klammern sich erfahrungsgemäß an ihren bisherigen
Parent (hier den Coordinator) und wechseln ihre Funkroute durch bloßes
Aufwecken kaum selbständig. Bleibt der Empfang in Stufe 1 aus:

1. In der Zigbee2MQTT-Oberfläche „Permit join“ **gezielt nur am neuen Router**
   (z. B. `Router Keller`) aktivieren.
2. `Tiefkeller` am neuen Router bzw. am Einsatzort per Taste neu verbinden,
   **ohne** das Gerät zuvor in Zigbee2MQTT zu löschen (Gerätename und Zuordnung
   bleiben erhalten).
3. Die Join-Freigabe in der Oberfläche anschließend wieder schließen und den
   Empfang erneut über `lastSeen`, `linkquality`, Netzwerkkarte und
   `Observe-JaylabZigbee.ps1` abnehmen.

## Rückweg

- Bei fehlgeschlagenem Flashen den Zweitstick nicht am produktiven Coordinator
  betreiben. Erst Fehler und COM-Auswahl prüfen; bei Bedarf den Dongle-Flasher,
  das [XZG Multi-Tool](https://mt.xyzroe.cc/), `cc2538-bsl` oder die in der
  [Zigbee2MQTT-Anleitung](https://www.zigbee2mqtt.io/guide/adapters/zstack.html)
  genannten TI-Werkzeuge verwenden.
- Bei fehlender Verbesserung den Zweitstick vom Strom trennen und in
  Zigbee2MQTT nur diesen Router entfernen. Der bestehende Coordinator, dessen
  Netzkennung und die übrigen Geräte bleiben unverändert.
- Eine Rückkehr zur Coordinator-Rolle erfordert eine passende
  CC2652P-Coordinator-Firmware. Den Stick danach nicht ohne Prüfung seines
  gespeicherten Netzwerkzustands als zweiten Coordinator an das bestehende
  Netz anschließen. Das bloße Wiederherstellen der Coordinator-Firmware ist
  kein Rückweg für den produktiven Coordinator und stellt nicht zwingend die
  ursprüngliche Firmwarefassung des Zweitsticks wieder her.

## Quellen

- [Zigbee2MQTT: ZBDongle-P und Router-Firmware](https://www.zigbee2mqtt.io/guide/adapters/zstack.html)
- [Koenkk: Router-Firmware und Beitritt nach dem Flashen](https://github.com/Koenkk/Z-Stack-firmware/tree/master/router/Z-Stack_3.x.0)
- [SONOFF Dongle Flasher](https://dongle.sonoff.tech/sonoff-dongle-flasher/)
- [XZG Multi-Tool](https://mt.xyzroe.cc/)
