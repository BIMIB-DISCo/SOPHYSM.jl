import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import org.julialang

ApplicationWindow {
    font.family: "Georgia"
    width: 1000
    height: 700
    minimumWidth: 1000
    minimumHeight: 700
    visible: true
    title: qsTr("SOPHYSM")
    id : mainWindow

    // Components
    MessageDialog {
        id: downloadMessageDialog
        text: "Download the selected collections on " + propmap.workspace_dir + "?"
        informativeText: "Download may take several time, continue anyway?"
        buttons: MessageDialog.Yes | MessageDialog.Cancel
        onButtonClicked: function (button, role) {
            switch (button) {
            case MessageDialog.Yes:
                var collectionsToDownload = []
                // Iterate Collections selected
                for (var i = 0; i < checkBoxColumn.children.length; i++) {
                    var child = checkBoxColumn.children[i]
                    if (child instanceof CheckBox && child.checked) {
                        console.log("starting download...", child.objectName, propmap.workspace_dir)
                        Julia.download_single_slide_from_collection(child.objectName, propmap.workspace_dir)
                        collectionsToDownload.push(child.objectName)
                    }
                }
                console.log("collection selected", collectionsToDownload)
                downloadPopup.close()
                this.close()
                break;
            case MessageDialog.Cancel:
                downloadPopup.close()
                this.close()
            }
        }
    }

    // Folder Dialog to Select a new Workspace
    FolderDialog {
        id: folderDialog
        title: "Please choose your new Workspace Folder"
        onAccepted: {
            // Parsing the selectedFolder with "file://" removed
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(7);
        }
        onRejected: {
            console.log("Canceled");
        }
    }

    //dropdown menu to display the application settings
    Menu {
        id: dropdownMenu
        width: 200

        MenuItem {
            text: "Change Directory"
            onClicked: folderDialog.open()
        }

        MenuItem {
            text: "test"
            onClicked: {
                console.log("test onClicked")
            }

        }

        MenuItem {
            text: "Item 3"
            onClicked: console.log("Item 3 selected")
        }
    }


    // Popup window for downloading histopathology collection from TCGA
    Popup {
        id: downloadPopup
        padding: 10
        width: 900
        height: 380
        x: 50
        y: 50

        enter: Transition {
        NumberAnimation { 
            property: "scale"; 
            from: 0.0; to: 1.0 
            duration: 100}
        }

        ScrollView {
            id: scrollView
            // scrollbar is 15px large
            width: 900
            height: 365
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOn

            ColumnLayout {
                Label {
                    text: "Select the collections you want to download"
                    width: parent.width
                }

                Column {
                    id: checkBoxColumn
                    spacing: 5
                    CheckBox {
                        id: brca
                        objectName: "brca"
                        text: qsTr("TCGA-BRCA = Breast Invasive Carcinoma (Breast)")
                    }
                    CheckBox {
                        id: ov
                        objectName: "ov"
                        text: qsTr("TCGA-OV = Ovarian Serous Cystadenocarcinoma (Ovary)")
                    }
                    CheckBox {
                        id: luad
                        objectName: "luad"
                        text: qsTr("TCGA-LUAD = Lung Adenocarcinoma (Bronchus and Lung)")
                    }
                    CheckBox {
                        id: ucec
                        objectName: "ucec"
                        text: qsTr("TCGA-UCEC = Uterine Corpus Endometrial Carcinoma (Corpus uteri)")
                    }
                    CheckBox {
                        id: gbm
                        objectName: "gbm"
                        text: qsTr("TCGA-GBM = Glioblastoma Multiforme (Brain)")
                    }
                    CheckBox {
                        id: hsnc
                        objectName: "hsnc"
                        text: qsTr("TCGA-HSNC = Head and Neck Squamous Cell Carcinoma (Larynx, Lip, Tonsil, Gum, Other and unspecified parths of mouth)")
                    }
                    CheckBox {
                        id: kirc
                        objectName: "kirc"
                        text: qsTr("TCGA-KIRC = Kidney Renal Clear Cell Carcinoma (Kidney)")
                    }
                    CheckBox {
                        id: lgg
                        objectName: "lgg"
                        text: qsTr("TCGA-LGG = Brain Lower Grade Glioma (Brain)")
                    }
                    CheckBox {
                        id: lusc
                        objectName: "lusc"
                        text: qsTr("TCGA-LUSC = Lung Squamous Cell Carcinoma (Bronchus and lung)")
                    }
                    CheckBox {
                        id: tcha
                        objectName: "tcha"
                        text: qsTr("TCGA-TCHA = Thyroid Carcinoma (Thyroid gland)")
                    }
                    CheckBox {
                        id: prad
                        objectName: "prad"
                        text: qsTr("TCGA-PRAD = Prostate Adenocarcinoma (Prostate gland)")
                    }
                    CheckBox {
                        id: skcm
                        objectName: "skcm"
                        text: qsTr("TCGA-SKCM = Skin Cutaneous Melanoma (Skin)")
                    }
                    CheckBox {
                        id: coad
                        objectName: "coad"
                        text: qsTr("TCGA-COAD = Colon Adenocarcinoma (Colon)")
                    }
                    CheckBox {
                        id: stad
                        objectName: "stad"
                        text: qsTr("TCGA-STAD = Stomach Adenocarcinoma (Stomach)")
                    }
                    CheckBox {
                        id: blca
                        objectName: "blca"
                        text: qsTr("TCGA-BLCA = Bladder Urothelial Carcinoma (Bladder)")
                    }
                    CheckBox {
                        id: lihc
                        objectName: "lihc"
                        text: qsTr("TCGA-LIHC = Liver Hepatocellular Carcinoma (Liver and intrahepatic bile ducts)")
                    }
                    CheckBox {
                        id: cesc
                        objectName: "cesc"
                        text: qsTr("TCGA-CESC = Cervical Squamous Cell Carcinoma and Endocervical Adenocarcinoma (Cervix uteri)")
                    }
                    CheckBox {
                        id: kirp
                        objectName: "kirp"
                        text: qsTr("TCGA-KIRP = Kidney Renal Papillary Cell Carcinoma (Kidney)")
                    }
                    CheckBox {
                        id: sarc
                        objectName: "sarc"
                        text: qsTr("TCGA-SARC = Sarcoma (Various)")
                    }
                    CheckBox {
                        id: esca
                        objectName: "esca"
                        text: qsTr("TCGA-ESCA = Esophageal Carcinoma (Esophagus)")
                    }
                    CheckBox {
                        id: paad
                        objectName: "paad"
                        text: qsTr("TCGA-PAAD = Pancreatic Adenocarcinoma (Pancreas)")
                    }
                    CheckBox {
                        id: read
                        objectName: "read"
                        text: qsTr("TCGA-READ = Rectum Adenocarcinoma (Rectum)")
                    }
                    CheckBox {
                        id: pcpg
                        objectName: "pcpg"
                        text: qsTr("TCGA-PCPG = Pheochromocytoma and Paraganglioma (Adrenal gland)")
                    }
                    CheckBox {
                        id: tgct
                        objectName: "tgct"
                        text: qsTr("TCGA-TGCT = Testicular Germ Cell Tumors (Testis)")
                    }
                    CheckBox {
                        id: thym
                        objectName: "thym"
                        text: qsTr("TCGA-THYM = Thymoma (Thymus)")
                    }
                    CheckBox {
                        id: acc
                        objectName: "acc"
                        text: qsTr("TCGA-ACC = Adrenocortical Carcinoma - Adenomas and Adenocarcinomas (Adrenal gland)")
                    }
                    CheckBox {
                        id: meso
                        objectName: "meso"
                        text: qsTr("TCGA-MESO = Mesothelioma (Heart, mediastinum and pleura)")
                    }
                    CheckBox {
                        id: uvm
                        objectName: "uvm"
                        text: qsTr("TCGA-UVM = Uveal Melanoma (Eye and adnexa)")
                    }
                    CheckBox {
                        id: kich
                        objectName: "kich"
                        text: qsTr("TCGA-KICH = Kidney Chromophobe (Kidney)")
                    }
                    CheckBox {
                        id: ucs
                        objectName: "ucs"
                        text: qsTr("TCGA-UCS = Uterine Carcinosarcoma (Uterus, NOS)")
                    }
                    CheckBox {
                        id: chol
                        objectName: "chol"
                        text: qsTr("TCGA-CHOL = Cholangiocarcinoma (Liver and intrahepatic bile ducts, Other and unspecified part of biliary track)")
                    }
                    CheckBox {
                        id: dlbc
                        objectName: "dlbc"
                        text: qsTr("TCGA-DLBC = Lymphoid Neoplasm Diffuse Large B-cell Lymphoma (Various)")
                    }

                    Rectangle{
                        height: 30
                        color: "transparent"
                        width: parent.width

                       Button {
                            id: downloadCollectionsButton
                            text: "Download collections"
                            anchors{
                                bottomMargin: 5
                                left: parent.left
                                bottom: parent.bottom
                            }
                             onClicked: {
                                downloadMessageDialog.open()
                            }

                        }

                        Button {
                            id: closePopupButton
                            text: "Cancel"
                            anchors{
                                topMargin: 5
                                bottomMargin: 5
                                right: parent.right
                                bottom: parent.bottom
                            }
                            //Close the popup
                            onClicked: downloadPopup.close()
                        }
                    }
                }
            }
        }
    }


    // Application
    Column {
        id: verticalBar
        width: 40
        height: parent.height

        // explorer
        Button {
            id: explorerButton
            icon.source: "img/explorer.png"
            width: parent.width
            height: parent.width

            // on hover tooltip
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
                downloadPopup.open();
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
        width: parent.width
        height: parent.height
        anchors {
            left: verticalBar.right
        }

        // handle to resize the window
        handle: Rectangle {
            id: handleDelegate
            implicitWidth: 3
            color: SplitHandle.pressed ? "#0984e3"
                : (SplitHandle.hovered ? Qt.lighter("lightblue", 1.1) : "#b2bec3")
        }

        // folder
        Rectangle {
            id: folder
            color: "#b2bec3"
            implicitWidth: 200
            SplitView.minimumWidth: splitView.width / 5
            SplitView.maximumWidth: splitView.width * 3 / 4

            // current workspace
            Column {
                Label {
                    padding: 5
                    color: "black"
                    text: "Current workspace:"
                    font.pixelSize: 16
                }
                Label {
                    padding: 5
                    color: "black"
                    text: propmap.workspace_dir
                    font.pixelSize: 12
                }
            }
        }

        Rectangle {
            id: viewer
            width: stackLayout.width * 3 / 4
            height: stackLayout.height

            anchors.left: folder.right

            // tabBar
            TabBar {
                id: tabBar
                width: parent.width
                height: 40

                TabButton {
                    id: viewButton
                    width: 100
                    height: 42

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
                    width: 100
                    height: 42

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
                    width: 100 
                    height: 42
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
                    width: 100
                    height: 42
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
                }

                // Segmentation window
                Item {
                    Rectangle{
                        color: "lime"
                        anchors.fill: parent
                    }
                    id: segmentationTab
                }

                // Tessellation window
                Item {

                    Rectangle{
                        color: "yellow"
                        width: 30
                        height: 30
                    }
                    id: tessellationTab
                }

                // Simulation window
                Item {
                    Rectangle{
                        color: "green"
                        width: 30
                        height: 30
                    }
                    id: simulationTab
                }
            }
        }
    }
}
