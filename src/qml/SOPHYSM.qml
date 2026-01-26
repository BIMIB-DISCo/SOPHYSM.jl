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

    // Helper to force image refresh (bypassing cache)
    function setSource(imageItem, path) {
        if (path === "" || path === undefined) return;
        imageItem.source = "file://" + path + "?t=" + Math.random();
    }

    // ========================================================================
    // STARTUP LOGIC: Delayed Warm-up & System Ready Check
    // ========================================================================
    Timer {
        id: startupTimer
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            console.log("QML: GUI Loaded. Starting background warm-up...");
            Julia.perform_warmup(); // Triggers JIT compilation in background
            readyPoller.start();    // Starts checking if engine is ready
        }
    }

    // Checks if the Julia engine has finished warming up
    Timer {
        id: readyPoller
        interval: 500
        repeat: true
        running: false
        onTriggered: {
            if (Julia.check_system_ready()) {
                console.log("QML: Engine ready!");
                segmentateButton.text = "Segment";
                segmentateButton.enabled = true;
                readyPoller.stop();
            }
        }
    }

    // ========================================================================
    // STATUS POLLER: Checks job status periodically
    // ========================================================================
    Timer {
        id: statusPoller
        interval: 500
        repeat: true
        running: false
        
        onTriggered: {
            var result = Julia.check_job_status();
            
            if (result !== "") {
                statusPoller.stop();
                
                if (result === "ERROR") {
                    Julia.log_message("@error", "An error occurred during calculation.");
                } else {
                    // Update native images
                    setSource(imgSegmentated, result);
                    
                    if (propmap.segmentation_method === "graph") {
                         var bp = result.replace("_seg.png", "");
                         setSource(imgGraphVertex, bp + "_seg_graph_vertex.png");
                         setSource(imgGraphEdges, bp + "_seg_graph_edges.png");
                    }
                    Julia.log_message("@info", "Segmentation completed successfully!");
                }
                
                // Re-enable UI
                segmentateButton.enabled = true;
                segmentateButton.text = "Segment";
            }
        }
    }

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
        onDownloadCanceled: { Julia.log_message("@info", "Download canceled") }
    }
    
    Dialogs.Settings {
        id: settingsDialog
        workspaceDir: propmap.workspace_dir
        onSettingsApplied: { Julia.log_message("@info", "Settings applied") }
        onSettingsCanceled: { Julia.log_message("@info", "Settings canceled") }
    }
    
    Dialogs.About { id: aboutDialog }

    FolderDialog {
        id: folderDialog
        title: "Please choose your new Workspace Folder"
        onAccepted: {
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(7);
            downloadDialog.workspaceDir = propmap.workspace_dir;
            settingsDialog.workspaceDir = propmap.workspace_dir;
            Julia.log_message("@info", "Changed workspace directory to: " + propmap.workspace_dir);
        }
    }

    FileDialog {
        id: imageDialog
        title: "Please choose an image"
        onAccepted: {
            var path = imageDialog.selectedFile.toString().slice(7);
            Julia.log_message("@info", "loaded image: " + path);
            propmap.selected_image_path = path;
            
            // Load preview
            setSource(imgSegmentation, path);
            
            this.close();
        }
    }

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
                
                hoverEnabled: true
                ToolTip.delay: 500
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Download Collections")
                
                onClicked: { downloadDialog.open(); }
            }
            
            Button {
                id: settingsButton
                icon.source: "img/settings_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                width: parent.width; height: parent.width; background: Rectangle { color: "#1E1E1E" }
                
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
                width: parent.width; height: parent.width; background: Rectangle { color: "#1E1E1E" }
                
                hoverEnabled: true
                ToolTip.delay: 500
                ToolTip.timeout: 5000
                ToolTip.visible: hovered
                ToolTip.text: qsTr("About")
                
                onClicked: aboutDialog.open()
            }
        }
    }

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
                    
                    hoverEnabled: true
                    ToolTip.delay: 500
                    ToolTip.timeout: 5000
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Open an Image")
                    
                    onClicked: { imageDialog.open() }
                }

                Row {
                    spacing: 10
                    
                    Common.Button {
                        id: segmentateButton
                        text: "Initializing..." // Initial state
                        enabled: false          // Disabled until Warm-up is done
                        buttonWidth: 120; buttonHeight: 40
                        
                        hoverEnabled: true
                        ToolTip.delay: 500
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Segmentate Image")
                        
                        onClicked: {
                            if (!propmap.segmentation_method) { 
                                Julia.log_message("@error", "No segmentation method selected. Opening settings dialog.");
                                settingsDialog.open(); return; 
                            }
                            if (!propmap.selected_image_path) { 
                                Julia.log_message("@error", "No image selected. Please select an image first."); return; 
                            }
                            if (propmap.segmentation_method === "jnet" && (!propmap.model_bson_path || propmap.model_bson_path === "")) {
                                Julia.log_message("@error", "JNet selected but no model file provided.");
                                settingsDialog.highlightModelButton = true;
                                settingsDialog.open(); return;
                            }
                            
                            // UI Feedback
                            segmentateButton.enabled = false;
                            segmentateButton.text = "Running...";
                            Julia.log_message("@info", "Processing image in background...");
                            
                            var pathParts = propmap.selected_image_path.split('.');
                            var extension = pathParts.pop();
                            var basePath = pathParts.join('.');
                            var output_path = basePath + "_seg.png";
                            
                            // Start Job
                            Julia.start_async_job(
                                propmap.segmentation_method,
                                propmap.model_bson_path, 
                                propmap.selected_image_path, 
                                output_path
                            );
                            
                            // Start Polling
                            statusPoller.start();
                        }
                    }
                    
                    Common.Button {
                        id: tesselateButton
                        text: "Tesselate"
                        buttonWidth: 120; buttonHeight: 40
                        
                        hoverEnabled: true
                        ToolTip.delay: 500
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("Tesselate Image")
                        
                        onClicked: {
                            if (!propmap.selected_image_path) { Julia.log_message("@error", "No image selected."); return; }
                            var pathParts = propmap.selected_image_path.split('.');
                            var extension = pathParts.pop();
                            var basePath = pathParts.join('.');
                            var outputPath = basePath;

                            Julia.start_tessellation(propmap.selected_image_path, outputPath);
                            
                            // Visualizzazione Tessellazione (Native)
                            setSource(imgTessellationTotal, outputPath + "_total_tessellation.png");
                            setSource(imgTessellationCells, outputPath + "_cell_tessellation.png");
                            setSource(imgGraphVertex, outputPath + "_seg_graph_vertex.png");
                            setSource(imgGraphEdges, outputPath + "_seg_graph_edges.png");
                        }
                    }
                }
            }

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
                    
                    // --- NATIVE IMAGE COMPONENTS ---
                    // Stable approach: Replaced JuliaDisplay with native Image
                    
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