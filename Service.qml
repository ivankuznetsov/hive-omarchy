import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var status: Model.emptyStatus("Checking Hive…")
  property bool refreshing: false
  property string lastError: ""

  readonly property string defaultInstancesJson: "[{\"name\":\"Local\",\"url\":\"http://127.0.0.1:4567\",\"transport\":\"local\"}]"
  readonly property string instancesJson: String(setting("instancesJson", defaultInstancesJson) || "[]")
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 15, 5, 300)
  readonly property int timeoutSec: intSetting("timeoutSec", 8, 1, 30)
  readonly property bool showTaskCount: boolSetting("showTaskCount", true)
  readonly property int maxInstancesJsonBytes: 32768
  readonly property int maxInstances: 16
  readonly property int runningTaskCount: status.runningTaskCount || 0
  readonly property int daemonRunning: status.daemonRunning || 0
  readonly property int configured: status.configured || 0
  readonly property int reachable: status.reachable || 0
  readonly property var instances: status.instances || []
  readonly property string helperPath: {
    var url = Qt.resolvedUrl("scripts/hive-status").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }
  readonly property string barLabel: "🐝" + (showTaskCount && runningTaskCount > 0 ? " " + runningTaskCount : "")
  readonly property string tooltipText: Model.tooltip(status, refreshing)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (typeof value === "boolean") return value
    var normalized = String(value || "").toLowerCase()
    return normalized === "true" || normalized === "yes" || normalized === "on" || normalized === "1"
  }

  function utf8ByteLength(value, stopAfter) {
    var text = String(value || "")
    var bytes = 0
    for (var index = 0; index < text.length; index++) {
      var code = text.charCodeAt(index)
      if (code <= 0x7f) bytes += 1
      else if (code <= 0x7ff) bytes += 2
      else if (code >= 0xd800 && code <= 0xdbff && index + 1 < text.length
               && text.charCodeAt(index + 1) >= 0xdc00 && text.charCodeAt(index + 1) <= 0xdfff) {
        bytes += 4
        index += 1
      } else bytes += 3
      if (bytes > stopAfter) return bytes
    }
    return bytes
  }

  function rejectConfiguration(message) {
    refreshing = false
    lastError = message
    status = Model.emptyStatus(message)
  }

  function refresh() {
    if (statusProcess.running || helperPath === "") return
    var rawInstances = instancesJson
    if (utf8ByteLength(rawInstances, maxInstancesJsonBytes) > maxInstancesJsonBytes) {
      rejectConfiguration("Hive instances JSON exceeds the 32 KiB safety limit")
      return
    }
    var parsedInstances
    try {
      parsedInstances = JSON.parse(rawInstances)
    } catch (error) {
      rejectConfiguration("Hive instances must be valid JSON")
      return
    }
    if (!Array.isArray(parsedInstances)) {
      rejectConfiguration("Hive instances must be a JSON array")
      return
    }
    if (parsedInstances.length > maxInstances) {
      rejectConfiguration("Hive Status supports at most " + maxInstances + " instances")
      return
    }
    refreshing = true
    statusProcess.command = [helperPath, "--instances", rawInstances, "--timeout", String(timeoutSec)]
    statusProcess.running = true
  }

  function applyStatus(raw) {
    var nextStatus = Model.parseStatus(raw)
    status = nextStatus
    lastError = nextStatus.ok ? "" : nextStatus.error
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: statusStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var output = String(statusStdout.text || "")
      if (output.trim() !== "") root.applyStatus(output)
      else {
        var error = String(statusStderr.text || "").replace(/\s+/g, " ").trim().substring(0, 512)
        root.lastError = error || "Hive status helper failed"
        root.status = Model.emptyStatus(root.lastError)
      }
    }
  }
}
