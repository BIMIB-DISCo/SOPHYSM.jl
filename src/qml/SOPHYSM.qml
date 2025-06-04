import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Universal 2.15
import QtQuick.Dialogs

import org.julialang
import "components/dialogs" as Dialogs
import "components/common" as Common

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
        color: "#1E1E1E"  // Changed to match About dialog background

        Rectangle {
            id: segmentationTabContainer
            color: "#1E1E1E"  // Changed to match About dialog background
            anchors.fill: parent

            Column {
                id: segmentationControls
                width: 250
                spacing: 10
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: 30
                    topMargin: 30
                }

                Common.Button {
                    id: imageSelectionButton
                    text: "Select Image"
                    buttonWidth: 250
                    buttonHeight: 40
                    isHighlighted: !propmap.selected_image_path || propmap.selected_image_path === ""
                    
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

                Row {
                    spacing: 10
                    
                    Common.Button {
                        id: segmentateButton
                        text: "Segment"
                        buttonWidth: 120
                        buttonHeight: 40
                        
                        hoverEnabled: true
                        ToolTip.delay: 500
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Segmentate Image")

                        onClicked: {
                            if (!propmap.segmentation_method || propmap.segmentation_method === "") {
                                Julia.log_message("@error", "No segmentation method selected. Opening settings dialog.");
                                settingsDialog.open();
                                return;
                            }
                            
                            if (!propmap.selected_image_path || propmap.selected_image_path === "") {
                                Julia.log_message("@error", "No image selected. Please select an image first.");
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
                            
                            var pathParts = propmap.selected_image_path.split('.');
                            var extension = pathParts.pop();
                            var basePath = pathParts.join('.');
                            var output_path = basePath + "_seg.png";
                            
                            Julia.segment_image(propmap.segmentation_method,
                                                propmap.model_bson_path, 
                                                propmap.selected_image_path, 
                                                output_path);
                                                
                            Julia.display_img(jdispSegmentated, output_path);
                            
                            // Display graph images if using graph method
                            if (propmap.segmentation_method === "graph") {
                                // Fix: Use basePath + "_seg_graph_vertex.png" instead of basePath + "_graph_vertex.png"
                                Julia.display_img(jdispGraphVertex, basePath + "_seg_graph_vertex.png");
                                Julia.display_img(jdispGraphEdges, basePath + "_seg_graph_edges.png");
                            }
                        }
                    }
                    
                    Common.Button {
                        id: tesselateButton
                        text: "Tesselate"
                        buttonWidth: 120
                        buttonHeight: 40

                        hoverEnabled: true
                        ToolTip.delay: 500
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Tesselate Image")

                        onClicked: {
                            if (!propmap.selected_image_path || propmap.selected_image_path === "") {
                                Julia.log_message("@error", "No image selected. Please select an image first.");
                                return;
                            }

                            var pathParts = propmap.selected_image_path.split('.');
                            var extension = pathParts.pop();
                            var basePath = pathParts.join('.');
                            var outputPath = basePath;

                            Julia.start_tessellation(propmap.selected_image_path, outputPath);

                            Julia.display_img(jdispTessellationTotal, outputPath + "_total_tessellation.png");
                            Julia.display_img(jdispTessellationCells, outputPath + "_cell_tessellation.png");
                            Julia.display_img(jdispGraphVertex, outputPath + "_seg_graph_vertex.png");
                            Julia.display_img(jdispGraphEdges, outputPath + "_seg_graph_edges.png");
                        }
                    }
                }
            }

            ScrollView {
                id: segmentationScrollView
                anchors {
                    left: segmentationControls.right
                    leftMargin: 120
                    top: parent.top
                    topMargin: 30
                    bottom: parent.bottom
                    bottomMargin: 30
                    right: parent.right
                    rightMargin: 30
                }
                clip: true
                contentWidth: segmentationGrid.width

                GridLayout {
                    id: segmentationGrid
                    width: Math.min(parent.width - segmentationControls.width - 180, (500 * 2) + columnSpacing)
                    columns: 2
                    rowSpacing: 20
                    columnSpacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        id: originalImageContainer
                        width: 500
                        height: 500
                        color: "#3f3f3f"

                        JuliaDisplay {
                            id: jdispSegmentation
                            width: 460
                            height: 460
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        id: segmentedImageContainer
                        width: 500
                        height: 500
                        color: "#3f3f3f"

                        JuliaDisplay {
                            id: jdispSegmentated
                            width: 460
                            height: 460
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        id: placeholder3
                        width: 500
                        height: 500
                        color: "#3f3f3f"
                        
                        JuliaDisplay {
                            id: jdispGraphVertex
                            width: 460
                            height: 460
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        id: placeholder4
                        width: 500
                        height: 500
                        color: "#3f3f3f"
                        
                        JuliaDisplay {
                            id: jdispGraphEdges
                            width: 460
                            height: 460
                            anchors.centerIn: parent
                        }
                    }

                    Rectangle {
                        id: placeholder1
                        width: 500
                        height: 333
                        color: "#3f3f3f"

                        JuliaDisplay {
                            id: jdispTessellationTotal
                            anchors.centerIn: parent
                            width: 460
                            height: 307
                        }
                    }

                    Rectangle {
                        id: placeholder2
                        width: 500
                        height: 333
                        color: "#3f3f3f"

                        JuliaDisplay {
                            id: jdispTessellationCells
                            anchors.centerIn: parent
                            width: 460
                            height: 307
                        }
                    }
                }
            }
        }
    }
}