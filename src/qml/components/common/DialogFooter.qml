import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../common" as Common

RowLayout {
    id: root
    
    property bool primaryEnabled: true
    property bool primaryHighlighted: true
    property string primaryText: "OK"
    property string secondaryText: "Cancel"
    
    signal primaryClicked()
    signal secondaryClicked()
    
    Layout.fillWidth: true
    spacing: 15
    
    Item { Layout.fillWidth: true }
    
    Common.Button {
        text: root.secondaryText
        onClicked: root.secondaryClicked()
    }
    
    Common.Button {
        text: root.primaryText
        isHighlighted: root.primaryHighlighted
        enabled: root.primaryEnabled
        onClicked: root.primaryClicked()
    }
}
