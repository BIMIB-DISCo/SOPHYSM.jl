import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Dialogs

import org.julialang
import "../common" as Common

Item {
    id: root
    
    property string workspaceDir: ""
    property bool hasChanges: false
    property bool isDarkTheme: true
    property string modelBsonPath: ""
    property bool highlightModelButton: false
    property string segmentationMethod: ""
    
    signal settingsApplied()
    signal settingsCanceled()
    
    function open() {
        root.hasChanges = false;
        if (propmap.model_bson_path && propmap.model_bson_path !== "") {
            root.modelBsonPath = propmap.model_bson_path
            modelPathLabel.text = propmap.model_bson_path
            root.highlightModelButton = false
        }
        
        if (propmap.segmentation_method) {
            root.segmentationMethod = propmap.segmentation_method
            jnetCheckBox.checked = root.segmentationMethod === "jnet"
            graphCheckBox.checked = root.segmentationMethod === "graph"
            tessellationCheckBox.checked = root.segmentationMethod === "tessellation"
        }
        
        settingsPopup.open();
    }
    
    function close() {
        settingsPopup.close();
    }
    
    FileDialog {
        id: modelFileDialog
        title: "Select Model File (.bson)"
        nameFilters: ["BSON files (*.bson)"]
        
        onAccepted: {
            var path = modelFileDialog.selectedFile.toString().slice(7);
            Julia.log_message("@info", "Selected model file: " + path);
            root.modelBsonPath = path;
            modelPathLabel.text = path;
            root.hasChanges = true;
            root.highlightModelButton = false;
        }
        
        onRejected: {
            Julia.log_message("@info", "Canceled model file selection");
        }
    }
    
    FileDialog {
        id: folderDialog
        title: "Select Workspace Directory"
        fileMode: FileDialog.OpenFolder
        
        onAccepted: {
            var path = folderDialog.selectedFolder.toString().slice(7);
            root.workspaceDir = path;
            workspaceDirLabel.text = path;
            root.hasChanges = true;
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
            root.highlightModelButton = false;
        }
    
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 200 }
        }
        
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150 }
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
            
            Common.DialogHeader {
                title: "Settings"
                description: "Configure application settings:"
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 24
                
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
                
                // New segmentation method selection
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
                            source: "../../img/image_24dp_E3E3E3_FILL0_wght300_GRAD0_opsz24.png"
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
                            text: "Choose between neural network (JNet) or threshold-based segmentation."
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
                                        tessellationCheckBox.checked = false
                                        root.hasChanges = true
                                    } else if (!graphCheckBox.checked && !tessellationCheckBox.checked) {
                                        // Ensure at least one option is selected
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
                                        tessellationCheckBox.checked = false
                                        root.hasChanges = true
                                    } else if (!jnetCheckBox.checked && !tessellationCheckBox.checked) {
                                        // Ensure at least one option is selected
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
                                id: tessellationCheckBox
                                text: "Tessellation Method"
                                checked: root.segmentationMethod === "tessellation"
                                onCheckedChanged: {
                                    if (checked) {
                                        root.segmentationMethod = "tessellation"
                                        jnetCheckBox.checked = false
                                        graphCheckBox.checked = false
                                        root.hasChanges = true
                                    } else if (!jnetCheckBox.checked && !graphCheckBox.checked) {
                                        // Ensure at least one option is selected
                                        root.segmentationMethod = ""
                                    }
                                }
                                contentItem: Text {
                                    text: tessellationCheckBox.text
                                    font: tessellationCheckBox.font
                                    opacity: enabled ? 1.0 : 0.3
                                    color: "#FFFFFF"
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: tessellationCheckBox.indicator.width + tessellationCheckBox.spacing
                                }
                            }
                        }
                    }
                }
                
                // Model selection row - only visible when JNet is selected
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
                        
                        Label {
                            text: "Model File:"
                            color: "#FFFFFF"
                            font.bold: true
                        }
                        
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
                        onClicked: {
                            modelFileDialog.open()
                        }
                    }
                }
                
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
                        
                        Label {
                            text: "Current Workspace Directory:"
                            color: "#FFFFFF"
                            font.bold: true
                        }
                        
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
                
                Item {
                    Layout.fillHeight: true
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                Common.Button {
                    text: "Close"
                    onClicked: {
                        if (root.hasChanges) {
                            // Salva il path del modello nel propmap quando si chiude il dialog
                            propmap.model_bson_path = root.modelBsonPath
                            // Salva il metodo di segmentazione
                            propmap.segmentation_method = root.segmentationMethod
                            root.settingsApplied()
                        }
                        settingsPopup.close()
                    }
                }
            }
        }
    }
}
