import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import jlqml
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
    
    function open() {
        collectionSelector.updateHasSelections();
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
            NumberAnimation { 
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200 
            }
            NumberAnimation { 
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 200 
            }
        }
        
        exit: Transition {
            NumberAnimation { 
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 150 
            }
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
            
            Common.DialogHeader {
                title: "Download TCGA Collections"
                description: "Select the collections you want to download:"
            }
            
            Common.CollectionSelector {
                id: collectionSelector
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: tcgaCollections
                onSelectionChanged: {
                    root.hasSelections = collectionSelector.hasSelections
                }
            }
            
            Label {
                text: "Note: Downloads may take a long time depending on the " +
                      "collection size and your internet connection."
                color: "#F1C40F"
                font.italic: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                Layout.topMargin: 5
            }
            
            Common.DialogFooter {
                Layout.topMargin: 5
                primaryText: "Download"
                secondaryText: "Cancel"
                primaryEnabled: root.hasSelections
                primaryHighlighted: root.hasSelections
                
                onPrimaryClicked: {
                    downloadPopup.close()
                    root.downloadRequested(
                        collectionSelector.getSelectedItems(), 
                        root.workspaceDir
                    )
                }
                
                onSecondaryClicked: {
                    downloadPopup.close()
                    root.downloadCanceled()
                }
            }
        }
    }
}