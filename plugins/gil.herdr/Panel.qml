import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// herdr agents that need attention. The bar shows herdr's sidebar dot (red =
// blocked, teal = done) with the count inside; the panel lists the agents and
// a click jumps to the agent's pane in the terminal attached to its herdr
// server, local or `herdr --remote`. Data and focusing live in herdr-attention.
Panel {
  id: root
  moduleName: "gil.herdr"
  ipcTarget: "gil.herdr"

  // herdr's gruvbox palette (src/app/state.rs) and its status_color mapping
  // (src/client/shell.rs): blocked = red, done = teal. With nothing to show
  // the ring takes the bar's foreground, like the other bar icons.
  readonly property color blockedColor: "#fb4934"
  readonly property color doneColor: "#8ec07c"
  readonly property color dotText: "#282828"

  readonly property string script: Qt.resolvedUrl("herdr-attention").toString().replace("file://", "")
  property var agents: []
  property var errors: []
  property int cursor: -1
  readonly property int blockedCount: agents.filter(a => a.status === "blocked").length

  function statusColor(status) { return status === "blocked" ? blockedColor : doneColor }

  function jump(agent) {
    if (!agent) return
    Quickshell.execDetached([script, "focus", agent.host, agent.pane])
    close()
  }

  function location(agent) {
    var parts = [agent.hostLabel]
    if (agent.workspace) parts.push(agent.workspace)
    if (agent.tab) parts.push(agent.tab)
    return parts.join(" / ")
  }

  onOpenedChanged: if (opened) cursor = agents.length > 0 ? 0 : -1
  onAgentsChanged: if (cursor >= agents.length) cursor = agents.length - 1

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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

  // herdr's dot: filled for blocked/done, a hollow ring when nothing needs attention.
  component Dot: Rectangle {
    property color dotColor
    property int count: 0
    property bool showCount: true
    property real size: 16
    width: size
    height: size
    radius: size / 2
    color: count > 0 ? dotColor : "transparent"
    border.width: count > 0 ? 0 : 1.5
    border.color: dotColor

    Text {
      anchors.centerIn: parent
      visible: parent.showCount && parent.count > 0
      text: parent.count > 99 ? "99" : String(parent.count)
      color: root.dotText
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Math.round(parent.size * (parent.count > 9 ? 0.55 : 0.7))
      font.bold: true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    useActiveColor: false
    tooltipText: root.agents.length === 0 ? "No herdr agents need attention"
      : root.agents.length + " herdr agent" + (root.agents.length === 1 ? "" : "s") + " need attention"
        + (root.blockedCount > 0 ? " (" + root.blockedCount + " blocked)" : "")
    iconComponent: Component {
      Item {
        Dot {
          anchors.centerIn: parent
          count: root.agents.length
          dotColor: root.agents.length === 0 ? root.barForeground
            : (root.blockedCount > 0 ? root.blockedColor : root.doneColor)
        }
      }
    }
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (root.agents.length === 0 || dy === 0) return
        root.cursor = Math.max(0, Math.min(root.agents.length - 1, root.cursor + dy))
      }
      onActivateRequested: root.jump(root.agents[root.cursor])
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        PanelSectionHeader {
          text: "HERDR AGENTS NEEDING ATTENTION"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Text {
          visible: root.agents.length === 0
          text: "Nothing is blocked or done."
          color: root.bar.foreground
          opacity: 0.6
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Column {
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: root.agents

            Rectangle {
              id: row
              required property var modelData
              required property int index
              readonly property bool current: root.cursor === index
              width: parent.width
              implicitHeight: rowContent.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: current ? Style.hoverFill : "transparent"

              Row {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(10)

                Dot {
                  anchors.verticalCenter: parent.verticalCenter
                  size: 10
                  count: 1
                  showCount: false
                  dotColor: root.statusColor(row.modelData.status)
                }

                Column {
                  width: parent.width - parent.spacing * 2 - 10 - statusText.implicitWidth
                  spacing: Style.space(1)

                  Text {
                    width: parent.width
                    text: row.modelData.title
                    elide: Text.ElideRight
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    text: root.location(row.modelData)
                    elide: Text.ElideRight
                    color: root.bar.foreground
                    opacity: 0.6
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Text {
                  id: statusText
                  anchors.verticalCenter: parent.verticalCenter
                  text: row.modelData.status
                  color: root.statusColor(row.modelData.status)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.cursor = row.index
                onClicked: root.jump(row.modelData)
              }
            }
          }
        }

        Repeater {
          model: root.errors
          Text {
            required property var modelData
            width: parent.width
            text: modelData
            wrapMode: Text.Wrap
            color: root.blockedColor
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
