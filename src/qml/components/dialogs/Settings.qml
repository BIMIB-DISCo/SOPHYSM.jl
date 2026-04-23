import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import jlqml
import "../common" as Common

Item {
    id: root

    property string workspaceDir: ""
    property bool isDarkTheme: true
    property bool hasChanges: false

    signal settingsApplied()

    function open() {
        workspaceDirLabel.text = root.workspaceDir
        themeSwitch.checked = root.isDarkTheme
        settingsPopup.open()
    }

    function close() {
        settingsPopup.close()
    }

    FolderDialog {
        id: folderDialog
        title: "Select Workspace Directory"

        onAccepted: {
            var path = selectedFolder.toString().slice(7)
            root.workspaceDir = path
            workspaceDirLabel.text = path
            root.hasChanges = true
        }
    }

    Popup {
        id: settingsPopup
        width: 500
        height: 300
        modal: true
        dim: true
        anchors.centerIn: Overlay.overlay

        background: Rectangle {
            color: "#1E1E1E"
            radius: 10
            border.color: "#333"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Common.DialogHeader {
                title: "Settings"
                description: "Application configuration"
            }

            // THEME
            RowLayout {
                Layout.fillWidth: true

                Label { text: "Dark Theme"; color: "#fff" }

                Item { Layout.fillWidth: true }

                Switch {
                    id: themeSwitch
                    checked: root.isDarkTheme
                    onToggled: {
                        root.isDarkTheme = checked
                        root.hasChanges = true
                    }
                }
            }

            // WORKSPACE
            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    Layout.fillWidth: true

                    Label { text: "Workspace"; color: "#fff" }

                    Label {
                        id: workspaceDirLabel
                        text: root.workspaceDir
                        color: "#aaa"
                        wrapMode: Text.WordWrap
                    }
                }

                Common.Button {
                    text: "Change"
                    onClicked: folderDialog.open()
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Common.Button {
                    text: "Close"
                    onClicked: {
                        root.settingsApplied()
                        settingsPopup.close()
                    }
                }
            }
        }
    }
}