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

    Dialogs.Download {
        id: downloadDialog
        workspaceDir: propmap.workspace_dir
        
        onDownloadRequested: function(collections, targetDir) {
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
    
    Dialogs.Settings {
        id: settingsDialog
        workspaceDir: propmap.workspace_dir
        
        onSettingsApplied: {
            Julia.log_message("@info", "Settings applied")
        }
        
        onSettingsCanceled: {
            Julia.log_message("@info", "Settings canceled")
        }
    }
    
    Dialogs.About {
        id: aboutDialog
    }

    FolderDialog {
        id: folderDialog
        title: "Please choose your new Workspace Folder"
        onAccepted: {
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(7);
            downloadDialog.workspaceDir = propmap.workspace_dir;
            settingsDialog.workspaceDir = propmap.workspace_dir;
            Julia.log_message("@info", "Changed workspace directory to: " + propmap.workspace_dir);
        }
        onRejected: {
            Julia.log_message("@info", "Canceled new Workspace Folder selection");
        }
    }

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

    Column {
        id: verticalBar
        width: 40
        height: parent.height
        
        // download
        Button {
            id: downloadButton
            icon.source: "img/download_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
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

        Button {
            id: settingsButton
            icon.source: "img/settings_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
            width: parent.width
            height: parent.width

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Settings")

            onClicked: settingsDialog.open()
        }

        Button {
            id: helpButton
            icon.source: "img/info_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
            width: parent.width
            height: parent.width

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("About")

            onClicked: aboutDialog.open()
        }
    }

    Rectangle {
        id: mainViewArea
        anchors {
            left: verticalBar.right
            right: parent.right
            bottom: parent.bottom
            top: parent.top
        }
        color: "#282828"

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

                hoverEnabled: true
                ToolTip.delay: 500
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Simulation Panel")
            }
        }

        StackLayout {
            id: stackLayout
            width: parent.width
            height: parent.height
            anchors {
                bottom: mainViewArea.bottom
                top: tabBar.bottom
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
                            if (!propmap.segmentation_method || propmap.segmentation_method === "") {
                                Julia.log_message("@error", "No segmentation method selected. Opening settings dialog.");
                                settingsDialog.open();
                                return;
                            }
                            
                            if (!propmap.selected_image_path || propmap.selected_image_path === "") {
                                Julia.log_message("@error", "No image selected. Please select an image first.");
                                propmap.segmentation_update_text = "Please select an image first";
                                return;
                            }
                            
                            if (propmap.segmentation_method === "jnet" && 
                                (!propmap.model_bson_path || propmap.model_bson_path === "")) {
                                Julia.log_message("@error", "JNet selected but no model file provided. Opening settings dialog.");
                                // Highlight the model button in the settings dialog
                                settingsDialog.highlightModelButton = true;
                                settingsDialog.open();
                                return;
                            }
                            
                            propmap.segmentation_update_text = "Processing...";
                            var output_path = propmap.selected_image_path.replace(".jpg", "_result.jpg");
                            
                            Julia.segment_image(propmap.segmentation_method,
                                              propmap.model_bson_path, 
                                              propmap.selected_image_path, 
                                              output_path);
                                              
                            Julia.display_img(jdispSegmentated, output_path);
                            propmap.segmentation_update_text = "Segmentation complete";
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

            Item {
                Rectangle{
                    color: "#282828"
                    anchors.fill: parent
                }
                id: tessellationTab
            }

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