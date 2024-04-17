import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import org.julialang

ApplicationWindow {
    width: 640
    height: 480
    minimumWidth: 640
    minimumHeight: 480
    visible: true    
    title: qsTr("SOPHYSM")
    id : mainWindow
    
    // tabBar
    TabBar {
        id: bar
        width: parent.width
        height: parent.height / 12        
        contentHeight: parent.height / 12

        TabButton {
            text: qsTr("Workspace")
            id: workspaceButton
            width: bar.width / 8
        }
        TabButton {
            text: qsTr("Segmentation")
            id: segmentationButton
            width: bar.width / 8
        }
        TabButton {
            text: qsTr("Tessellation")
            id: tessellationButton
            width: bar.width / 8
        }
        TabButton {
            text: qsTr("Simulation")
            id: simulationButton
            width: bar.width / 8
        }
    }

        // da destra
        // help button
        Button {
            id: helpButton

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Open GitHub documentation")

            icon.source: "img/help.png"
            width: bar.height / 1.5
            height: bar.height / 1.5
            y: bar.height / 6
            anchors {
                right: parent.right
                rightMargin: 10
            }
        }

        // settings button
        Button {
            id: settingsButton

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Open settings window")

            icon.source: "img/settings.png"
            onClicked: {
                testD.open()
            }
            width: bar.height / 1.5
            height: bar.height / 1.5
            y: bar.height / 6
            anchors {
                right: helpButton.left
                rightMargin: 10
            }
        }

        //stackLayout
        StackLayout {
            id: stackLayout
            width: parent.width
            height: parent.height * 11 / 12
            currentIndex: bar.currentIndex

            anchors {
                top: bar.bottom                
            }
            
            // workspace Item
            Item {
                id: workspaceTab
                width: parent.width
                height: parent.height                
                
                Rectangle {
                    id: folder
                    color: "lightgrey"
                    width: stackLayout.width / 4
                    height: stackLayout.height

                    Column {
                        Label {
                            text: "Current workspace:"
                            font.pixelSize: 16
                        }

                        Label {
                            text: workspaceName
                            font.pixelSize: 16
                        }
                    }
                }

                Rectangle {
                    id: viewer
                    width: stackLayout.width * 3 / 4
                    height: stackLayout.height

                    anchors.left: folder.right
                }

            }
            Item {
                id: segmentationTab
            }
            Item {
                id: tessellationTab
            }
            Item {
                id: simulationTab
            }
        }
    }