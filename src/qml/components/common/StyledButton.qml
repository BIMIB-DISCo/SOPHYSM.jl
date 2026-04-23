// Common/StyledButton.qml
import QtQuick
import QtQuick.Controls

Button {
    id: control

    property color accent: "#FF8C42"
    property bool isPrimary: false

    implicitHeight: 34
    implicitWidth: 100

    contentItem: Text {
        text: control.text
        color: control.isPrimary ? "#000" : "#FFF"
        font.bold: control.isPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 6

        color: control.isPrimary
            ? control.accent
            : (control.hovered ? "#3a3a3a" : "#2a2a2a")

        border.color: control.isPrimary ? control.accent : "#444"

        Behavior on color { ColorAnimation { duration: 120 } }
    }
}