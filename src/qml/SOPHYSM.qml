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

    FolderDialog {
        id: folderDialog
        title: "Please choose your new Workspace Folder"
        onAccepted: {
            console.log("User has selected " + folderDialog.selectedFolder);
            // Parsing the selectedFolder with "file:///" removed
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(8);
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    Menu {
        id: dropdownMenu
        width: 100

        MenuItem {
            text: "Change Directory"
            onClicked: folderDialog.open()
        }

        MenuItem {
            text: "test"
            onClicked: {
                console.log("test onClicked"),
                Julia.test("test")
            }

        }

        MenuItem {
            text: "Item 3"
            onClicked: console.log("Item 3 selected")
        }
    }

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

            onClicked: Qt.openUrlExternally("https://github.com/BIMIB-DISCo/SOPHYSM.jl/tree/development")

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
            ToolTip.text: qsTr("Settings")

            onClicked: dropdownMenu.popup()

            icon.source: "img/settings.png"

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
            SplitView {
                id: splitView
                width: parent.width
                height: parent.height

                // handle to resize the window
                handle: Rectangle {
                    id: handleDelegate
                    implicitWidth: 2
                    color: SplitHandle.pressed ? "black"
                        : (SplitHandle.hovered ? Qt.lighter("grey", 1.1) : "grey")
                }

                // folder
                Rectangle {
                    id: folder
                    color: "grey"
                    implicitWidth: 200
                    SplitView.minimumWidth: splitView.width / 4
                    SplitView.maximumWidth: splitView.width * 3 / 4

                    // current workspace
                    Column {
                        Label {
                            padding: 3
                            text: "Current workspace:"
                            font.pixelSize: 16
                        }
                        Label {
                            padding: 3
                            text: propmap.workspace_dir
                            font.pixelSize: 12
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
