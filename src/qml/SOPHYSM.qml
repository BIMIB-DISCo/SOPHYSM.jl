import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Universal 2.15
import QtQuick.Dialogs

import org.julialang
import "components/dialogs" as Dialogs

ApplicationWindow {
    font.family: "Arial"
    width: 1100
    height: 700
    minimumWidth: 1100
    minimumHeight: 700
    visible: true
    title: qsTr("SOPHYSM")
    id : mainWindow

    visibility: ApplicationWindow.Maximized
    Universal.theme: Universal.Dark

    // Components
    Dialogs.Download {
        id: downloadDialog
        workspaceDir: propmap.workspace_dir
        
        onDownloadRequested: function(collections, targetDir) {
            // Process download requests
            for (var i = 0; i < collections.length; i++) {
                Julia.log_message("@info", "Starting download...")
                Julia.log_message("@info", "Start downloading [" + collections[i] + "] in " + targetDir)
                Julia.download_single_slide_from_collection(collections[i], targetDir)
            }
        }
        
        onDownloadCanceled: {
            Julia.log_message("@info", "Download canceled by user")
        }
    }

    // Folder Dialog to Select a new Workspace
    FolderDialog {
        id: folderDialog
        title: "Please choose your new Workspace Folder"
        onAccepted: {
            // Parsing the selectedFolder with "file://" removed
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(7);
            downloadDialog.workspaceDir = propmap.workspace_dir;
        }
        onRejected: {
            Julia.log_message("@info", "Canceled new Workspace Folder selection");
        }
    }

    // File Dialog to Select an Image
    FileDialog {
    id: imageDialog
    title: "Please choose an image"

    onAccepted: {
            var path = imageDialog.selectedFile.toString().slice(7);
            Julia.log_message("@info", "loaded image: " + path);
            Julia.display_img(jdisp, path);
            Julia.display_img(jdispSegmentation, path);
            propmap.selected_image_path = path;
            this.close();
        }

    onRejected: {
        Julia.log_message("@info", "Canceled Image selection");
        this.close();
        }
    }

    // Dropdown menu to display the application settings
    Menu {
        id: dropdownMenu
        width: 200

        MenuItem {
            text: "Change Directory"
            onClicked: folderDialog.open();
        }
    }

    // Application
    Column {
        id: verticalBar
        width: 40
        height: parent.height

        // Explorer
        Button {
            id: explorerButton
            icon.source: "img/explorer.png"
            width: parent.width
            height: parent.width

            // On hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Open file Explorer")

            onClicked: {                
                if(folder.visible == true)
                {
                    folder.visible = false;
                    folder.width = 0;
                }
                else
                    folder.visible = true;
            }
        }
        
        // download
        Button {
            id: downloadButton
            icon.source: "img/download.png"
            width: parent.width
            height: parent.width

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Download single collection or multiple collections")

            onClicked: {
                downloadDialog.open();
            }
        }

        // help button
        Button {
            id: helpButton
            icon.source: "img/help.png"
            width: parent.width
            height: parent.width

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Open GitHub documentation")

            onClicked: Qt.openUrlExternally("https://github.com/BIMIB-DISCo/SOPHYSM.jl/tree/development")            
        }

        // settings button
        Button {
            id: settingsButton
            icon.source: "img/settings.png"
            width: parent.width
            height: parent.width

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Settings")

            onClicked: dropdownMenu.popup()
        }
    }

    // workspace Item
    SplitView {
        id: splitView
        anchors {
            left: verticalBar.right
            right: parent.right
            bottom: parent.bottom
            top: parent.top
        }

        // handle to resize the window
        handle: Rectangle {
            id: handleDelegate
            implicitWidth: 3
            color: SplitHandle.pressed ? "#0984e3"
                : (SplitHandle.hovered ? Qt.lighter("lightblue", 1.1) : "black")
        }

        // folder
        Rectangle {
            id: folder
            color: "#282828"
            implicitWidth: 200
            SplitView.minimumWidth: splitView.width / 5
            SplitView.maximumWidth: splitView.width * 3 / 4

            // current workspace
            Column {
                Label {
                    padding: 10
                    color: "white"
                    text: "Current workspace:"
                    font.pixelSize: 16
                }
                Label {
                    padding: 10
                    color: "white"
                    text: propmap.workspace_dir
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            id: viewer
            width: parent.width
            height: parent.height

            anchors.left: folder.right

            // tabBar
            TabBar {
                id: tabBar
                width: parent.width
                height: 40

                TabButton {
                    id: viewButton
                    width: 120
                    height: 40

                    anchors.bottom: parent.bottom

                    contentItem: Text {
                        text: qsTr("View")
                        opacity: enabled ? 1.0 : 0.3
                        color: "lightblue"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    // on hover tooltip
                    hoverEnabled: true
                    ToolTip.delay: 500
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("View Panel")          
                }

                TabButton {
                    id: segmentationButton
                    width: 120
                    height: 40

                    anchors.bottom: parent.bottom

                    contentItem: Text {
                        text: qsTr("Segmentation")
                        opacity: enabled ? 1.0 : 0.3
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    // on hover tooltip
                    hoverEnabled: true
                    ToolTip.delay: 500
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Segmentation Panel")          
                }

                TabButton {
                    id: tessellationButton
                    width: 120 
                    height: 40
                    anchors.bottom: parent.bottom 

                    contentItem: Text {
                        text: qsTr("Tessellation")
                        opacity: enabled ? 1.0 : 0.3
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    // on hover tooltip
                    hoverEnabled: true
                    ToolTip.delay: 500
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Tessellation Panel")
                }

                TabButton {
                    id: simulationButton
                    width: 120
                    height: 40
                    anchors.bottom: parent.bottom

                    contentItem: Text {
                        text: qsTr("Simulation")
                        opacity: enabled ? 1.0 : 0.3
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    // on hover tooltip
                    hoverEnabled: true
                    ToolTip.delay: 500
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Simulation Panel")
                }
            }

            //stackLayout
            StackLayout {
                id: stackLayout
                width: parent.width
                height: parent.height
                anchors {
                    bottom: viewer.bottom
                }
                currentIndex: tabBar.currentIndex
                onCurrentIndexChanged: {
                    switch (currentIndex) {
                        case 0:
                            viewButton.contentItem.color = "lightblue";
                            segmentationButton.contentItem.color = "white";
                            tessellationButton.contentItem.color = "white";
                            simulationButton.contentItem.color = "white";
                            break;
                        case 1:
                            viewButton.contentItem.color = "white";
                            segmentationButton.contentItem.color = "lightblue";
                            tessellationButton.contentItem.color = "white";
                            simulationButton.contentItem.color = "white";
                            break;
                        case 2:
                            viewButton.contentItem.color = "white";
                            segmentationButton.contentItem.color = "white";
                            tessellationButton.contentItem.color = "lightblue";
                            simulationButton.contentItem.color = "white";
                            break;
                        case 3:
                            viewButton.contentItem.color = "white";
                            segmentationButton.contentItem.color = "white";
                            tessellationButton.contentItem.color = "white";
                            simulationButton.contentItem.color = "lightblue";
                            break;
                    }
                }
                
                anchors {
                    top: tabBar.bottom
                }

                Item {
                    id: viewTab
                    Rectangle {
                        id: viewTabContainer
                        anchors.fill: parent
                        color: "#282828"

                        Rectangle {
                            id: rectangleViewContainer
                            width: 572
                            height: 572
                            anchors {
                                top: parent.top
                                left: parent.left
                                topMargin: 30
                                leftMargin: 30
                            }
                            color: "#3f3f3f"

                            JuliaDisplay {
                                id: jdisp
                                width: 512
                                height: 512
                                anchors.centerIn: parent
                            }
                        }

                        // Image Selection button
                        Button {
                            id: imageSelectionButton
                            text: "Select Image"
                            
                            width: 120
                            height: 30

                            anchors {
                                top: rectangleViewContainer.bottom
                                topMargin: 10
                                left: viewTabContainer.left
                                leftMargin: 30
                            }
                            // On hover tooltip
                            hoverEnabled: true
                            ToolTip.delay: 500
                            ToolTip.timeout: 5000
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Open an Image")

                            onClicked: {
                                imageDialog.open()
                            }
                        }
                    }                    
                }

                // Segmentation window
                Item {
                    id: segmentationTab
                    Rectangle{
                        id: segmentationTabContainer
                        color: "#282828"
                        anchors.fill: parent

                        Rectangle {
                            id: rectangleSegmentationContainer
                            width: 572
                            height: 572
                            anchors {
                                top: parent.top
                                left: parent.left
                                topMargin: 30
                                leftMargin: 30
                            }
                            color: "#3f3f3f"

                            JuliaDisplay {
                                id: jdispSegmentation
                                width: 512
                                height: 512
                                anchors.centerIn: parent
                            }
                        }

                        Rectangle {
                            id: rectangleSegmentatedContainer
                            width: 384
                            height: 384
                            anchors {
                                top: parent.top
                                left: rectangleSegmentationContainer.right
                                topMargin: 30
                                leftMargin: 30
                            }
                            color: "#3f3f3f"

                            JuliaDisplay {
                                id: jdispSegmentated
                                width: 324
                                height: 324
                                anchors.centerIn: parent
                            }
                        }

                        // Segmentate Button
                        Button {
                            id: segmentateButton
                            text: "Segment"
                            
                            width: 120
                            height: 30

                            anchors {
                                top: rectangleSegmentationContainer.bottom
                                topMargin: 10
                                left: segmentationTabContainer.left
                                leftMargin: 30
                            }
                            // On hover tooltip
                            hoverEnabled: true
                            ToolTip.delay: 500
                            ToolTip.timeout: 5000
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Segmentate Image Chosen in View Tab")

                            onClicked: {
                                var output_path = propmap.selected_image_path.replace(".jpg", "_result.jpg");
                                Julia.segment_image(propmap.selected_image_path, 
                                                    propmap.selected_image_path, 
                                                    output_path);
                                Julia.display_img(jdispSegmentated, output_path)
                            }
                        }

                        Label {
                            id: segmentationUpdateText
                            text: propmap.segmentation_update_text
                            color: "white"
                            font.pixelSize: 18
                            anchors{
                                top: rectangleSegmentationContainer.bottom
                                topMargin: 10
                                left: segmentateButton.right
                                leftMargin: 30
                            }
                        }
                    }
                }

                // Tessellation window
                Item {
                    Rectangle{
                        color: "#282828"
                        anchors.fill: parent
                    }
                    id: tessellationTab
                }

                // Simulation window
                Item {
                    Rectangle{
                        color: "#282828"
                        anchors.fill: parent
                    }
                    id: simulationTab
                }
            }
        }
    }
}