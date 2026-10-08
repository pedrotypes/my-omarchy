import QtQuick
import Quickshell.Io

// Three tiny vertical meters (CPU, GPU, memory) fed by ../scripts/sysmeter.
Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  property int cpu: 0
  property int gpu: 0
  property int mem: 0
  readonly property color fg: bar ? bar.foreground : "white"
  readonly property color hot: bar ? bar.urgent : "red"

  implicitWidth: row.implicitWidth + 12
  implicitHeight: bar ? bar.barSize : 26

  Process {
    id: sampler
    running: true
    command: [Qt.resolvedUrl("../scripts/sysmeter").toString().replace("file://", ""), "2"]
    stdout: SplitParser {
      onRead: function(line) {
        const parts = line.trim().split(" ")
        if (parts.length === 3) {
          root.cpu = parseInt(parts[0])
          root.gpu = parseInt(parts[1])
          root.mem = parseInt(parts[2])
        }
      }
    }
    onExited: restart.start()
  }

  Timer { id: restart; interval: 5000; onTriggered: sampler.running = true }

  component Meter: Row {
    property string label
    property int value
    spacing: 3

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: parent.label
      color: root.fg
      opacity: 0.7
      font.family: root.bar ? root.bar.fontFamily : "monospace"
      font.pixelSize: 10
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 5
      height: 14
      radius: 1
      color: "transparent"
      border.color: root.fg
      border.width: 1
      opacity: 0.9

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: Math.max(0, (parent.height - 2) * parent.parent.value / 100)
        color: parent.parent.value >= 85 ? root.hot : root.fg
        Behavior on height { NumberAnimation { duration: 300 } }
      }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 8
    Meter { label: "C"; value: root.cpu }
    Meter { label: "G"; value: root.gpu }
    Meter { label: "M"; value: root.mem }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: if (root.bar) root.bar.showTooltip(root, "CPU " + root.cpu + "%  \u00b7  GPU " + root.gpu + "%  \u00b7  Memory " + root.mem + "%")
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
  }
}
