import QtQuick
import QtQuick.Controls

Button {
    id: root
    
    property bool isHighlighted: false
    property int buttonWidth: 120
    property int buttonHeight: 40
    
    implicitWidth: buttonWidth
    implicitHeight: buttonHeight
    
    contentItem: Text {
        text: root.text
        font: root.font
        color: root.enabled ? "#FFFFFF" : "#888888"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    
    background: Rectangle {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        color: {
            if (!root.enabled) {
                return "#202020"
            } else if (root.isHighlighted) {
                return root.down ? "#A05000" : (root.hovered ? "#FF7D1A" : "#FF6600")
            } else {
                return root.down ? "#353535" : (root.hovered ? "#454545" : "#252525")
            }
        }
        radius: 5
        border.color: {
            if (!root.enabled) {
                return "#444444"
            } else if (root.isHighlighted) {
                return "#FF6600"
            } else {
                return "#333333"
            }
        }
        border.width: 1
        opacity: root.enabled ? 1.0 : 0.7
    }
}
