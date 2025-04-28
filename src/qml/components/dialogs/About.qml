import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import Qt.labs.platform

import org.julialang
import "../common" as Common

Item {
    id: root
    
    property string githubUrl: "https://github.com/BIMIB-DISCo/SOPHYSM.jl"
    
    function open() {
        aboutPopup.open();
    }
    
    function close() {
        aboutPopup.close();
    }
    
    Popup {
        id: aboutPopup
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
            
            Common.DialogHeader {
                title: "About SOPHYSM"
                description: "Software for Spatial Phylogenetic Modeling of Solid Tumors"
            }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                Layout.margins: 10
                spacing: 20
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#777777"
                    radius: 5
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#777777"
                    radius: 5
                }
            }
            
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                TextArea {
                    id: aboutText
                    text: "SOPHYSM is software for spatial phylogenetic modeling of solid tumors. It features:\n\n• Image processing for histological slide segmentation\n• Extraction of spatial and morphological information\n• Simulation of cellular spatial dynamics\n• Phylogenetic tree modeling\n• Molecular evolution simulation with various models\n• Support for insertions and deletions (indels)"
                    wrapMode: Text.WordWrap
                    readOnly: true
                    color: "#FFFFFF"
                    textFormat: TextEdit.PlainText
                    background: null
                    
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                
                Item { Layout.fillWidth: true }
                
                Common.Button {
                    text: "Close"
                    onClicked: {
                        aboutPopup.close()
                    }
                }
                
                Common.Button {
                    text: "GitHub"
                    isHighlighted: true
                    onClicked: {
                        Qt.openUrlExternally(root.githubUrl)
                    }
                }
            }
        }
    }
}
