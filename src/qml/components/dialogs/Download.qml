import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import org.julialang
import "../models" as Models
import "../common" as Common

Item {
    id: root
    
    property string workspaceDir: ""
    property alias collectionsModel: tcgaCollections
    property bool hasSelections: false
    
    Models.TCGACollectionsModel {
        id: tcgaCollections
    }
    
    signal downloadRequested(var collections, string targetDir)
    signal downloadCanceled()
    
    function setAllCheckboxes(checked) {
        for (var i = 0; i < checkBoxColumn.children.length; i++) {
            var child = checkBoxColumn.children[i];
            if (child instanceof Common.CheckBox) {
                child.checked = checked;
            }
        }
        updateHasSelections();
    }
    
    function updateHasSelections() {
        for (var i = 0; i < checkBoxColumn.children.length; i++) {
            var child = checkBoxColumn.children[i];
            if (child instanceof Common.CheckBox && child.checked) {
                root.hasSelections = true;
                return;
            }
        }
        root.hasSelections = false;
    }
    
    function open() {
        updateHasSelections();
        downloadPopup.open();
    }
    
    function close() {
        downloadPopup.close();
    }
    
    Popup {
        id: downloadPopup
        padding: 20
        width: 900
        height: 500
        
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
        
        background: Rectangle {
            color: "#1E1E1E"
            radius: 10
            border.color: "#333333"
            border.width: 1
        }
    
        ColumnLayout {
            anchors.fill: parent
            spacing: 16
            
            Label {
                text: "Download TCGA Collections"
                font.pixelSize: 24
                font.bold: true
                color: "#FFFFFF"
                Layout.fillWidth: true
                Layout.bottomMargin: 4
            }
            
            Label {
                text: "Select the collections you want to download:"
                color: "#FFFFFF"
                Layout.fillWidth: true
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Common.Button {
                    text: "Select All"
                    buttonWidth: 100
                    onClicked: setAllCheckboxes(true)
                }
                
                Common.Button {
                    text: "Deselect All"
                    buttonWidth: 100
                    onClicked: setAllCheckboxes(false)
                }
                
                Item { Layout.fillWidth: true }
            }
            
            // Collection selection area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                border.width: 1
                border.color: "#2D2D2D" 
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
                        
                        Repeater {
                            model: tcgaCollections
                            
                            Common.CheckBox {
                                objectName: model.code
                                text: ""
                                width: parent.width
                                
                                onCheckedChanged: {
                                    updateHasSelections();
                                }
                                
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
                            }
                        }
                    }
                }
            }
            
            Label {
                text: "Note: Downloads may take a long time depending on the collection size and your internet connection."
                color: "#F1C40F"
                font.italic: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                Layout.topMargin: 5
            }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 5
                spacing: 15
                
                Item { Layout.fillWidth: true }
                
                Common.Button {
                    id: closePopupButton
                    text: "Cancel"
                    onClicked: {
                        downloadPopup.close()
                        root.downloadCanceled()
                    }
                }
                
                Common.Button {
                    id: downloadCollectionsButton
                    text: "Download"
                    isHighlighted: root.hasSelections
                    enabled: root.hasSelections
                    onClicked: {
                        var collectionsToDownload = []
                        for (var i = 0; i < checkBoxColumn.children.length; i++) {
                            var child = checkBoxColumn.children[i]
                            if (child instanceof Common.CheckBox && child.checked) {
                                collectionsToDownload.push(child.objectName)
                            }
                        }
                        downloadPopup.close()
                        root.downloadRequested(collectionsToDownload, root.workspaceDir)
                    }
                }
            }
        }
    }
}