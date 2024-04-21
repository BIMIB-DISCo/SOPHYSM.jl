import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import org.julialang

ApplicationWindow {
    font.family: "Roboto"
    width: 1000
    height: 700
    minimumWidth: 1000
    minimumHeight: 700
    visible: true
    title: qsTr("SOPHYSM")
    id : mainWindow

    FolderDialog {
        id: folderDialog
        title: "Please choose your new Workspace Folder"
        onAccepted: {
            // Parsing the selectedFolder with "file:///" removed
            propmap.workspace_dir = folderDialog.selectedFolder.toString().slice(8);
        }
        onRejected: {
            console.log("Canceled");
        }
    }

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
                    spacing: 5
                    CheckBox { text: qsTr("TCGA-BRCA = Breast Invasive Carcinoma (Breast)") }
                    CheckBox { text: qsTr("TCGA-OV = Ovarian Serous Cystadenocarcinoma (Ovary)") }
                    CheckBox { text: qsTr("TCGA-LUAD = Lung Adenocarcinoma (Bronchus and Lung)") }
                    CheckBox { text: qsTr("TCGA-UCEC = Uterine Corpus Endometrial Carcinoma (Corpus uteri)") }
                    CheckBox { text: qsTr("TCGA-GBM = Glioblastoma Multiforme (Brain)") }
                    CheckBox { text: qsTr("TCGA-HSNC = Head and Neck Squamous Cell Carcinoma (Larynx, Lip, Tonsil, Gum, Other and unspecified parths of mouth)") }
                    CheckBox { text: qsTr("TCGA-KIRC = Kidney Renal Clear Cell Carcinoma (Kidney)") }
                    CheckBox { text: qsTr("TCGA-LGG = Brain Lower Grade Glioma (Brain)") }
                    CheckBox { text: qsTr("TCGA-LUSC = Lung Squamous Cell Carcinoma (Bronchus and lung)") }
                    CheckBox { text: qsTr("TCGA-TCHA = Thyroid Carcinoma (Thyroid gland)") }
                    CheckBox { text: qsTr("TCGA-PRAD = Prostate Adenocarcinoma (Prostate gland)") }
                    CheckBox { text: qsTr("TCGA-SKCM = Skin Cutaneous Melanoma (Skin)") }
                    CheckBox { text: qsTr("TCGA-COAD = Colon Adenocarcinoma (Colon)") }
                    CheckBox { text: qsTr("TCGA-STAD = Stomach Adenocarcinoma (Stomach)") }
                    CheckBox { text: qsTr("TCGA-BLCA = Bladder Urothelial Carcinoma (Bladder)") }
                    CheckBox { text: qsTr("TCGA-LIHC = Liver Hepatocellular Carcinoma (Liver and intrahepatic bile ducts)") }
                    CheckBox { text: qsTr("TCGA-CESC = Cervical Squamous Cell Carcinoma and Endocervical Adenocarcinoma (Cervix uteri)") }
                    CheckBox { text: qsTr("TCGA-KIRP = Kidney Renal Papillary Cell Carcinoma (Kidney)") }
                    CheckBox { text: qsTr("TCGA-SARC = Sarcoma (Various)") }
                    CheckBox { text: qsTr("TCGA-ESCA = Esophageal Carcinoma (Esophagus)") }
                    CheckBox { text: qsTr("TCGA-PAAD = Pancreatic Adenocarcinoma (Pancreas)") }
                    CheckBox { text: qsTr("TCGA-READ = Rectum Adenocarcinoma (Rectum)") }
                    CheckBox { text: qsTr("TCGA-PCPG = Pheochromocytoma and Paraganglioma (Adrenal gland)") }
                    CheckBox { text: qsTr("TCGA-TGCT = Testicular Germ Cell Tumors (Testis)") }
                    CheckBox { text: qsTr("TCGA-THYM = Thymoma (Thymus)") }
                    CheckBox { text: qsTr("TCGA-ACC = Adrenocortical Carcinoma - Adenomas and Adenocarcinomas (Adrenal gland)") }
                    CheckBox { text: qsTr("TCGA-MESO = Mesothelioma (Heart, mediastinum and pleura)") }
                    CheckBox { text: qsTr("TCGA-UVM = Uveal Melanoma (Eye and adnexa)") }
                    CheckBox { text: qsTr("TCGA-KICH = Kidney Chromophobe (Kidney)") }
                    CheckBox { text: qsTr("TCGA-UCS = Uterine Carcinosarcoma (Uterus, NOS)") }
                    CheckBox { text: qsTr("TCGA-CHOL = Cholangiocarcinoma (Liver and intrahepatic bile ducts, Other and unspecified part of biliary track)") }
                    CheckBox { text: qsTr("TCGA-DLBC = Lymphoid Neoplasm Diffuse Large B-cell Lymphoma (Various)") }
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
                        }

                        Button {
                            id: closePopupButton
                            text: "Cancel"
                            anchors{
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


    
    Column {
        id: verticalBar
        width: 40
        height: parent.height
        anchors {
            top: tabBar.bottom
        }

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

    // tabBar
    TabBar {
        id: tabBar
        width: parent.width
        contentHeight: 40
        x: 40

        TabButton {
            id: segmentationButton
            text: qsTr("Segmentation")
            width: 100           

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Segmentation Panel")          
        }
        TabButton {
            id: tessellationButton
            text: qsTr("Tessellation")   
            width: 100         

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Tessellation Panel")
        }
        TabButton {
            id: simulationButton
            text: qsTr("Simulation")
            width: 100       

            // on hover tooltip
            hoverEnabled: true
            ToolTip.delay: 500
            ToolTip.timeout: 5000
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Simulation Panel")
        }
    }

        // workspace Item
        SplitView {
            id: splitView
            width: parent.width
            height: parent.height
            anchors {
                top: tabBar.bottom
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

                //stackLayout
                StackLayout {
                    id: stackLayout
                    width: parent.width
                    height: parent.height
                    currentIndex: tabBar.currentIndex

                    Item {
                        Rectangle{
                            color: "lime"
                            anchors.fill: parent
                        }
                        id: segmentationTab
                    }

                    Item {

                        Rectangle{
                            color: "yellow"
                            width: 30
                            height: 30
                        }
                        id: tessellationTab
                    }

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
