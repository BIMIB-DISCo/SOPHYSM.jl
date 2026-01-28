import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Universal 2.15
import QtQuick.Dialogs

import jlqml

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

    // Helper function to set image source with cache busting
    function setSource(imageItem, path) {
        if (path === "" || path === undefined) return;
        imageItem.source = "file://" + path + "?t=" + Math.random();
    }

    // Status Poller Timer to check job completion
    Timer {
        id: statusPoller
        interval: 500 // Timer interval in ms
        repeat: true
        running: false // Flag to start/stop the timer

        onTriggered: {
            var result = Julia.check_job_status();
            if (result !== "") {
                // result not empty -> Julia finished
                console.log("POLLER: Result found: " + result);
                
                // Stop the poller
                statusPoller.stop();
                
                // Handling errors or success
                if (result === "ERROR") {
                    Julia.log_message("@error", "An error occurred during the calculation.");
                } else {
                    // Segmentation completed -> loading images
                    setSource(imgSegmentated, result);
                    if (propmap.segmentation_method === "graph") {
                        var bp = result.replace("_seg.png", "");
                        setSource(imgGraphVertex, bp + "_seg_graph_vertex.png");
                        setSource(imgGraphEdges, bp + "_seg_graph_edges.png");
                    }
                    Julia.log_message("@info", "Segmentation completed!");
                }

                // 3. Unlock the "Segment" button
                segmentateButton.enabled = true;
                segmentateButton.text = "Segment";
            } else {
                /* 
                If result is empty, Julia is still working
                Do nothing, the timer will trigger again in 500ms.
                */
                console.log("POLLER: Julia is working...");
            }
        }
    }

    // Download Dialog
    Dialogs.Download {
        id: downloadDialog
        workspaceDir: propmap.workspace_dir
        onDownloadRequested: function(collections, targetDir) {
            for (var i = 0; i < collections.length; i++) {
                Julia.log_message("@info", "Starting download...")
                Julia.download_single_slide_from_collection(collections[i], targetDir)
            }
        }
        onDownloadCanceled: { Julia.log_message("@info", "Download canceled") }
    }

    // Settings Dialog
    Dialogs.Settings {
        id: settingsDialog
        workspaceDir: propmap.workspace_dir
        onSettingsApplied: { Julia.log_message("@info", "Settings applied") }
        onSettingsCanceled: { Julia.log_message("@info", "Settings canceled") }
    }

    // About Dialog
    Dialogs.About { id: aboutDialog }

    // Folder Dialog for workspace selection
    FolderDialog {
        id: folderDialog
        title: "Workspace Folder"
        onAccepted: {
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(7);
            downloadDialog.workspaceDir = propmap.workspace_dir;
            settingsDialog.workspaceDir = propmap.workspace_dir;
            Julia.log_message("@info", "Changed workspace: " + propmap.workspace_dir);
        }
    }

    // File Dialog for image selection
    FileDialog {
        id: imageDialog
        title: "Choose an image"
        onAccepted: {
            var path = imageDialog.selectedFile.toString().slice(7);
            Julia.log_message("@info", "loaded image: " + path);
            propmap.selected_image_path = path;
            setSource(imgSegmentation, path);
            this.close();
        }
    }

    // Sidebar with buttons
    Rectangle {
        id: verticalBarBackground
        width: 40; height: parent.height; color: "#1E1E1E"
        Column {
            id: verticalBar
            width: parent.width; height: parent.height
            Item { width: parent.width; height: 30 }

            Button {
                id: downloadButton
                icon.source: "img/download_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                width: parent.width; height: parent.width; background: Rectangle { color: "#1E1E1E" }
                onClicked: { downloadDialog.open(); }
            }

            Button {
                id: settingsButton
                icon.source: "img/settings_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                width: parent.width; height: parent.width; background: Rectangle { color: "#1E1E1E" }
                onClicked: settingsDialog.open()
            }

            Button {
                id: helpButton
                icon.source: "img/info_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                width: parent.width; height: parent.width; background: Rectangle { color: "#1E1E1E" }
                onClicked: aboutDialog.open()
            }
        }
    }

    // Main View Area
    Rectangle {
        id: mainViewArea
        anchors { left: verticalBarBackground.right; right: parent.right; bottom: parent.bottom; top: parent.top }
        color: "#1E1E1E" 
        Rectangle {
            id: segmentationTabContainer
            color: "#1E1E1E" 
            anchors.fill: parent
            Column {
                id: segmentationControls
                width: 250; spacing: 10
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 30; topMargin: 30 }
                Common.Button {
                    id: imageSelectionButton
                    text: "Select Image"
                    buttonWidth: 250; buttonHeight: 40
                    isHighlighted: !propmap.selected_image_path
                    onClicked: { imageDialog.open() }
                }
                Row {
                    spacing: 10
                    Common.Button {
                        id: segmentateButton
                        text: "Segment"
                        buttonWidth: 120; buttonHeight: 40
                        onClicked: {
                            if (!propmap.segmentation_method) { Julia.log_message("@error", "No method."); settingsDialog.open(); return; }
                            if (!propmap.selected_image_path) { Julia.log_message("@error", "No image."); return; }
                            if (propmap.segmentation_method === "jnet" && (!propmap.model_bson_path || propmap.model_bson_path === "")) {
                                Julia.log_message("@error", "JNet selected but no model file.");
                                settingsDialog.highlightModelButton = true;
                                settingsDialog.open(); return;
                            }
                            var pathParts = propmap.selected_image_path.split('.');
                            var extension = pathParts.pop();
                            var basePath = pathParts.join('.');
                            var output_path = basePath + "_seg.png";
                            
                            // 1. UI Feedback
                            segmentateButton.enabled = false;
                            segmentateButton.text = "Running...";

                            // 2. Start the async job in Julia
                            Julia.start_async_job(
                                propmap.segmentation_method,
                                propmap.model_bson_path, 
                                propmap.selected_image_path, 
                                output_path
                            );

                            // 3. Start the Poller to check for job completion
                            statusPoller.start();
                        }
                    }
                    
                    Common.Button {
                        id: tesselateButton
                        text: "Tesselate"
                        buttonWidth: 120; buttonHeight: 40
                        onClicked: {
                            if (!propmap.selected_image_path) { Julia.log_message("@error", "No image."); return; }
                            var pathParts = propmap.selected_image_path.split('.');
                            var extension = pathParts.pop();
                            var basePath = pathParts.join('.');
                            var outputPath = basePath;
                            Julia.start_tessellation(propmap.selected_image_path, outputPath);
                            setSource(imgTessellationTotal, outputPath + "_total_tessellation.png");
                            setSource(imgTessellationCells, outputPath + "_cell_tessellation.png");
                            setSource(imgGraphVertex, outputPath + "_seg_graph_vertex.png");
                            setSource(imgGraphEdges, outputPath + "_seg_graph_edges.png");
                        }
                    }
                }
            }
            // Scrollview for segmentation images results
            ScrollView {
                id: segmentationScrollView
                anchors {
                    left: segmentationControls.right; leftMargin: 120
                    top: parent.top; topMargin: 30
                    bottom: parent.bottom; bottomMargin: 30
                    right: parent.right; rightMargin: 30
                }
                clip: true
                contentWidth: segmentationGrid.width
                
                GridLayout {
                    id: segmentationGrid
                    width: Math.min(parent.width - segmentationControls.width - 180, (500 * 2) + columnSpacing)
                    columns: 2; rowSpacing: 20; columnSpacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { 
                        width: 500; height: 500; color: "#3f3f3f"
                        Image { id: imgSegmentation; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false } 
                    }

                    Rectangle { 
                        width: 500; height: 500; color: "#3f3f3f"
                        Image { id: imgSegmentated; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false } 
                    }

                    Rectangle { 
                        width: 500; height: 500; color: "#3f3f3f"
                        Image { id: imgGraphVertex; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false } 
                    }

                    Rectangle { 
                        width: 500; height: 500; color: "#3f3f3f"
                        Image { id: imgGraphEdges; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false } 
                    }

                    Rectangle { 
                        width: 500; height: 333; color: "#3f3f3f"
                        Image { id: imgTessellationTotal; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false } 
                    }

                    Rectangle { 
                        width: 500; height: 333; color: "#3f3f3f"
                        Image { id: imgTessellationCells; anchors.fill: parent; fillMode: Image.PreserveAspectFit; cache: false } 
                    }
                }
            }
        }
    }
}