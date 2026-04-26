// Common/ParamCard.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "." as Common

Rectangle {
    id: card
    property string title: ""
    property string description: ""

    radius: 8
    color: "#252525"
    border.color: "#3a3a3a"
    
    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + 20
    Layout.preferredWidth: layout.implicitWidth + 20

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6


        Label {
            text: card.title
            color: "#FFFFFF"
            font.bold: true
        }

        Label {
            text: card.description
            color: "#AAAAAA"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            visible: description !== ""
        }

        Item { height: 6 }

        ColumnLayout {
            id: contentArea
            Layout.fillWidth: true
        }
    }

    default property alias content: contentArea.data
}