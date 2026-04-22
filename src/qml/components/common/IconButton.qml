// file: qml/components/common/IconButton.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

Button {
    id: root
    property string source: ""
    property int size: 24
    property bool isDarkTheme: true
    property int buttonWidth: 0
    property int buttonHeight: 0
    
    // Dimensioni
    implicitWidth: buttonWidth > 0 ? buttonWidth : size + 16
    implicitHeight: buttonHeight > 0 ? buttonHeight : size + 16
    
    flat: true
    padding: 4
    
    // Icona
    contentItem: Image {
        source: root.source
        width: root.size
        height: root.size
        fillMode: Image.PreserveAspectFit
        opacity: root.enabled ? 1.0 : 0.4
        smooth: true
        asynchronous: true
    }
    
    // Background con feedback hover/press
    background: Rectangle {
        id: bg
        radius: 8
        color: "transparent"
        
        states: [
            State {
                when: root.hovered && root.enabled
                PropertyChanges { target: bg; color: isDarkTheme ? "#444444" : "#e0e0e0" }
            },
            State {
                when: root.pressed && root.enabled
                PropertyChanges { target: bg; color: isDarkTheme ? "#555555" : "#d0d0d0" }
            },
            State {
                when: !root.enabled
                PropertyChanges { target: root.contentItem; opacity: 0.3 }
            }
        ]
        
        transitions: Transition {
            ColorAnimation { duration: 150 }
        }
    }
    
    // Tooltip
    ToolTip.visible: hovered && root.toolTipText
    ToolTip.text: root.toolTipText
    ToolTip.delay: 500
    ToolTip.timeout: 3000
    
    // ✅ Cursor shape: usa MouseArea sovrapposto invece di cursorShape su Button
    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Passa gli eventi di click al Button sottostante
        onClicked: root.clicked()
        // Importante: non bloccare gli eventi hover del Button
        propagateComposedEvents: true
    }
}