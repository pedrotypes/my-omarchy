import QtQuick

// herdr's sidebar status dot: filled for blocked/done (optionally with a count
// inside), a hollow ring when there is nothing to count.
Rectangle {
  id: dot
  property color dotColor
  property int count: 0
  property bool showCount: true
  property real size: 16
  property color textColor: "#282828"
  property string fontFamily: "monospace"

  width: size
  height: size
  radius: size / 2
  color: count > 0 ? dotColor : "transparent"
  border.width: count > 0 ? 0 : Math.max(1.5, size / 10)
  border.color: dotColor

  Text {
    anchors.centerIn: parent
    visible: dot.showCount && dot.count > 0
    text: dot.count > 99 ? "99" : String(dot.count)
    color: dot.textColor
    font.family: dot.fontFamily
    font.pixelSize: Math.round(dot.size * (dot.count > 9 ? 0.55 : 0.7))
    font.bold: true
  }
}
