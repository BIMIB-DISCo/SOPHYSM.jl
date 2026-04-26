import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import jlqml
import "./components/common" as Common
import "./components/dialogs" as Dialogs
import "./components/models" as Models

ApplicationWindow {
    id: root
    visible: true
    width: 1400
    height: 900
    minimumWidth: 1100
    minimumHeight: 700
    title: "SOPHYSM"
    visibility: ApplicationWindow.Maximized
    
    // ================= THEME AND STATE =================
    property bool isDarkTheme: true
    property string workspaceDir: propmap.workspace_dir || ""
    property string currentProject: ""
    property string currentImage: ""
    property string segmentationMethod: propmap.segmentation_method || ""
    property int workflowStep: 0
    property var projectImages: []
    
    // ================= PROPERTIES AND FUNCTIONS =================
    property string expandImagePath: ""
    property string expandImageTitleBase: "Preview"
    
    // ================= HELPER =================
    function setSource(imageItem, path) {
        if (!path || path === "") return;
        
        var resolved = Julia.resolve_image_for_qml(path);
        
        imageItem.source = "file://" + resolved + "?t=" + Date.now();
    }
    
    function updateWorkflowStep() {
        if (!currentProject) { workflowStep = 0; return; }
        if (!currentImage) { workflowStep = 0; return; }
        if (!segmentationMethod) { workflowStep = 1; return; }
        workflowStep = 3;
    }
    
    function onSegmentationCompleted(imageName, outputs) {
        console.log("✅ Segmentation completed for:", imageName);
        if (outputs.segmented) setSource(panelSegmented.imageItem, outputs.segmented);
        if (outputs.graphVertex) setSource(panelVertices.imageItem, outputs.graphVertex);
        if (outputs.graphEdges) setSource(panelGraph.imageItem, outputs.graphEdges);
        if (outputs.overlay) setSource(panelOverlay.imageItem, outputs.overlay);
        if (outputs.voronoi) setSource(panelVoronoi.imageItem, outputs.voronoi);
        for (var i = 0; i < projectImages.length; i++) {
            if (projectImages[i].name === imageName) { projectImages[i].hasOutput = true; break; }
        }
        tessellateButton.enabled = true;
        if (workflowStep === 3) workflowStep = 4;
        Julia.log_message("@info", "Analysis ready for: " + imageName);
    }

    // ================= MAIN LAYOUT =================
    Row {
        anchors.fill: parent
        spacing: 0
        
        // === SIDEBAR ===
        Rectangle {
            id: sidebar
            width: Math.max(250, Math.min(350, root.width * 0.20))
            height: parent.height
            color: isDarkTheme ? "#1a1a1a" : "#f5f5f5"
            border.color: isDarkTheme ? "#333" : "#ddd"
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                
                // HEADER
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 75
                    spacing: 6
                    Label { text: "🧬 SOPHYSM"; font.bold: true; font.pixelSize: 16; color: isDarkTheme ? "#fff" : "#333"; elide: Text.ElideRight }
                    Label { text: workspaceDir ? "📁 " + workspaceDir : "⚠ No workspace"; font.pixelSize: 9; color: isDarkTheme ? "#aaa" : "#666"; wrapMode: Text.WordWrap; elide: Text.ElideMiddle; Layout.fillWidth: true; maximumLineCount: 2 }
                    Common.Button { text: "Change Workspace"; buttonWidth: parent.width; buttonHeight: 26; font.pixelSize: 10; onClicked: workspaceDialog.open() }
                    Button {
                        icon.source: "img/download_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                        icon.width: 24; icon.height: 24
                        width: parent.width; height: 26
                        text: "Download TCGA"
                        icon.color: isDarkTheme ? "#fff" : "#333"
                        flat: true
                        background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? (root.isDarkTheme ? "#666" : "#ccc") : "transparent" }
                        hoverEnabled: true
                        onClicked: downloadDialog.open()
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: isDarkTheme ? "#333" : "#ddd" }
                
                // PROJECT MANAGER
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 4
                        Label { text: "📁 Project"; font.bold: true; font.pixelSize: 12; color: isDarkTheme ? "#fff" : "#333" }
                        Item { Layout.fillWidth: true }
                        Common.Button { text: "🆕"; buttonWidth: 28; buttonHeight: 24; font.pixelSize: 10; ToolTip.text: "New Project"; onClicked: newProjectDialog.open() }
                        Common.Button { text: "📂"; buttonWidth: 28; buttonHeight: 24; font.pixelSize: 10; ToolTip.text: "Open Project"; onClicked: openProjectDialog.open() }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: isDarkTheme ? "#252525" : "#fff"
                        border.color: isDarkTheme ? "#444" : "#ccc"
                        border.width: 1
                        radius: 4
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 4
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            contentWidth: -1
                            contentHeight: imagesColumn.implicitHeight
                            Column {
                                id: imagesColumn
                                width: parent.width - 8
                                spacing: 2
                                Repeater {
                                    model: projectImages
                                    Rectangle {
                                        width: parent.width
                                        height: 30
                                        color: (modelData.name === currentImage) ? (isDarkTheme ? "#444" : "#e0e0e0") : "transparent"
                                        radius: 3
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 4
                                            spacing: 6
                                            Image { source: "img/image_24dp.png"; width: 16; height: 16; visible: !modelData.hasOutput }
                                            Image { source: "img/check_circle_24dp.png"; width: 16; height: 16; visible: modelData.hasOutput }
                                            Label { text: modelData.name; font.pixelSize: 11; color: isDarkTheme ? "#ddd" : "#333"; elide: Text.ElideRight; Layout.fillWidth: true }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: { currentImage = modelData.path; loadCurrentImage(); updateWorkflowStep(); }
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                                Label {
                                    visible: projectImages.length === 0
                                    text: currentProject ? "No images yet" : "Open a project"
                                    font.pixelSize: 10; font.italic: true; color: isDarkTheme ? "#666" : "#999"
                                    wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true; Layout.preferredHeight: 40
                                }
                            }
                        }
                    }
                    Common.Button {
                        Layout.fillWidth: true; Layout.preferredHeight: 28
                        text: "➕ Add Image"; buttonHeight: 28; font.pixelSize: 10
                        enabled: currentProject !== ""
                        onClicked: imageSourceMenu.popup()
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: isDarkTheme ? "#333" : "#ddd" }
                
                // WORKFLOW
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 230
                    spacing: 6
                    Label { text: "⚙️ Analysis"; font.bold: true; font.pixelSize: 12; color: isDarkTheme ? "#fff" : "#333" }
                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 36; spacing: 4
                        ComboBox {
                            id: methodComboBox
                            Layout.fillWidth: true; height: 36; font.pixelSize: 11
                            model: ["JNet", "Graph", "Cellpose", "Cellpose.jl"]
                            
                            Component.onCompleted: {
                                var methods = ["jnet", "graph", "cellpose", "cellpose_jl"];
                                var idx = methods.indexOf(segmentationMethod);
                                currentIndex = (idx >= 0) ? idx : -1;
                            }
                            
                            onCurrentTextChanged: {
                                var methodKey = methodComboBox.currentText.toLowerCase().replace(".", "_");
                                if (segmentationMethod !== methodKey) {
                                    segmentationMethod = methodKey;
                                    propmap.segmentation_method = methodKey;
                                    updateWorkflowStep();
                                }
                            }
                        }
                        Common.Button {
                            text: "⚙️"; buttonWidth: 36; buttonHeight: 36
                            ToolTip.text: "Configure parameters"
                            enabled: methodComboBox.currentIndex >= 0
                            isHighlighted: workflowStep === 2
                            onClicked: segmentationDialog.open()
                        }
                    }
                    Common.Button {
                        id: segmentButton
                        text: "▶ Segment"; buttonWidth: parent.width; buttonHeight: 36
                        font.bold: true
                        isHighlighted: workflowStep === 3
                        enabled: currentImage !== "" && segmentationMethod !== ""
                        onClicked: {
                            if (!currentImage || !segmentationMethod) return;
                            
                            var base = currentImage.replace(/\.[^/.]+$/, "");
                            var outputPath = base + "_seg.png";
                            
                            segmentButton.enabled = false;
                            segmentButton.text = "Running...";
                            
                            Julia.log_message("@info", "Starting segmentation. Output will be: " + outputPath);
                            
                            Julia.start_async_job(
                                segmentationMethod, 
                                propmap.model_bson_path, 
                                currentImage,
                                outputPath
                            );
                            
                            jobPoller.start();
                        }
                    }
                    Common.Button {
                        id: tessellateButton
                        text: "♦ Tessellate"; buttonWidth: parent.width; buttonHeight: 36
                        isHighlighted: workflowStep === 4
                        enabled: false
                        onClicked: {
                            var pathParts = currentImage.split('.');
                            var basePath = pathParts.join('.');
                            Julia.start_tessellation(currentImage, basePath);
                            setSource(panelOverlay.imageItem, basePath + "_total_tessellation.png");
                            setSource(panelVoronoi.imageItem, basePath + "_cell_tessellation.png");
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                
                // FOOTER
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 8
                    Item { Layout.fillWidth: true }

                    // Settings button
                    Button {
                        id: settingsBtn
                        icon.source: "img/settings_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                        icon.width: 24
                        icon.height: 24
                        icon.color: isDarkTheme ? "#fff" : "#333"
                        width: 40
                        height: 40
                        flat: true
                        
                        // Custom background with hover effect
                        background: Rectangle {
                            color: "transparent"
                            radius: 6
                            border.color: parent.hovered ? (root.isDarkTheme ? "#666" : "#ccc") : "transparent"
                        }
                        
                        // Tooltip
                        hoverEnabled: true
                        ToolTip.delay: 500
                        ToolTip.timeout: 5000
                        ToolTip.visible: hovered
                        ToolTip.text: "Settings"
                        
                        onClicked: settingsDialog.open()
                    }

                    // Info button
                    Button {
                        icon.source: "img/info_512dp_E3E3E3_FILL0_wght300_GRAD0_opsz48.png"
                        icon.width: 24; icon.height: 24
                        width: 40; height: 40
                        icon.color: isDarkTheme ? "#fff" : "#333"
                        flat: true
                        background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? (root.isDarkTheme ? "#666" : "#ccc") : "transparent" }
                        hoverEnabled: true
                        ToolTip.visible: hovered; ToolTip.text: "About SOPHYSM"; ToolTip.delay: 500; ToolTip.timeout: 5000
                        onClicked: aboutDialog.open()
                    }
                }
            }
        }
        
        // === MAIN AREA: GRID 3x2 ===
        Rectangle {
            id: mainArea
            width: parent.width - sidebar.width
            height: parent.height
            color: isDarkTheme ? "#121212" : "#fafafa"
            GridLayout {
                anchors.fill: parent
                anchors.margins: 20
                columns: 3; rows: 2; columnSpacing: 20; rowSpacing: 20
                Common.ImagePanel { id: panelInput; title: "1. Input"; isDarkTheme: root.isDarkTheme; Layout.fillWidth: true; Layout.fillHeight: true; onExpand: function(path, title) { expandImage(path, title) } }
                Common.ImagePanel { id: panelSegmented; title: "2. Segmented"; isDarkTheme: root.isDarkTheme; Layout.fillWidth: true; Layout.fillHeight: true; onExpand: function(path, title) { expandImage(path, title) } }
                Common.ImagePanel { id: panelVertices; title: "3. Vertices"; isDarkTheme: root.isDarkTheme; Layout.fillWidth: true; Layout.fillHeight: true; onExpand: function(path, title) { expandImage(path, title) } }
                Common.ImagePanel { id: panelGraph; title: "4. Graph"; isDarkTheme: root.isDarkTheme; Layout.fillWidth: true; Layout.fillHeight: true; onExpand: function(path, title) { expandImage(path, title) } }
                Common.ImagePanel { id: panelOverlay; title: "5. Overlay"; isDarkTheme: root.isDarkTheme; Layout.fillWidth: true; Layout.fillHeight: true; onExpand: function(path, title) { expandImage(path, title) } }
                Common.ImagePanel { id: panelVoronoi; title: "6. Voronoi"; isDarkTheme: root.isDarkTheme; Layout.fillWidth: true; Layout.fillHeight: true; onExpand: function(path, title) { expandImage(path, title) } }
            }
        }
    }
    
    // ================= TIMER: POLLING =================
    Timer {
        id: jobPoller
        interval: 500
        repeat: true
        running: false

        onTriggered: {
            var result = Julia.check_job_status();
            
            if (result === "" || result === undefined) return;
            
            jobPoller.stop();

            if (result === "ERROR" || result === "ERROR_TIMEOUT") {
                Julia.log_message("@error", "Segmentation failed or timed out.");
                segmentButton.enabled = true;
                segmentButton.text = "▶ Segment";
                return;
            }

            var segPath = result;
            Julia.log_message("@info", "Segmentation completed: " + segPath);

            var basePath = segPath;
            if (basePath.endsWith("_seg.png")) {
                basePath = basePath.slice(0, -8);
            } else if (basePath.endsWith(".png")) {
                basePath = basePath.slice(0, -4);
            }

            Julia.log_message("@info", "Base path for outputs: " + basePath);

            var ts = "?t=" + Date.now();

            panelSegmented.imageItem.source = "file://" + segPath + ts;
            panelVertices.imageItem.source = "file://" + basePath + "_graph_vertex.png" + ts;
            panelGraph.imageItem.source = "file://" + basePath + "_graph_edges.png" + ts;
            panelOverlay.imageItem.source = "file://" + basePath + "_graph_edges_orig.png" + ts;
            panelVoronoi.imageItem.source = "file://" + basePath + "_voronoi_orig.png" + ts;

            for (var i = 0; i < projectImages.length; i++) {
                if (projectImages[i].path === currentImage) {
                    projectImages[i].hasOutput = true;
                    break;
                }
            }
            projectImages = projectImages.concat([]);

            tessellateButton.enabled = true;
            if (workflowStep === 3) workflowStep = 4;
            
            segmentButton.enabled = true;
            segmentButton.text = "▶ Segment";
            
            Julia.log_message("@info", "All output images loaded. Ready for tessellation.");
        }
    }
    
    // ================= DIALOGS =================
    Dialogs.Download {
        id: downloadDialog
        workspaceDir: root.workspaceDir
        onDownloadRequested: function(collections, targetDir) {
            for (var i = 0; i < collections.length; i++) {
                Julia.log_message("@info", "Downloading: " + collections[i])
                Julia.download_single_slide_from_collection(collections[i], targetDir)
            }
        }
        onDownloadCanceled: { Julia.log_message("@info", "Download canceled") }
    }
    Dialogs.Settings {
        id: settingsDialog
        workspaceDir: root.workspaceDir
        isDarkTheme: root.isDarkTheme
        Component.onCompleted: {
            segmentationMethod = root.segmentationMethod
        }
        onSettingsApplied: { Julia.log_message("@info", "Settings applied") }
    }
    Dialogs.About { id: aboutDialog }
    
    FolderDialog {
        id: workspaceDialog
        title: "Select Workspace Directory"
        onAccepted: {
            workspaceDir = selectedFolder.toString().slice(7)
            propmap.workspace_dir = workspaceDir
            downloadDialog.workspaceDir = workspaceDir
            settingsDialog.workspaceDir = workspaceDir
            Julia.log_message("@info", "Workspace: " + workspaceDir)
        }
    }
    
    Dialog {
        id: newProjectDialog
        title: "New Project"
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 320
        height: 180
        background: Rectangle {
            color: isDarkTheme ? "#1e1e1e" : "#fff"
            border.color: isDarkTheme ? "#444" : "#ccc"
            radius: 8
        }
        
        onOpened: {
            projectNameField.forceActiveFocus()
        }
        
        contentItem: ColumnLayout {
            spacing: 12
            anchors.margins: 16
            
            Label {
                text: "Project Name:"
                color: isDarkTheme ? "#fff" : "#333"
            }
            
            TextField {
                id: projectNameField
                Layout.fillWidth: true
                placeholderText: "My_Analysis_01"
                focus: true
                selectByMouse: true
                cursorVisible: true
                
                background: Rectangle {
                    color: isDarkTheme ? "#333" : "#fff"
                    border.color: isDarkTheme ? "#555" : "#ccc"
                    border.width: 1
                    radius: 4
                }
                
                validator: RegularExpressionValidator {
                    regularExpression: /^[a-zA-Z0-9_\-\.\s]+$/
                }
            }
            
            RowLayout {
                Layout.topMargin: 8
                Item { Layout.fillWidth: true }
                Common.Button {
                    text: "Cancel"
                    buttonHeight: 30
                    onClicked: newProjectDialog.close()
                }
                Common.Button {
                    text: "Create"
                    buttonHeight: 30
                    isHighlighted: true
                    enabled: projectNameField.text.length > 0
                    onClicked: {
                        if (projectNameField.text && workspaceDir) {
                            createProject(projectNameField.text)
                            newProjectDialog.close()
                        }
                    }
                }
            }
        }
    }
    
    Dialog {
        id: expandImageDialog
        modal: true
        width: Math.min(root.width * 0.9, 1200)
        height: Math.min(root.height * 0.9, 800)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        title: expandImageTitle
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        visible: false
        
        background: Rectangle {
            color: isDarkTheme ? "#1e1e1e" : "#fff"
            border.color: isDarkTheme ? "#444" : "#ccc"
            radius: 8
        }
        
        header: ToolBar {
            background: Rectangle { color: "transparent" }
            contentItem: RowLayout {
                spacing: 12
                Label {
                    id: expandImageTitle
                    text: "Preview"
                    font.bold: true
                    font.pixelSize: 14
                    color: isDarkTheme ? "#fff" : "#333"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Button {
                    text: "✕"
                    font.pixelSize: 16
                    flat: true
                    onClicked: expandImageDialog.close()
                }
            }
        }
        
        contentItem: Rectangle {
            color: isDarkTheme ? "#121212" : "#fafafa"
            radius: 4
            
            Image {
                id: expandedImage
                anchors.fill: parent
                anchors.margins: 12  
                fillMode: Image.PreserveAspectFit
                
                asynchronous: false
                cache: true
                clip: true
                smooth: true
                
                onStatusChanged: {
                    if (status === Image.Error) {
                        console.error("❌ Image load ERROR:", expandedImage.source);
                        Julia.log_message("@error", "QML Image Error: " + expandedImage.source);
                    } else if (status === Image.Ready) {
                        console.log("✅ Image loaded:", expandedImage.source, 
                                    "Size:", expandedImage.paintedWidth, "x", expandedImage.paintedHeight);
                    } else if (status === Image.Loading) {
                        console.log("⏳ Loading:", expandedImage.source);
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (expandedImage.fillMode === Image.PreserveAspectFit) {
                            expandedImage.fillMode = Image.Pad
                            expandedImage.sourceSize = Qt.size(0, 0)
                        } else {
                            expandedImage.fillMode = Image.PreserveAspectFit
                        }
                    }
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                }
            }
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 16
                color: isDarkTheme ? "#333333cc" : "#ffffffcc"
                radius: 6
                Label {
                    anchors.margins: 8
                    text: "🔍 Click per zoom 1:1 / fit"
                    font.pixelSize: 10
                    color: isDarkTheme ? "#ddd" : "#333"
                }
            }
        }
        
        onOpened: {
            if (!expandImagePath || expandImagePath === "") {
                console.error("❌ expandImagePath is empty!");
                return;
            }
            
            console.log("🔍 Opening expanded view for:", expandImagePath);
            Julia.log_message("@info", "Expanding: " + expandImagePath);
            
            try {
                var resolved = Julia.get_image_for_expanded_view(expandImagePath);
                console.log("🔍 Julia returned:", resolved);
                
                var finalSource = resolved;
                if (!resolved.startsWith("file://")) {
                    finalSource = Qt.resolvedUrl(resolved).toString();
                    console.log("🔍 Converted to Qt URL:", finalSource);
                }
                
                finalSource = finalSource + "?t=" + Date.now();
                console.log("🔍 Setting source:", finalSource);
                
                expandedImage.source = "";  // Reset to trigger reload
                expandedImage.source = finalSource;
                
                expandImageTitle.text = expandImageTitleBase + " — " + expandImagePath.split('/').pop();
                
            } catch (e) {
                console.error("❌ Error in onOpened:", e);
                Julia.log_message("@error", "QML onOpened error: " + e);
            }
        }
        
        onClosed: {
            expandedImage.source = "";  // Libera memoria
            console.log("🔍 Dialog closed, image source cleared");
        }
    }
    
    FolderDialog {
        id: openProjectDialog
        title: "Open Project Folder"
        onAccepted: { openProject(selectedFolder.toString().slice(7)); }
    }
    
    FileDialog {
        id: addImageDialog
        title: "Select Image File"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.tiff *.tif)"]
        onAccepted: { addImageToProject(selectedFile.toString().slice(7)); }
    }
    
    Menu {
        id: imageSourceMenu
        MenuItem { text: "📁 From Local File"; onTriggered: addImageDialog.open() }
        MenuItem { text: "☁️ From TCGA Collection"; onTriggered: downloadDialog.open() }
    }

    Dialogs.SegmentationParams {
        id: segmentationDialog
        segmentationMethod: root.segmentationMethod

        onSettingsApplied: {
            root.segmentationMethod = segmentationMethod
            propmap.segmentation_method = segmentationMethod
            updateWorkflowStep()
        }
    }
    
    // ================= FUNCTIONS =================
    function createProject(name) {
        if (!workspaceDir) { Julia.log_message("@error", "Set workspace first!"); return; }
        var projPath = Julia.create_project_dir(name);
        currentProject = name; projectImages = []; currentImage = "";
        Julia.log_message("@info", "Project created: " + projPath); updateWorkflowStep();
    }
    
    function openProject(path) {
        currentProject = path.split('/').pop();
        var images = Julia.scan_project_images(path);
        
        var newImages = [];
        for (var i = 0; i < images.length; i++) {
            var name = images[i].split('/').pop();
            newImages.push({name: name, path: images[i], hasOutput: false});
        }
        projectImages = newImages;
        currentImage = "";
        
        if (newImages.length > 0) {
            var firstPath = newImages[0].path;
            var outputs = Julia.check_existing_outputs(firstPath);
            
            if (outputs.segmented) setSource(panelSegmented.imageItem, outputs.segmented);
            if (outputs.graphVertex) setSource(panelVertices.imageItem, outputs.graphVertex);
            if (outputs.graphEdges) setSource(panelGraph.imageItem, outputs.graphEdges);
            if (outputs.overlay) setSource(panelOverlay.imageItem, outputs.overlay);
            if (outputs.voronoi) setSource(panelVoronoi.imageItem, outputs.voronoi);
            
            if (outputs.segmented) {
                tessellateButton.enabled = true;
                if (workflowStep < 4) workflowStep = 4;
                newImages[0].hasOutput = true;
            }
        }
        
        projectImages = newImages;
        Julia.log_message("@info", "Opened project: " + currentProject + " (" + images.length + " images)");
        updateWorkflowStep();
    }
    
    function addImageToProject(sourceImagePath) {
        if (!currentProject || !workspaceDir) {
            Julia.log_message("@error", "No active project to add image to.");
            return;
        }
        
        var projectFolderPath = workspaceDir + "/" + currentProject;
        var localImagePath = Julia.copy_image_to_project(sourceImagePath, projectFolderPath);
        var name = localImagePath.split('/').pop();
        
        for (var i = 0; i < projectImages.length; i++) {
            if (projectImages[i].name === name) {
                currentImage = localImagePath;
                loadCurrentImage();
                updateWorkflowStep();
                return;
            }
        }
        
        var newItem = {
            name: name, 
            path: localImagePath,
            hasOutput: false
        };
        projectImages = projectImages.concat([newItem]);
        
        currentImage = localImagePath;
        loadCurrentImage();
        updateWorkflowStep();
        
        Julia.log_message("@info", "Image added to project: " + name);
    }
    
    function loadCurrentImage() {
        if (!currentImage) return;
        
        var resolved = Julia.resolve_image_for_qml(currentImage);
        panelInput.imageItem.source = "file://" + resolved + "?t=" + Date.now();
        
        panelSegmented.imageItem.source = ""; 
        panelVertices.imageItem.source = "";
        panelGraph.imageItem.source = ""; 
        panelOverlay.imageItem.source = ""; 
        panelVoronoi.imageItem.source = "";
        tessellateButton.enabled = false;
    }
    
    function expandImage(path, title) {
        if (!path || path === "") {
            Julia.log_message("@warn", "expandImage: empty path");
            return;
        }
        
        expandImagePath = path;
        expandImageTitleBase = title || "Preview";
        
        Julia.log_message("@info", "Opening expanded view: " + title + " — " + path);
        expandImageDialog.open();
    }
}
