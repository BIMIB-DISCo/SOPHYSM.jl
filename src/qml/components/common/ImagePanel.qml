// file: qml/components/common/ImagePanel.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root    
    property string title: ""
    property alias imageItem: imageDisplay
    property bool isDarkTheme: true
    property var onExpand: null
    
    color: isDarkTheme ? "#1e1e1e" : "#fff"
    border.color: isDarkTheme ? "#333" : "#ddd"
    border.width: 1
    radius: 6
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4
        
        Label {
            text: title
            font.bold: true
            font.pixelSize: 12
            color: isDarkTheme ? "#ccc" : "#555"
        }
        
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: isDarkTheme ? "#2a2a2a" : "#f9f9f9"
            border.color: isDarkTheme ? "#444" : "#eee"
            border.width: 1
            radius: 4
            clip: true
            
            Image {
                id: imageDisplay
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (imageDisplay.source.toString() !== "" && onExpand) {
                        onExpand(imageDisplay.source, title)  // ← Chiama la funzione del padre
                    }
                }
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}