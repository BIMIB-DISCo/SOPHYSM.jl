import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
    id: root
    
    property string title: ""
    property string description: ""
    property int bottomMargin: 4
    
    Layout.fillWidth: true
    spacing: 10
    
    Label {
        text: root.title
        font.pixelSize: 24
        font.bold: true
        color: "#FFFFFF"
        Layout.fillWidth: true
        Layout.bottomMargin: root.bottomMargin
        visible: root.title !== ""
    }
    
    Label {
        text: root.description
        color: "#FFFFFF"
        Layout.fillWidth: true
        visible: root.description !== ""
    }
}
