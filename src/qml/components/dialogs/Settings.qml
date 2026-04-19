import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import jlqml
import "../common" as Common

Item {
    id: root

    property string workspaceDir: ""
    property bool hasChanges: false
    property bool isDarkTheme: true
    property string modelBsonPath: ""
    property bool highlightModelButton: false
    property string segmentationMethod: ""

    // Graph segmentation parameters
    property real thresholdGray: 0.5
    property real thresholdMarker: 0.3
    property real minThreshold: 50.0
    property real maxThreshold: 1000.0

    // Cellpose parameters
    property real cellposeDiameter: 0.0
    property real cellposeFlowThreshold: 0.4
    property real cellposeCellprobThreshold: 0.0
    property real cellposeMinSize: 15.0
    property bool cellposeInvert: false
    property bool cellposeAugment: false
    property bool cellposeCacheModels: true
    property real cellposeMaxCachedModels: 2.0
    property string cellposePretrainedModel: ""

    signal settingsApplied()
    signal settingsCanceled()

    function open() {
        root.hasChanges = false

        // Restore model path
        if (propmap.model_bson_path && propmap.model_bson_path !== "") {
            root.modelBsonPath = propmap.model_bson_path
            modelPathLabel.text = propmap.model_bson_path
            root.highlightModelButton = false
        } else {
            root.modelBsonPath = ""
            modelPathLabel.text = "No model file selected"
        }

        // Restore segmentation method and update checkboxes
        if (propmap.segmentation_method) {
            root.segmentationMethod = propmap.segmentation_method
        } else {
            root.segmentationMethod = ""
        }
        jnetCheckBox.checked = root.segmentationMethod === "jnet"
        graphCheckBox.checked = root.segmentationMethod === "graph"
        cellposeCheckBox.checked = root.segmentationMethod === "cellpose"
        cellposeJLCheckBox.checked = root.segmentationMethod === "cellpose_jl"

        // Restore graph parameters
        if (propmap.threshold_gray !== undefined) root.thresholdGray = propmap.threshold_gray
        if (propmap.threshold_marker !== undefined) root.thresholdMarker = propmap.threshold_marker
        if (propmap.min_threshold !== undefined) root.minThreshold = propmap.min_threshold
        if (propmap.max_threshold !== undefined) root.maxThreshold = propmap.max_threshold

        // Push restored values into fields (so they show updated values)
        thresholdGrayField.text = root.thresholdGray.toFixed(2)
        thresholdMarkerField.text = root.thresholdMarker.toFixed(2)
        minThresholdField.text = root.minThreshold.toFixed(0)
        maxThresholdField.text = root.maxThreshold.toFixed(0)

        // Restore cellpose parameters
        if (propmap.cellpose_diameter !== undefined) root.cellposeDiameter = propmap.cellpose_diameter
        if (propmap.cellpose_flow_threshold !== undefined) root.cellposeFlowThreshold = propmap.cellpose_flow_threshold
        if (propmap.cellpose_cellprob_threshold !== undefined) root.cellposeCellprobThreshold = propmap.cellpose_cellprob_threshold
        if (propmap.cellpose_min_size !== undefined) root.cellposeMinSize = propmap.cellpose_min_size
        if (propmap.cellpose_invert !== undefined) root.cellposeInvert = propmap.cellpose_invert
        if (propmap.cellpose_augment !== undefined) root.cellposeAugment = propmap.cellpose_augment
        if (propmap.cellpose_cache_models !== undefined) root.cellposeCacheModels = propmap.cellpose_cache_models
        if (propmap.cellpose_max_cached_models !== undefined) root.cellposeMaxCachedModels = propmap.cellpose_max_cached_models
        if (propmap.cellpose_pretrained_model !== undefined) root.cellposePretrainedModel = propmap.cellpose_pretrained_model

        // Push restored values into fields (so they show updated values)
        cellposeDiameterField.text = root.cellposeDiameter.toFixed(0)
        cellposeFlowField.text = root.cellposeFlowThreshold.toFixed(2)
        cellposeCellprobField.text = root.cellposeCellprobThreshold.toFixed(1)
        cellposeMinSizeField.text = root.cellposeMinSize.toFixed(0)

        cellposeInvertCheck.checked = root.cellposeInvert
        cellposeAugmentCheck.checked = root.cellposeAugment
        cellposeCacheCheck.checked = root.cellposeCacheModels

        cellposeMaxCachedField.text = root.cellposeMaxCachedModels.toFixed(0)
        cellposePretrainedField.text = root.cellposePretrainedModel

        // Workspace label (if you use propmap for it, add it here; otherwise keep current)
        workspaceDirLabel.text = root.workspaceDir

        settingsPopup.open()
    }

    function close() {
        settingsPopup.close()
    }

    FileDialog {
        id: modelFileDialog
        title: "Select Model File (.bson)"
        nameFilters: ["BSON files (*.bson)"]

        onAccepted: {
            var path = modelFileDialog.selectedFile.toString().slice(7)
            Julia.log_message("@info", "Selected model file: " + path)
            root.modelBsonPath = path
            modelPathLabel.text = path
            root.hasChanges = true
            root.highlightModelButton = false
        }

        onRejected: {
            Julia.log_message("@info", "Canceled model file selection")
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Select Workspace Directory"

        onAccepted: {
            var path = folderDialog.selectedFolder.toString().slice(7)
            root.workspaceDir = path
            workspaceDirLabel.text = path
            root.hasChanges = true
        }
    }

    Popup {
        id: settingsPopup
        padding: 20
        width: 900
        height: 500

        anchors.centerIn: Overlay.overlay
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        // Ripristina l'evidenziazione quando il dialog viene chiuso
        onClosed: {
            root.highlightModelButton = false
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200
            }
            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 200
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 150
            }
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

            // ================= HEADER (FIXED) =================
            Common.DialogHeader {
                title: "Settings"
                description: "Configure application settings:"
            }

            // ================= CONTENT (SCROLLABLE) =================
            ScrollView {
                id: contentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                contentWidth: availableWidth

                ColumnLayout {
                    width: contentScroll.availableWidth
                    spacing: 24

                    // ---------------- THEME ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            color: "#454545"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Image {
                                anchors.centerIn: parent
                                source: "../../img/routine_24dp_E3E3E3_FILL0_wght300_GRAD0_opsz24.png"
                                width: 16
                                height: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: "Application Theme:"
                                color: "#FFFFFF"
                                font.bold: true
                            }

                            Label {
                                text: "Choose between dark and light theme for the application interface."
                                color: "#CCCCCC"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Item {
                            Layout.preferredWidth: 60
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignBottom
                            Layout.rightMargin: 10

                            Switch {
                                id: themeSwitch
                                checked: root.isDarkTheme
                                anchors.centerIn: parent
                                width: 56
                                height: 32

                                onToggled: {
                                    root.isDarkTheme = checked
                                    root.hasChanges = true
                                }

                                indicator: Rectangle {
                                    implicitWidth: 56
                                    implicitHeight: 28
                                    x: themeSwitch.leftPadding
                                    y: themeSwitch.height / 2 - height / 2
                                    radius: 14
                                    color: themeSwitch.checked ? "#444444" : "#AAAAAA"
                                    border.color: themeSwitch.checked ? "#666666" : "#CCCCCC"

                                    Rectangle {
                                        id: toggleIndicator
                                        x: themeSwitch.checked ? parent.width - width - 2 : 2
                                        y: 2
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: themeSwitch.checked ? "#222222" : "#EEEEEE"
                                        border.width: 0

                                        Item {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                        }

                                        Behavior on x {
                                            NumberAnimation { duration: 200 }
                                        }
                                    }
                                }

                                contentItem: Item {}
                            }
                        }
                    }

                    // ---------------- SEGMENTATION METHOD ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            color: "#454545"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Image {
                                anchors.centerIn: parent
                                source: "../../img/tactic_24dp_E3E3E3_FILL0_wght200_GRAD0_opsz24.png"
                                width: 16
                                height: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: "Segmentation Method:"
                                color: "#FFFFFF"
                                font.bold: true
                            }

                            Label {
                                text: "Choose between neural network (JNet) or threshold-based graph segmentation."
                                color: "#CCCCCC"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                spacing: 20
                                Layout.topMargin: 10

                                Common.CheckBox {
                                    id: jnetCheckBox
                                    text: "Neural Network (JNet)"
                                    checked: root.segmentationMethod === "jnet"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.segmentationMethod = "jnet"
                                            graphCheckBox.checked = false
                                            cellposeCheckBox.checked = false
                                            root.hasChanges = true
                                        } else if (!graphCheckBox.checked && !cellposeCheckBox.checked) {
                                            root.segmentationMethod = ""
                                        }
                                    }

                                    contentItem: Text {
                                        text: jnetCheckBox.text
                                        font: jnetCheckBox.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: jnetCheckBox.indicator.width + jnetCheckBox.spacing
                                    }
                                }

                                Common.CheckBox {
                                    id: graphCheckBox
                                    text: "Graph Method"
                                    checked: root.segmentationMethod === "graph"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.segmentationMethod = "graph"
                                            jnetCheckBox.checked = false
                                            cellposeCheckBox.checked = false
                                            root.hasChanges = true
                                        } else if (!jnetCheckBox.checked && !cellposeCheckBox.checked) {
                                            root.segmentationMethod = ""
                                        }
                                    }

                                    contentItem: Text {
                                        text: graphCheckBox.text
                                        font: graphCheckBox.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: graphCheckBox.indicator.width + graphCheckBox.spacing
                                    }
                                }

                                Common.CheckBox {
                                    id: cellposeCheckBox
                                    text: "Cellpose Method"
                                    checked: root.segmentationMethod === "cellpose"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.segmentationMethod = "cellpose"
                                            jnetCheckBox.checked = false
                                            graphCheckBox.checked = false
                                            root.hasChanges = true
                                        } else if (!jnetCheckBox.checked && !graphCheckBox.checked) {
                                            root.segmentationMethod = ""
                                        }
                                    }

                                    contentItem: Text {
                                        text: cellposeCheckBox.text
                                        font: cellposeCheckBox.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: cellposeCheckBox.indicator.width + cellposeCheckBox.spacing
                                    }
                                }
                                Common.CheckBox {
                                    id: cellposeJLCheckBox
                                    text: "Cellpose.jl (Native)"
                                    checked: root.segmentationMethod === "cellpose_jl"
                                    onCheckedChanged: {
                                        if (checked) {
                                            root.segmentationMethod = "cellpose_jl"
                                            jnetCheckBox.checked = false
                                            graphCheckBox.checked = false
                                            cellposeCheckBox.checked = false
                                            root.hasChanges = true
                                        } else if (!jnetCheckBox.checked && !graphCheckBox.checked && !cellposeCheckBox.checked) {
                                            root.segmentationMethod = ""
                                        }
                                    }
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Native Julia implementation. Requires path to ONNX model file in Settings."
                                    
                                    contentItem: Text {
                                        text: cellposeJLCheckBox.text
                                        font: cellposeJLCheckBox.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: cellposeJLCheckBox.indicator.width + cellposeJLCheckBox.spacing
                                    }
                                }
                            }
                        }
                    }

                    // ---------------- GRAPH PARAMETERS ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24
                        visible: root.segmentationMethod === "graph"

                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            color: "#454545"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Image {
                                anchors.centerIn: parent
                                source: "../../img/settings_applications_24dp_E3E3E3_FILL0_wght300_GRAD0_opsz24.png"
                                width: 16
                                height: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                text: "Graph Segmentation Parameters:"
                                color: "#FFFFFF"
                                font.bold: true
                            }

                            GridLayout {
                                columns: 4
                                columnSpacing: 25
                                rowSpacing: 8
                                Layout.topMargin: 12
                                Layout.fillWidth: true

                                Label { text: "Threshold Gray"; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
                                Label { text: "Threshold Marker"; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
                                Label { text: "Min Threshold"; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
                                Label { text: "Max Threshold"; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }

                                // Threshold Gray
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter

                                    TextField {
                                        id: thresholdGrayField
                                        text: root.thresholdGray.toFixed(2)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }

                                        validator: DoubleValidator { bottom: 0.0; top: 1.0; decimals: 2; notation: DoubleValidator.StandardNotation }

                                        onTextChanged: if (acceptableInput) { root.thresholdGray = parseFloat(text); root.hasChanges = true }
                                    }

                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(1.0, root.thresholdGray + 0.01)
                                                root.thresholdGray = val
                                                thresholdGrayField.text = val.toFixed(2)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(0.0, root.thresholdGray - 0.01)
                                                root.thresholdGray = val
                                                thresholdGrayField.text = val.toFixed(2)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }

                                // Threshold Marker
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter

                                    TextField {
                                        id: thresholdMarkerField
                                        text: root.thresholdMarker.toFixed(2)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }

                                        validator: DoubleValidator { bottom: 0.0; top: 1.0; decimals: 2; notation: DoubleValidator.StandardNotation }

                                        onTextChanged: if (acceptableInput) { root.thresholdMarker = parseFloat(text); root.hasChanges = true }
                                    }

                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(1.0, root.thresholdMarker + 0.01)
                                                root.thresholdMarker = val
                                                thresholdMarkerField.text = val.toFixed(2)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(0.0, root.thresholdMarker - 0.01)
                                                root.thresholdMarker = val
                                                thresholdMarkerField.text = val.toFixed(2)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }

                                // Min Threshold
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter

                                    TextField {
                                        id: minThresholdField
                                        text: root.minThreshold.toFixed(0)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }

                                        validator: IntValidator { bottom: 1; top: 1000 }

                                        onTextChanged: if (acceptableInput) { root.minThreshold = parseInt(text); root.hasChanges = true }
                                    }

                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(root.maxThreshold - 1, root.minThreshold + 1)
                                                root.minThreshold = val
                                                minThresholdField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(1, root.minThreshold - 1)
                                                root.minThreshold = val
                                                minThresholdField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }

                                // Max Threshold
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter

                                    TextField {
                                        id: maxThresholdField
                                        text: root.maxThreshold.toFixed(0)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }

                                        validator: IntValidator { bottom: 1; top: 10000 }

                                        onTextChanged: if (acceptableInput) { root.maxThreshold = parseInt(text); root.hasChanges = true }
                                    }

                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(10000, root.maxThreshold + 10)
                                                root.maxThreshold = val
                                                maxThresholdField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(root.minThreshold + 1, root.maxThreshold - 10)
                                                root.maxThreshold = val
                                                maxThresholdField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---------------- CELLPOSE PARAMETERS ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24
                        visible: root.segmentationMethod === "cellpose" || root.segmentationMethod === "cellpose_jl"
                        
                        Label {
                            text: "⚠ Advanced params (flow/cellprob/min_size) are hardcoded in Cellpose.jl internals."
                            color: "#FFA726"
                            font.italic: true
                            font.pixelSize: 11
                            visible: root.segmentationMethod === "cellpose_jl"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
}
                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            color: "#454545"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Image {
                                anchors.centerIn: parent
                                source: "../../img/settings_applications_24dp_E3E3E3_FILL0_wght300_GRAD0_opsz24.png"
                                width: 16
                                height: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label { text: "Cellpose Parameters:"; color: "#FFFFFF"; font.bold: true }

                            Label {
                                text: "Configure Cellpose segmentation. Diameter 0 = auto."
                                color: "#CCCCCC"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }

                            GridLayout {
                                columns: 4
                                columnSpacing: 25
                                rowSpacing: 8
                                Layout.topMargin: 12
                                Layout.fillWidth: true

                                Label { text: "Diameter"; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
                                Label { text: "Flow thr."; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
                                Label { text: "Cellprob thr."; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }
                                Label { text: "Min size"; color: "#CCCCCC"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter }

                                // Diameter
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter
                                    TextField {
                                        id: cellposeDiameterField
                                        text: root.cellposeDiameter.toFixed(0)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }
                                        validator: IntValidator { bottom: 0; top: 10000 }
                                        onTextChanged: if (acceptableInput) { root.cellposeDiameter = parseInt(text); root.hasChanges = true }
                                    }
                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(10000, root.cellposeDiameter + 5)
                                                root.cellposeDiameter = val
                                                cellposeDiameterField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(0, root.cellposeDiameter - 5)
                                                root.cellposeDiameter = val
                                                cellposeDiameterField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }

                                // Flow threshold
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter
                                    TextField {
                                        id: cellposeFlowField
                                        text: root.cellposeFlowThreshold.toFixed(2)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }
                                        validator: DoubleValidator { bottom: 0.0; top: 2.0; decimals: 2; notation: DoubleValidator.StandardNotation }
                                        onTextChanged: if (acceptableInput) { root.cellposeFlowThreshold = parseFloat(text); root.hasChanges = true }
                                    }
                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(2.0, root.cellposeFlowThreshold + 0.05)
                                                root.cellposeFlowThreshold = val
                                                cellposeFlowField.text = val.toFixed(2)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(0.0, root.cellposeFlowThreshold - 0.05)
                                                root.cellposeFlowThreshold = val
                                                cellposeFlowField.text = val.toFixed(2)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }

                                // Cellprob threshold
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter
                                    TextField {
                                        id: cellposeCellprobField
                                        text: root.cellposeCellprobThreshold.toFixed(1)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }
                                        validator: DoubleValidator { bottom: -10.0; top: 10.0; decimals: 1; notation: DoubleValidator.StandardNotation }
                                        onTextChanged: if (acceptableInput) { root.cellposeCellprobThreshold = parseFloat(text); root.hasChanges = true }
                                    }
                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(10.0, root.cellposeCellprobThreshold + 0.2)
                                                root.cellposeCellprobThreshold = val
                                                cellposeCellprobField.text = val.toFixed(1)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(-10.0, root.cellposeCellprobThreshold - 0.2)
                                                root.cellposeCellprobThreshold = val
                                                cellposeCellprobField.text = val.toFixed(1)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }

                                // Min size
                                RowLayout {
                                    spacing: 2
                                    Layout.alignment: Qt.AlignHCenter
                                    TextField {
                                        id: cellposeMinSizeField
                                        text: root.cellposeMinSize.toFixed(0)
                                        Layout.preferredWidth: 55
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }
                                        validator: IntValidator { bottom: 0; top: 100000 }
                                        onTextChanged: if (acceptableInput) { root.cellposeMinSize = parseInt(text); root.hasChanges = true }
                                    }
                                    Column {
                                        spacing: 1
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "+"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.min(100000, root.cellposeMinSize + 5)
                                                root.cellposeMinSize = val
                                                cellposeMinSizeField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                        Button {
                                            width: 18; height: 14
                                            contentItem: Text { text: "-"; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pointSize: 10 }
                                            onClicked: {
                                                var val = Math.max(0, root.cellposeMinSize - 5)
                                                root.cellposeMinSize = val
                                                cellposeMinSizeField.text = val.toFixed(0)
                                                root.hasChanges = true
                                            }
                                            background: Rectangle { color: parent.pressed ? "#666666" : "#444444"; radius: 3 }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 20
                                Layout.topMargin: 10

                                Common.CheckBox {
                                    id: cellposeInvertCheck
                                    text: "Invert"
                                    checked: root.cellposeInvert
                                    onCheckedChanged: { root.cellposeInvert = checked; root.hasChanges = true }
                                    contentItem: Text {
                                        text: cellposeInvertCheck.text
                                        font: cellposeInvertCheck.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: cellposeInvertCheck.indicator.width + cellposeInvertCheck.spacing
                                    }
                                }

                                Common.CheckBox {
                                    id: cellposeAugmentCheck
                                    text: "Augment"
                                    checked: root.cellposeAugment
                                    onCheckedChanged: { root.cellposeAugment = checked; root.hasChanges = true }
                                    contentItem: Text {
                                        text: cellposeAugmentCheck.text
                                        font: cellposeAugmentCheck.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: cellposeAugmentCheck.indicator.width + cellposeAugmentCheck.spacing
                                    }
                                }

                                Common.CheckBox {
                                    id: cellposeCacheCheck
                                    text: "Cache models"
                                    checked: root.cellposeCacheModels
                                    onCheckedChanged: { root.cellposeCacheModels = checked; root.hasChanges = true }
                                    contentItem: Text {
                                        text: cellposeCacheCheck.text
                                        font: cellposeCacheCheck.font
                                        opacity: enabled ? 1.0 : 0.3
                                        color: "#FFFFFF"
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: cellposeCacheCheck.indicator.width + cellposeCacheCheck.spacing
                                    }
                                }
                            }

                            GridLayout {
                                columns: 2
                                columnSpacing: 25
                                rowSpacing: 8
                                Layout.topMargin: 10
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: 10
                                    Layout.fillWidth: true
                                    Label { text: "Max cached models"; color: "#CCCCCC" }
                                    TextField {
                                        id: cellposeMaxCachedField
                                        text: root.cellposeMaxCachedModels.toFixed(0)
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }
                                        validator: IntValidator { bottom: 1; top: 20 }
                                        onTextChanged: if (acceptableInput) { root.cellposeMaxCachedModels = parseInt(text); root.hasChanges = true }
                                    }
                                }

                                RowLayout {
                                    spacing: 10
                                    Layout.fillWidth: true
                                    Label { text: "Pretrained model path"; color: "#CCCCCC" }
                                    TextField {
                                        id: cellposePretrainedField
                                        text: root.cellposePretrainedModel
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        color: "#FFFFFF"
                                        background: Rectangle { color: "#333333"; border.color: "#555555"; border.width: 1; radius: 4 }
                                        placeholderText: "(optional)"
                                        onTextChanged: { root.cellposePretrainedModel = text; root.hasChanges = true }
                                    }
                                }
                            }
                        }
                    }

                    // ---------------- MODEL FILE (JNET ONLY) ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24
                        visible: root.segmentationMethod === "jnet"

                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            color: "#454545"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Image {
                                anchors.centerIn: parent
                                source: "../../img/graph_3_24dp_E3E3E3_FILL0_wght300_GRAD0_opsz24.png"
                                width: 16
                                height: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label { text: "Model File:"; color: "#FFFFFF"; font.bold: true }

                            Label {
                                id: modelPathLabel
                                text: root.modelBsonPath === "" ? "No model file selected" : root.modelBsonPath
                                color: "#CCCCCC"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Common.Button {
                            text: "Select Model"
                            isHighlighted: root.highlightModelButton
                            Layout.alignment: Qt.AlignBottom
                            onClicked: modelFileDialog.open()
                        }
                    }

                    // ---------------- WORKSPACE DIRECTORY ----------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24

                        Rectangle {
                            width: 36
                            height: 36
                            radius: width / 2
                            color: "#454545"
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Image {
                                anchors.centerIn: parent
                                source: "../../img/folder_24dp_E3E3E3_FILL0_wght300_GRAD0_opsz24.png"
                                width: 16
                                height: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label { text: "Current Workspace Directory:"; color: "#FFFFFF"; font.bold: true }

                            Label {
                                id: workspaceDirLabel
                                text: root.workspaceDir
                                color: "#CCCCCC"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }
                        }

                        Common.Button {
                            text: "Change Directory"
                            isHighlighted: false
                            Layout.alignment: Qt.AlignBottom
                            onClicked: {
                                folderDialog.open()
                                root.hasChanges = true
                            }
                        }
                    }

                    // Small bottom padding inside scroll content
                    Item { height: 10 }
                }
            }

            // ================= FOOTER (FIXED) =================
            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Common.Button {
                    text: "Close"
                    onClicked: {
                        if (root.hasChanges) {
                            // Save model + method
                            propmap.model_bson_path = root.modelBsonPath
                            propmap.segmentation_method = root.segmentationMethod

                            // Save graph
                            propmap.threshold_gray = root.thresholdGray
                            propmap.threshold_marker = root.thresholdMarker
                            propmap.min_threshold = root.minThreshold
                            propmap.max_threshold = root.maxThreshold

                            // Save cellpose
                            propmap.cellpose_diameter = root.cellposeDiameter
                            propmap.cellpose_flow_threshold = root.cellposeFlowThreshold
                            propmap.cellpose_cellprob_threshold = root.cellposeCellprobThreshold
                            propmap.cellpose_min_size = root.cellposeMinSize
                            propmap.cellpose_invert = root.cellposeInvert
                            propmap.cellpose_augment = root.cellposeAugment
                            propmap.cellpose_cache_models = root.cellposeCacheModels
                            propmap.cellpose_max_cached_models = root.cellposeMaxCachedModels
                            propmap.cellpose_pretrained_model = root.cellposePretrainedModel

                            root.settingsApplied()
                        }
                        settingsPopup.close()
                    }
                }
            }
        }
    }
}
