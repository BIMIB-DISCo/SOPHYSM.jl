// Common/StyledTextField.qml
import QtQuick
import QtQuick.Controls

TextField {
    id: control

    property color accent: "#FF8C42"

    color: "#FFFFFF"
    selectionColor: accent
    selectedTextColor: "#000"

    font.pixelSize: 13
    horizontalAlignment: TextInput.AlignHCenter

    background: Rectangle {
        radius: 5
        border.width: 1
        border.color: control.activeFocus ? control.accent : "#555"
        color: "#2b2b2b"

        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}