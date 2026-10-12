import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "BatteryModel.js" as BatteryModel
import "Model.js" as Model

// Auto CPU Freq — process-wide service.
//
// Owns two things that must survive a panel closing and be shared across every
// monitor: the polled auto-cpufreq status (governor, EPP, turbo, platform
// profile, saved overrides) and the low-battery warning ported from the
// built-in omarchy.battery service. Where that service drove
// power-profiles-daemon through omarchy-powerprofiles-set, this one reports the
// auto-cpufreq daemon's status instead; the daemon itself performs the automatic
// profile switching.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string binDir: String(Qt.resolvedUrl("bin")).replace(/^file:\/\//, "")

  // Parsed autocpufreq-status output, plus bookkeeping.
  property var status: ({})
  property bool refreshing: false
  property string lastError: ""
  property date lastUpdated: new Date(0)

  readonly property string installed: status.installed || "0"
  readonly property string active: status.active || "0"
  readonly property string version: status.version || ""
  readonly property string force: status.force || "auto"
  readonly property string turboOverride: status.turbo_override || "auto"
  readonly property string governor: status.governor || "-"
  readonly property string epp: status.epp || "-"
  readonly property string turbo: status.turbo || "unknown"
  readonly property string platformProfile: status.platform_profile || "-"
  readonly property string platformProfiles: status.platform_profiles || "-"

  readonly property int batteryThreshold: 10

  PersistentProperties {
    id: persisted
    reloadableId: "othmane-wadi-autocpufreq"
    property bool notifiedLowBattery: false
  }

  function refresh() {
    if (!binDir || statusProcess.running) return
    refreshing = true
    statusProcess.running = true
  }

  function updateState(raw) {
    refreshing = false
    var parsed = Model.parseKeyValue(raw)
    if (Object.keys(parsed).length === 0) {
      lastError = "empty status"
      return
    }
    lastError = ""
    status = parsed
    lastUpdated = new Date()
  }

  function batteryPercentage() {
    return BatteryModel.batteryPercentage(UPower.displayDevice)
  }

  function isDischarging() {
    return BatteryModel.isDischarging(UPower.displayDevice, UPower.onBattery, UPowerDeviceState.Discharging)
  }

  function checkBattery() {
    var s = BatteryModel.shouldWarnLowBattery(UPower.displayDevice, UPower.onBattery,
      UPowerDeviceState.Discharging, batteryThreshold, persisted.notifiedLowBattery)
    persisted.notifiedLowBattery = s.notifiedLowBattery
    if (s.notify) sendLowBatteryWarning(s.level)
  }

  function sendLowBatteryWarning(level) {
    if (warningProcess.running) return
    warningProcess.command = ["omarchy-battery-low", String(level)]
    warningProcess.running = true
  }

  Process { id: warningProcess }

  Process {
    id: statusProcess
    command: [root.binDir + "/autocpufreq-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateState(text)
    }
    onExited: root.refreshing = false
  }

  // Poll the auto-cpufreq status. Cheap (sysfs only) and bounded.
  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Low-battery warning cadence, matching the built-in battery service.
  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.checkBattery()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      root.checkBattery()
      root.refresh()
    }
  }
}
