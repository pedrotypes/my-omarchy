import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// The bar panel's list, centered and at the Omarchy menu's size (the same
// surface, row, and font tokens as the keybindings screen). Up/Down or j/k
// move, Enter jumps to the agent's pane, Esc or a click outside closes.
// Summon with: omarchy-shell shell toggle gil.herdr
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int cursor: 0

  property var service: null
  readonly property var agents: service ? service.agents : []
  readonly property var errors: service ? service.errors : []

  // The [menu] surface tokens, like omarchy.menu and omarchy.emojis.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  property var selectedBorderSpec: Border.surfaceSpec("menu", "selected-border", Color.menu.selectedBorder, 0)
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int rowHeight: Math.max(Style.space(58), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)
  property int rowSpacing: Style.space(2)
  property int cardWidth: Math.min(Style.space(800), panel.width - Style.gapsOut * 2)
  readonly property int listHeight: agents.length === 0 ? rowHeight
    : agents.length * rowHeight + (agents.length - 1) * rowSpacing
  readonly property int errorsHeight: errorColumn.visible ? errorColumn.implicitHeight + contentSpacing : 0
  property int cardHeight: Math.min(contentMargin * 2 + headerHeight + contentSpacing + listHeight + errorsHeight,
                                    Math.round(panel.height * 0.8))

  function lookupService() {
    if (!service && shell && typeof shell.serviceFor === "function") service = shell.serviceFor("gil.herdr")
  }

  function open(payloadJson) {
    lookupService()
    cursor = 0
    opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { opened = false }

  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function") shell.hide((manifest && manifest.id) || "gil.herdr")
  }

  function toggle() { opened ? dismiss() : open("{}") }

  function move(delta) {
    if (agents.length === 0) return
    cursor = Math.max(0, Math.min(agents.length - 1, cursor + delta))
    list.positionViewAtIndex(cursor, ListView.Contain)
  }

  function activate(index) {
    var agent = agents[index]
    if (!agent || !service) return
    dismiss()
    service.jump(agent)
  }

  onAgentsChanged: if (cursor >= agents.length) cursor = Math.max(0, agents.length - 1)

  Timer {
    interval: 200
    repeat: true
    running: root.service === null
    onTriggered: root.lookupService()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "gil-herdr"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismiss()
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            root.move(-1)
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            root.move(1)
          } else if (event.key === Qt.Key_Home || event.key === Qt.Key_G && !(event.modifiers & Qt.ShiftModifier)) {
            root.move(-root.agents.length)
          } else if (event.key === Qt.Key_End || event.key === Qt.Key_G) {
            root.move(root.agents.length)
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activate(root.cursor)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: hint.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Herdr agents needing attention"
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: hint
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "j/k  enter  esc"
            color: root.foreground
            opacity: 0.4
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Item {
          width: parent.width
          height: Math.max(0, parent.height - root.headerHeight - root.contentSpacing - root.errorsHeight)

          Text {
            visible: root.agents.length === 0
            anchors.left: parent.left
            anchors.leftMargin: Style.space(18)
            height: root.rowHeight
            verticalAlignment: Text.AlignVCenter
            text: "Nothing is blocked or done."
            color: root.foreground
            opacity: 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
          }

          ListView {
            id: list
            anchors.fill: parent
            model: root.agents
            clip: true
            spacing: root.rowSpacing
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.cursor

            delegate: BorderSurface {
              id: row
              required property var modelData
              required property int index
              readonly property bool hasCursor: row.index === root.cursor

              width: ListView.view.width
              height: root.rowHeight
              radius: root.cornerRadius
              color: row.hasCursor ? root.selectedBackground : "transparent"
              borderSpec: row.hasCursor ? root.selectedBorderSpec : Border.none()

              Item {
                id: dotSlot
                width: Style.space(36)
                height: parent.height
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)

                Dot {
                  anchors.centerIn: parent
                  size: Math.round(Style.font.heading * 0.7)
                  count: 1
                  showCount: false
                  dotColor: root.service ? root.service.statusColor(row.modelData.status) : root.foreground
                }
              }

              Column {
                anchors.left: dotSlot.right
                anchors.leftMargin: Style.space(6)
                anchors.right: statusText.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: row.modelData.title
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.heading
                  font.weight: Font.Medium
                  elide: Text.ElideRight
                }

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: root.service ? root.service.location(row.modelData) : ""
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: 0.52
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              Text {
                id: statusText
                textFormat: Text.PlainText
                anchors.right: parent.right
                anchors.rightMargin: Style.space(16)
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.status
                color: root.service ? root.service.statusColor(row.modelData.status) : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.cursor = row.index
                onClicked: root.activate(row.index)
              }
            }
          }
        }

        Column {
          id: errorColumn
          visible: root.errors.length > 0
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: root.errors
            Text {
              required property var modelData
              width: parent.width
              text: modelData
              wrapMode: Text.Wrap
              color: root.service ? root.service.blockedColor : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
