import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Notification history button. Left-click replays the recent notifications
// as toasts (`omarchy-shell notifications showHistory`); clicking again while
// they are up dismisses them all. Right-click always dismisses. Plugins can't
// see the toast stack, so "up" is tracked here: it ends after a dismiss or
// once the replayed toasts have had time to expire.
BarWidget {
  id: root
  moduleName: "gil.notification-history"

  // Normal toasts last 8 s (the notification service's normalPopupDuration).
  readonly property int replayLifetime: 8000
  property bool shown: false

  function run(action) {
    proc.command = ["omarchy-shell", "notifications", action]
    proc.running = true
  }

  function showHistory() {
    run("showHistory")
    shown = true
    lifetime.restart()
  }

  function dismiss() {
    run("dismissAll")
    shown = false
    lifetime.stop()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process { id: proc }

  Timer {
    id: lifetime
    interval: root.replayLifetime
    onTriggered: root.shown = false
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.shown
    // nf-md-bell_outline
    text: String.fromCodePoint(0xF009C)
    tooltipText: root.shown ? "Hide notifications" : "Show recent notifications"
    onPressed: function(b) {
      if (b === Qt.RightButton || root.shown) root.dismiss()
      else root.showHistory()
    }
  }
}
