import QtQuick
import QtQuick.Controls

CheckBox {
    id: root
    
    indicator: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        x: root.leftPadding
        y: root.height / 2 - height / 2
        radius: 10
        border.color: root.checked ? "#FF6600" : "#555555"
        border.width: 1
        color: "transparent"
        
        Rectangle {
            width: 10
            height: 10
            anchors.centerIn: parent
            radius: 5
            color: parent.parent.checked ? 
                   "#FF6600" : "transparent"
            visible: parent.parent.checked
        }
    }
}
