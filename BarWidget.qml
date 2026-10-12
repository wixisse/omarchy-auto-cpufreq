import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Auto CPU Freq — bar widget.
//
// A clone of the built-in omarchy.power widget (battery hero, progress bar and
// stats) whose power section drives auto-cpufreq instead of
// power-profiles-daemon. The auto-cpufreq state is read from the plugin's
// shared service; the battery hero keeps using UPower for the bar icon and the
// stock omarchy-battery-status/omarchy-system-stats helpers for the details.
Panel {
  id: root

  moduleName: "othmane-wadi.autocpufreq"
  ipcTarget: moduleName
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the refresh() method below.
  manageIpc: false

  property var batteryInfo: ({})
  property var systemInfo: ({})
  property var localState: ({})
  property int modeIndex: 0
  property int turboIndex: 0
  property bool cursorActive: false

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property string binDir: String(Qt.resolvedUrl("bin")).replace(/^file:\/\//, "")

  // The plugin's process-wide service. Falls back to a widget-local poll when
  // the service has not been published yet, so the popout is never blank.
  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(root.moduleName) : null
  readonly property var st: svc ? (svc.status || ({})) : localState

  readonly property var modes: Model.modes()
  readonly property var turboModes: Model.turboModes()

  readonly property bool installed: (st.installed || "0") === "1"
  readonly property bool daemonActive: (st.active || "0") === "1"
  readonly property string version: st.version && st.version !== "-" ? st.version : ""
  readonly property string force: st.force || "auto"
  readonly property string turboOverride: st.turbo_override || "auto"

  readonly property bool showPercentage: setting("showPercentage", false) === true
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function selectProfileByDelta(delta) {
    modeIndex = Model.selectProfileIndex(modeIndex, delta, modes)
  }

  function activateSelectedMode() {
    if (modeIndex < 0 || modeIndex >= modes.length) return
    setMode(modes[modeIndex].id)
  }

  function batteryIcon() {
    return Model.batteryIcon(UPower.displayDevice, root.discharging, upowerStates())
  }

  function modeLabel() {
    return Model.modeLabel(UPower.displayDevice, root.discharging, upowerStates())
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive
  readonly property real batteryFraction: Model.batteryFraction(UPower.displayDevice)
  readonly property bool charging: {
    var d = UPower.displayDevice
    return d && d.isPresent && !UPower.onBattery && !root.batteryFlowIdle
  }
  readonly property color batteryFillColor: bar ? bar.foreground : Color.foreground

  readonly property var chargingPhrases: [
    "Pumping power", "Injecting electrons", "Pouring juice",
    "Amassing watts", "Hoarding joules", "Topping reserves", "Soaking amps"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power", "Spending joules", "Draining watts",
    "Burning electrons", "Sipping juice", "Spending coulombs", "Bleeding amps"
  ]
  property int phraseIndex: 0
  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0
  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!root.batteryPresent) return
    if (!batteryProc.running) batteryProc.running = true
    if (!systemProc.running) systemProc.running = true
    if (svc) svc.refresh()
    else if (!statusProc.running) statusProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function updateLocalState(raw) {
    var next = Model.parseKeyValue(raw)
    if (Object.keys(next).length === 0) return
    localState = next
  }

  function runAction(verb, arg) {
    if (!binDir || actionProc.running) return
    actionProc.command = [root.binDir + "/autocpufreq-action", String(verb), String(arg || "")]
    actionProc.running = true
  }

  function setMode(id) {
    runAction("mode", id)
  }

  function setTurbo(id) {
    runAction("turbo", id)
  }

  function openTerminal(which) {
    if (!binDir) return
    Quickshell.execDetached([root.binDir + "/autocpufreq-action", String(which)])
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (bar && bar.shell && bar.shell.updateEntryInline) bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh(); if (root.svc) root.svc.refresh() }
    function togglePercentage(): void { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }
      refresh()
      var idx = svc ? Model.modeIndex(svc.force) : 0
      modeIndex = idx >= 0 ? idx : 0
      cursorActive = false
    }
  }
  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: systemProc
    command: ["omarchy-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  Process {
    id: statusProc
    command: [root.binDir + "/autocpufreq-status"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateLocalState(text) }
  }

  Process {
    id: actionProc
    onExited: {
      root.refresh()
      if (root.svc) root.svc.refresh()
    }
  }

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation { target: heroStatus; property: "opacity"; to: 0.0; duration: 180; easing.type: Easing.OutQuad }
    ScriptAction {
      script: {
        var n = root.activePhrases.length
        if (n > 0) root.phraseIndex = (root.phraseIndex + 1) % n
      }
    }
    PropertyAnimation { target: heroStatus; property: "opacity"; to: 1.0; duration: 260; easing.type: Easing.InQuad }
  }

  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.selectProfileByDelta(dx)
        else if (dy !== 0) root.selectProfileByDelta(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedMode()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: battery icon · status · percentage ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.batteryIcon()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Auto CPU Freq"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              textFormat: Text.PlainText
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            textFormat: Text.PlainText
            text: root.batteryInfo.percentage || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // ---------- Battery progress bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.batteryFillColor
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        // ---------- Battery stats ----------
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Battery size"; value: root.batteryInfo.size || "" }
            InfoPair { label: "Charge cycles"; value: root.batteryInfo.cycles || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
              value: root.chargeThresholdActive ? (root.batteryInfo.threshold || "-") : (root.batteryFlowIdle ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive ? "Battery state" : (root.discharging ? "Discharging" : "Charging")
              value: root.chargeThresholdActive ? "Holding" : (root.batteryFull ? "-" : (root.batteryInfo.rate || ""))
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // ---------- auto-cpufreq ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "AUTO CPU FREQ"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          InfoPair {
            label: "Daemon"
            value: root.installed
              ? Model.daemonLabel(root.st.installed || "0", root.st.active || "0") + (root.version ? " · v" + root.version : "")
              : "Not installed"
          }

          Row {
            id: modeRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: root.modes.length > 0
              ? (width - spacing * (root.modes.length - 1)) / root.modes.length
              : 0

            Repeater {
              model: root.modes
              ChoiceChip {
                required property var modelData
                required property int index
                width: modeRow.cellWidth
                option: modelData
                isSelected: root.force === modelData.id
                cursorHere: root.cursorActive && root.modeIndex === index
                onPicked: root.setMode(modelData.id)
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.modeIndex = index
                  }
                }
              }
            }
          }

          InfoPair { label: "Turbo"; value: Model.pretty(root.st.turbo) }

          Row {
            id: turboRow
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: root.turboModes.length > 0
              ? (width - spacing * (root.turboModes.length - 1)) / root.turboModes.length
              : 0

            Repeater {
              model: root.turboModes
              ChoiceChip {
                required property var modelData
                width: turboRow.cellWidth
                option: modelData
                isSelected: root.turboOverride === modelData.id
                onPicked: root.setTurbo(modelData.id)
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap
            InfoPair { label: "Governor"; value: Model.pretty(root.st.governor) }
            InfoPair { label: "EPP"; value: Model.pretty(root.st.epp) }
            InfoPair { label: "Platform"; value: Model.pretty(root.st.platform_profile) }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Live stats"
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              onClicked: { root.openTerminal("stats"); root.close() }
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Monitor"
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              enabled: root.installed
              onClicked: { root.openTerminal("monitor"); root.close() }
            }
          }
        }
      }
    }
  }

  // Pick-one chip. The kit's plain Button paints its selected state from the
  // theme's `selected-color` token, which defaults to the (grey/white)
  // foreground — so a chosen option barely reads. Instead: a soft accent tint
  // with accent text and a hairline accent border. Coloured enough to stand
  // out, light enough that the label stays legible.
  component ChoiceChip: Button {
    id: chip

    property var option: null
    property bool isSelected: false
    property bool cursorHere: false

    signal picked()

    text: chip.option ? String(chip.option.label) : ""
    iconText: chip.option && chip.option.icon ? String(chip.option.icon) : ""
    iconSize: Style.font.title
    fontSize: Style.font.bodySmall
    fontFamily: root.bar.fontFamily
    horizontalPadding: Style.spacing.controlPaddingX
    verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
    bordered: true

    selected: chip.isSelected
    hasCursor: chip.cursorHere

    color: chip.isSelected
      ? Util.alpha(Color.accent, 0.16)
      : chip.hot ? Style.hoverFillFor(root.bar.foreground, Color.accent)
      : chip.background
    foreground: chip.isSelected ? Color.accent : root.bar.foreground
    borderSpec: chip.isSelected
      ? Border.controlSpec("normal", Color.accent, Color.accent)
      : chip.hot ? Border.controlSpec("hover-cursor", root.bar.foreground, Color.accent)
      : Border.controlSpec("normal", root.bar.foreground, Color.accent)

    onClicked: chip.picked()
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
