// file: qml/components/common/Button.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic

Button {
    id: root
    
    // ================= PROPRIETÀ PERSONALIZZATE (per compatibilità) =================
    property bool isHighlighted: false
    property bool isDarkTheme: true
    property int buttonWidth: 100      // ✅ Aggiunto: larghezza personalizzata
    property int buttonHeight: 36      // ✅ Aggiunto: altezza personalizzata
    property string buttonTextColor: "" // ✅ Opzionale: colore testo personalizzato
    
    // ================= DIMENSIONI =================
    implicitWidth: buttonWidth > 0 ? buttonWidth : 100
    implicitHeight: buttonHeight > 0 ? buttonHeight : 36
    
    // ================= STILE BASE =================
    flat: false
    padding: 8
    
    // ================= TESTO =================
    contentItem: Text {
        text: root.text
        font: root.font
        opacity: enabled ? 1.0 : 0.3
        color: {
            if (root.buttonTextColor !== "") return root.buttonTextColor
            if (root.isHighlighted) return "#FFFFFF"
            if (root.isDarkTheme) return "#FFFFFF"
            return "#333333"
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    
    // ================= SFONDO =================
    background: Rectangle {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        color: {
            if (root.isHighlighted) return "#FF8C42"  // Arancione per step attivo
            if (root.pressed) return isDarkTheme ? "#555555" : "#cccccc"
            if (root.hovered) return isDarkTheme ? "#444444" : "#e0e0e0"
            return isDarkTheme ? "#333333" : "#ffffff"
        }
        border.color: {
            if (root.isHighlighted) return "#FF6B2B"
            return isDarkTheme ? "#555555" : "#cccccc"
        }
        border.width: 1
        radius: 6
        
        // Animazione fluida
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }
}