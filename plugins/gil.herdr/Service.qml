import QtQuick
import Quickshell
import Quickshell.Io

// One herdr-attention watcher for the whole plugin; the bar widget and the
// overlay both read agents/errors from here and jump through it.
Item {
  id: root

  property var shell: null
  property var manifest: null

  // herdr's gruvbox palette (src/app/state.rs) and its status_color mapping
  // (src/client/shell.rs): blocked = red, done = teal.
  readonly property color blockedColor: "#fb4934"
  readonly property color doneColor: "#8ec07c"
  readonly property color dotText: "#282828"

  readonly property string script: Qt.resolvedUrl("herdr-attention").toString().replace("file://", "")
  property var agents: []
  property var errors: []
  readonly property int blockedCount: agents.filter(a => a.status === "blocked").length

  function statusColor(status) { return status === "blocked" ? blockedColor : doneColor }

  function location(agent) {
    var parts = [agent.hostLabel]
    if (agent.workspace) parts.push(agent.workspace)
    if (agent.tab) parts.push(agent.tab)
    return parts.join(" / ")
  }

  function jump(agent) {
    if (agent) Quickshell.execDetached([script, "focus", agent.host, agent.pane])
  }

  Process {
    id: watcher
    running: true
    command: [root.script, "watch"]
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var data = JSON.parse(line)
          root.agents = data.agents || []
          root.errors = data.errors || []
        } catch (e) {}
      }
    }
    onExited: restart.start()
  }

  Timer { id: restart; interval: 5000; onTriggered: watcher.running = true }
}
