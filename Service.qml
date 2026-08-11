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

  property string _stdout: ""
  property string _stderr: ""

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

  function refresh() {
    if (statusProcess.running || helperPath === "") return
    _stdout = ""
    _stderr = ""
    refreshing = true
    statusProcess.command = [helperPath, "--instances", instancesJson, "--timeout", String(timeoutSec)]
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
      onStreamFinished: root._stdout = text
    }
    stderr: StdioCollector {
      id: statusStderr
      waitForEnd: true
      onStreamFinished: root._stderr = text
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var output = String(statusStdout.text || root._stdout || "")
      if (output.trim() !== "") root.applyStatus(output)
      else {
        var error = String(statusStderr.text || root._stderr || "").replace(/\s+/g, " ").trim()
        root.lastError = error || "Hive status helper failed"
        root.status = Model.emptyStatus(root.lastError)
      }
    }
  }
}
