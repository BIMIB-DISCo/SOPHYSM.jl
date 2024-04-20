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
        width: 200

        MenuItem {
            text: "Change Directory"
            onClicked: folderDialog.open()
        }

        MenuItem {
            text: "test"
            onClicked: {
                console.log("test onClicked")
            }

        }

        MenuItem {
            text: "Item 3"
            onClicked: console.log("Item 3 selected")
        }
    }

    
    Column {
        id: verticalBar
        width: 40
        height: parent.height
        anchors {
            top: tabBar.bottom
        }
        // explorer
        Button {
            id: explorerButton

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Open file Explorer")

            icon.source: "img/explorer.png"
            width: parent.width
            height: parent.width

            onClicked: {
                
                if(folder.visible == true)
                {
                    folder.visible = false;
                    folder.width = 0;
                }
                else
                {
                    folder.visible = true;
                }
            }
        }
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
            width: parent.width
            height: parent.width
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

            width: parent.width
            height: parent.width
        }
    }

    // tabBar
    TabBar {
        id: tabBar
        width: parent.width
        contentHeight: 40
        x: 40

        TabButton {
            text: qsTr("Segmentation")
            id: segmentationButton
            width: 100           
        }
        TabButton {
            text: qsTr("Tessellation")
            id: tessellationButton
            width: 100
        }
        TabButton {
            text: qsTr("Simulation")
            id: simulationButton
            width: 100
        }
    }

        // workspace Item
        SplitView {
            id: splitView
            width: parent.width
            height: parent.height
            anchors {
                top: tabBar.bottom
                left: verticalBar.right
            }

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
                SplitView.minimumWidth: splitView.width / 5
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

                //stackLayout
                StackLayout {
                    id: stackLayout
                    width: parent.width
                    height: parent.height
                    currentIndex: tabBar.currentIndex

                    Item {
                        Rectangle{
                            color: "lime"
                            anchors.fill: parent
                        }
                        id: segmentationTab
                    }

                    Item {

                        Rectangle{
                            color: "yellow"
                            width: 30
                            height: 30
                        }
                        id: tessellationTab
                    }

                    Item {
                        Rectangle{
                            color: "green"
                            width: 30
                            height: 30
                        }
                        id: simulationTab
                    }
                }
            }
        }
    }
