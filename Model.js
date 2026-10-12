.pragma library

// ---------------------------------------------------------------------------
// Battery helpers — ported from the built-in omarchy.power widget.
// ---------------------------------------------------------------------------

function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, index))
}

function selectProfileIndex(index, delta, list) {
  var values = Array.isArray(list) ? list : []
  if (values.length === 0) return 0
  return clampIndex(index + delta, values.length)
}

function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf("\t")
    if (idx <= 0) continue
    next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
  }
  return next
}

function batteryFraction(device) {
  return device && device.isPresent ? Math.max(0, Math.min(1, device.percentage)) : 0
}

function chargeThresholdActive(device, onBattery, states) {
  var d = device || {}
  var s = states || {}
  if (!(d && d.isPresent && !onBattery)) return false

  var fraction = batteryFraction(d)
  if (d.state === s.Discharging) return false
  if (d.state === s.PendingCharge) return true
  if (d.state === s.FullyCharged && fraction < 0.99) return true
  if (d.state !== s.Charging || fraction >= 0.99) return false

  return Number(d.changeRate || 0) <= 0.2 || Number(d.timeToFull || 0) >= 8 * 60 * 60
}

function batteryIcon(device, onBattery, states) {
  var d = device || {}
  if (!d.isPresent) return ""

  // fw13-hyprland battery glyphs: Font Awesome battery-empty → battery-full
  // (carried by the Nerd Font), with a bolt while charging.
  var levels = ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
  var chargingGlyph = "\uf0e7"
  var index = Math.max(0, Math.min(4, Math.round((Number(d.percentage) || 0) * 4)))
  var threshold = chargeThresholdActive(d, onBattery, states)

  if (threshold) return levels[index]
  if (d.state === states.FullyCharged) return levels[4]
  if (!onBattery) return chargingGlyph
  return levels[index]
}

function modeLabel(device, onBattery, states) {
  var d = device || {}
  if (!d.isPresent) return ""

  var percentage = d.isPresent ? d.percentage : 0
  if (chargeThresholdActive(d, onBattery, states)) return "Threshold"
  if (onBattery) return "On battery"
  if (!onBattery && percentage >= 1) return "Fully charged"
  return "Charging"
}

// ---------------------------------------------------------------------------
// auto-cpufreq helpers.
// ---------------------------------------------------------------------------

// Governor-override picker. "auto" clears the override (daemon decides),
// "powersave"/"performance" pin the governor via `auto-cpufreq --force`.
var MODES = [
  { id: "auto", label: "Auto", icon: "󰊚" },
  { id: "powersave", label: "Saver", icon: "󰌪" },
  { id: "performance", label: "Perf", icon: "󰓅" }
]

var TURBO_MODES = [
  { id: "auto", label: "Auto" },
  { id: "never", label: "Never" },
  { id: "always", label: "Always" }
]

function modes() {
  return MODES.slice()
}

function turboModes() {
  return TURBO_MODES.slice()
}

// The service reports force as "auto" | "powersave" | "performance".
function modeIndex(force) {
  for (var i = 0; i < MODES.length; i++)
    if (MODES[i].id === force) return i
  return 0
}

function turboIndex(override) {
  for (var i = 0; i < TURBO_MODES.length; i++)
    if (TURBO_MODES[i].id === override) return i
  return 0
}

function modeIcon(id) {
  for (var i = 0; i < MODES.length; i++)
    if (MODES[i].id === id) return MODES[i].icon
  return "󰊚"
}

// Human-friendly governor/EPP/platform strings.
function pretty(value) {
  var v = String(value === undefined || value === null ? "" : value).trim()
  if (v === "" || v === "-") return "—"
  return v.replace(/_/g, " ").replace(/\b\w/g, function(c) { return c.toUpperCase() })
}

function daemonLabel(installed, active) {
  if (installed !== "1") return "Not installed"
  return active === "1" ? "Running" : "Stopped"
}

if (typeof module !== "undefined") {
  module.exports = {
    clampIndex: clampIndex,
    selectProfileIndex: selectProfileIndex,
    parseKeyValue: parseKeyValue,
    batteryFraction: batteryFraction,
    chargeThresholdActive: chargeThresholdActive,
    batteryIcon: batteryIcon,
    modeLabel: modeLabel,
    modes: modes,
    turboModes: turboModes,
    modeIndex: modeIndex,
    turboIndex: turboIndex,
    modeIcon: modeIcon,
    pretty: pretty,
    daemonLabel: daemonLabel
  }
}
