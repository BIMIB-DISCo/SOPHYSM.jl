// file: qml/components/common/IconButton.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

Button {
    id: root

    property string source: ""
    property int size: 24
    property bool isDarkTheme: true

    implicitWidth: size + 16
    implicitHeight: size + 16

    flat: true

    contentItem: Image {
        source: root.source
        width: root.size
        height: root.size
        fillMode: Image.PreserveAspectFit
        opacity: root.enabled ? 1.0 : 0.4
        smooth: true
        asynchronous: true
    }

    background: Rectangle {
        radius: 8
        color: root.hovered ? (root.isDarkTheme ? "#444" : "#e0e0e0") : "transparent"

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }
}