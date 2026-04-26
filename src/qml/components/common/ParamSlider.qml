// Common/ParamSlider.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property int decimals: 2

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Label {
            text: root.label
            color: "#DDD"
            Layout.fillWidth: true
            Layout.minimumWidth: 100
            Layout.preferredWidth: 200
            elide: Text.ElideRight
        }

        TextField {
            text: Number(root.value).toFixed(root.decimals)
            Layout.preferredWidth: parent.width * 0.15
            Layout.minimumWidth: 60
            Layout.maximumWidth: 100
            onEditingFinished: {
                var v = parseFloat(text)
                if (!isNaN(v)) root.value = v
            }
        }
    }

    Slider {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        from: root.from
        to: root.to
        value: root.value

        onMoved: root.value = value
    }
}