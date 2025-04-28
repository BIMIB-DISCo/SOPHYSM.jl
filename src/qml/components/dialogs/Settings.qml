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
    
    signal settingsApplied()
    signal settingsCanceled()
    
    function open() {
        root.hasChanges = false;
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
        }
        
        onRejected: {
            Julia.log_message("@info", "Canceled model file selection");
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
                        isHighlighted: false
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
                        settingsPopup.close()
                    }
                }
            }
        }
    }
}
