function emptyStatus(message) {
  return {
    ok: false,
    configured: 0,
    reachable: 0,
    daemonRunning: 0,
    runningTaskCount: 0,
    instances: [],
    generatedAt: "",
    error: message || "Hive status is unavailable"
  }
}

function parseStatus(raw) {
  var parsed
  try {
    parsed = JSON.parse(String(raw || "{}"))
  } catch (e) {
    return emptyStatus("Hive returned invalid status data")
  }

  if (!parsed || parsed.ok !== true || !Array.isArray(parsed.instances))
    return emptyStatus(String(parsed && (parsed.message || parsed.error) || "Hive status is unavailable"))

  return {
    ok: true,
    configured: Number(parsed.configured || parsed.instances.length || 0),
    reachable: Number(parsed.reachable || 0),
    daemonRunning: Number(parsed.daemon_running || 0),
    runningTaskCount: Number(parsed.running_task_count || 0),
    instances: parsed.instances,
    generatedAt: String(parsed.generated_at || ""),
    error: ""
  }
}

function instanceState(instance) {
  if (!instance || instance.reachable !== true) return "Unreachable"
  if (instance.daemon && instance.daemon.running === true) return "Daemon running"
  return "Daemon stopped"
}

function instanceDetail(instance) {
  if (!instance) return ""
  var tasks = Array.isArray(instance.tasks) ? instance.tasks.length : 0
  if (instance.tasks_available === true)
    return tasks === 1 ? "1 running task" : tasks + " running tasks"
  if (instance.task_error) return String(instance.task_error)
  return "Task access not configured"
}

function tooltip(status, refreshing) {
  if (refreshing) return "Hive · refreshing…"
  if (!status || status.configured === 0) return "Hive · no instances configured"
  if (!status.ok) return "Hive · " + status.error

  var hiveWord = status.configured === 1 ? "Hive" : "Hives"
  var taskWord = status.runningTaskCount === 1 ? "task" : "tasks"
  return status.daemonRunning + "/" + status.configured + " " + hiveWord + " running · " +
    status.runningTaskCount + " active " + taskWord + "\nLeft: details · Middle: refresh"
}

if (typeof module !== "undefined") {
  module.exports = {
    emptyStatus: emptyStatus,
    parseStatus: parseStatus,
    instanceState: instanceState,
    instanceDetail: instanceDetail,
    tooltip: tooltip
  }
}
