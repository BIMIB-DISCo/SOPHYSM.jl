import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Universal 2.15
import QtQuick.Dialogs

import org.julialang
import "../models" as Models

Item {
    id: root
    
    // Properties
    property string workspaceDir: ""
    
    // Reference to the collections model
    property alias collectionsModel: tcgaCollections
    
    // Models
    Models.TCGACollectionsModel {
        id: tcgaCollections
    }
    
    // Signals
    signal downloadRequested(var collections, string targetDir)
    signal downloadCanceled()
    
    // Public methods
    function open() {
        downloadPopup.open()
    }
    
    function close() {
        downloadPopup.close()
    }
    
    // Message dialog for confirmation
    MessageDialog {
        id: downloadMessageDialog
        title: "Confirm Download"
        text: "Download the selected collections on " + root.workspaceDir + "?"
        informativeText: "Download may take several time, continue anyway?"
        buttons: MessageDialog.Yes | MessageDialog.Cancel
        onButtonClicked: function (button, role) {
            switch (button) {
            case MessageDialog.Yes:
                var collectionsToDownload = []
                // Iterate Collections selected
                for (var i = 0; i < checkBoxColumn.children.length; i++) {
                    var child = checkBoxColumn.children[i]
                    if (child instanceof CheckBox && child.checked) {
                        collectionsToDownload.push(child.objectName)
                    }
                }
                downloadPopup.close()
                root.downloadRequested(collectionsToDownload, root.workspaceDir)
                this.close()
                break;
            case MessageDialog.Cancel:
                downloadPopup.close()
                root.downloadCanceled()
                this.close()
            }
        }
    }

    // Popup window for downloading histopathology collection from TCGA
    Popup {
        id: downloadPopup
        padding: 20
        width: 900
        height: 500
        
        // Centrare il popup nella finestra
        anchors.centerIn: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 200 }
        }
        
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
        }
        
        // Aggiungere un effetto visuale al popup
        background: Rectangle {
            color: "#1E1E1E"  // Grigio molto scuro invece di nero
            radius: 10
            border.color: "#333333"  // Grigio scuro invece di bianco
            border.width: 1
        }
    
        // Layout complessivo
        ColumnLayout {
            anchors.fill: parent
            spacing: 15
            
            // Titolo
            Label {
                text: "Download TCGA Collections"
                font.pixelSize: 20
                font.bold: true
                Layout.fillWidth: true
                Layout.bottomMargin: 5
            }
            
            // Descrizione
            Label {
                text: "Select the collections you want to download:"
                Layout.fillWidth: true
            }
            
            // Row for selection actions
            RowLayout {
                Layout.fillWidth: true
                
                Button {
                    text: "Select All"
                    background: Rectangle {
                        implicitWidth: 100
                        implicitHeight: 40
                        color: parent.down ? "#353535" : (parent.hovered ? "#454545" : "#252525")
                        radius: 5
                        border.color: "#333333"
                        border.width: 1
                    }
                    onClicked: {
                        for (var i = 0; i < checkBoxColumn.children.length; i++) {
                            var child = checkBoxColumn.children[i];
                            if (child instanceof CheckBox) {
                                child.checked = true;
                            }
                        }
                    }
                }
                
                Button {
                    text: "Deselect All"
                    background: Rectangle {
                        implicitWidth: 100
                        implicitHeight: 40
                        color: parent.down ? "#353535" : (parent.hovered ? "#454545" : "#252525")
                        radius: 5
                        border.color: "#333333"
                        border.width: 1
                    }
                    onClicked: {
                        for (var i = 0; i < checkBoxColumn.children.length; i++) {
                            var child = checkBoxColumn.children[i];
                            if (child instanceof CheckBox) {
                                child.checked = false;
                            }
                        }
                    }
                }
                
                Item { Layout.fillWidth: true } // Spacer
            }
            
            // Contenitore con bordo per la scrollview
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                border.width: 1
                border.color: "#2D2D2D"  // Grigio scuro invece di blu
                radius: 5
                
                ScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
            
                    Column {
                        id: checkBoxColumn
                        width: scrollView.width - 30
                        spacing: 8
                        
                        // Generate checkboxes dynamically from model
                        Repeater {
                            model: tcgaCollections
                            
                            CheckBox {
                                objectName: model.code
                                text: ""
                                width: parent.width
                                
                                contentItem: Row {
                                    spacing: 4
                                    leftPadding: 28
                                    
                                    Text {
                                        text: "TCGA-" + model.code.toUpperCase() + " = "
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    Text {
                                        text: model.description
                                        color: "#AAAAAA"
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                                
                                indicator: Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    x: parent.leftPadding
                                    y: parent.height / 2 - height / 2
                                    radius: 10
                                    border.color: parent.checked ? "#FF6600" : "#555555"
                                    border.width: 1
                                    color: "transparent"
                                    
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        anchors.centerIn: parent
                                        radius: 5
                                        color: parent.parent.checked ? "#FF6600" : "transparent"
                                        visible: parent.parent.checked
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Pulsanti fissi in basso
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 5
                spacing: 15
                
                Item { Layout.fillWidth: true } // Spacer
                
                Button {
                    id: closePopupButton
                    text: "Cancel"
                    implicitWidth: 120
                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 40
                        color: parent.down ? "#353535" : (parent.hovered ? "#454545" : "#252525")
                        radius: 5
                        border.color: "#333333"
                        border.width: 1
                    }
                    onClicked: downloadPopup.close()
                }
                
                Button {
                    id: downloadCollectionsButton
                    text: "Download"
                    implicitWidth: 120
                    highlighted: true
                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 40
                        color: parent.down ? "#A05000" : (parent.hovered ? "#FF7D1A" : "#FF6600")
                        radius: 5
                        border.color: "#FF6600"
                        border.width: 1
                    }
                    onClicked: downloadMessageDialog.open()
                }
            }
        }
    }
}