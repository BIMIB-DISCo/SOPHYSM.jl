import QtQuick
import QtQuick.Controls

CheckBox {
    id: root

    // 🔤 TESTO
    contentItem: Text {
        text: root.text
        color: root.enabled ? "#FFFFFF" : "#777777"
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator.width + 8
        font.pixelSize: 13
    }

    // ☑️ BOX
    indicator: Rectangle {
        implicitWidth: 18
        implicitHeight: 18
        radius: 4
        border.width: 1
        border.color: root.checked ? "#FF6600" : "#777"
        color: root.checked ? "#FF6600" : "transparent"

        // ✔ TICK
        Canvas {
            anchors.fill: parent
            visible: root.checked

            onPaint: {
                var ctx = getContext("2d")
                ctx.strokeStyle = "#1E1E1E"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(width*0.2, height*0.55)
                ctx.lineTo(width*0.45, height*0.75)
                ctx.lineTo(width*0.8, height*0.25)
                ctx.stroke()
            }
        }
    }
}