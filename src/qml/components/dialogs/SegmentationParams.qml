import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import jlqml
import "../common" as Common

Item {
    id: root

    property string segmentationMethod: ""
    property string modelBsonPath: ""
    property string cellposeJlOnnxPath: ""

    // graph parameters
    property real thresholdGray: 0.5
    property real thresholdMarker: 0.3
    property real minThreshold: 50
    property real maxThreshold: 1000

    // cellpose / cellpose_jl parameters
    property real cellposeDiameter: 0
    property real cellposeFlowThreshold: 0.4
    property real cellposeCellprobThreshold: 0
    property real cellposeMinSize: 15
    property bool cellposeInvert: false
    property bool cellposeAugment: false
    property bool cellposeCacheModels: false
    property int cellposeMaxCachedModels: 5
    property string cellposePretrainedModel: ""

    property bool hasChanges: false

    signal settingsApplied()

    function open() {
        settingsPopup.open()
    }

    // FileDialog for JNet (BSON)
    FileDialog {
        id: bsonFileDialog
        title: "Select JNet Model File"
        nameFilters: ["BSON files (*.bson)"]
        onAccepted: {
            root.modelBsonPath = selectedFile.toString().slice(7)
        }
    }

    // FileDialog for cellpose_jl (ONNX)
    FileDialog {
        id: onnxFileDialog
        title: "Select Cellpose.jl ONNX Model"
        nameFilters: ["ONNX files (*.onnx)", "All files (*)"]
        onAccepted: {
            root.cellposeJlOnnxPath = selectedFile.toString().slice(7)
        }
    }

    Popup {
        id: settingsPopup
        width: 900
        height: 550
        modal: true
        dim: true
        anchors.centerIn: Overlay.overlay

        background: Rectangle {
            color: "#1E1E1E"
            radius: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Common.DialogHeader {
                title: "Segmentation Parameters"
                description: "Configure segmentation method and parameters"
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    width: parent.width
                    spacing: 20

                    // === METHOD SELECTION ===
                    RowLayout {
                        spacing: 20

                        Common.CheckBox {
                            text: "JNet"
                            checked: root.segmentationMethod === "jnet"
                            onCheckedChanged: if (checked) root.segmentationMethod = "jnet"
                        }

                        Common.CheckBox {
                            text: "Graph"
                            checked: root.segmentationMethod === "graph"
                            onCheckedChanged: if (checked) root.segmentationMethod = "graph"
                        }

                        Common.CheckBox {
                            text: "Cellpose"
                            checked: root.segmentationMethod === "cellpose"
                            onCheckedChanged: if (checked) root.segmentationMethod = "cellpose"
                        }

                        Common.CheckBox {
                            text: "Cellpose.jl"
                            checked: root.segmentationMethod === "cellpose_jl"
                            onCheckedChanged: if (checked) root.segmentationMethod = "cellpose_jl"
                        }
                    }

                    // === GRAPH PARAMETERS ===
                    Common.ParamCard {
                        visible: root.segmentationMethod === "graph"
                        title: "Graph Segmentation"
                        description: "Threshold-based segmentation using graph connectivity"

                        Common.ParamSlider {
                            label: "Gray Threshold"
                            value: root.thresholdGray
                            from: 0; to: 1
                            onValueChanged: root.thresholdGray = value
                        }

                        Common.ParamSlider {
                            label: "Marker Threshold"
                            value: root.thresholdMarker
                            from: 0; to: 1
                            onValueChanged: root.thresholdMarker = value
                        }

                        Common.ParamSlider {
                            label: "Min Threshold"
                            value: root.minThreshold
                            from: 1; to: 1000
                            decimals: 0
                            onValueChanged: root.minThreshold = value
                        }

                        Common.ParamSlider {
                            label: "Max Threshold"
                            value: root.maxThreshold
                            from: 1; to: 10000
                            decimals: 0
                            onValueChanged: root.maxThreshold = value
                        }
                    }

                    // === CELLPOSE (Python) PARAMETERS ===
                    Common.ParamCard {
                        visible: root.segmentationMethod === "cellpose"
                        title: "Cellpose"
                        description: "Deep-learning based segmentation (Python backend)"

                        Common.ParamSlider {
                            label: "Diameter"
                            value: root.cellposeDiameter
                            from: 0; to: 200
                            decimals: 0
                            onValueChanged: root.cellposeDiameter = value
                        }

                        Common.ParamSlider {
                            label: "Flow Threshold"
                            value: root.cellposeFlowThreshold
                            from: 0; to: 2
                            onValueChanged: root.cellposeFlowThreshold = value
                        }

                        Common.ParamSlider {
                            label: "Cellprob Threshold"
                            value: root.cellposeCellprobThreshold
                            from: -10; to: 10
                            onValueChanged: root.cellposeCellprobThreshold = value
                        }

                        Common.ParamSlider {
                            label: "Min Size"
                            value: root.cellposeMinSize
                            from: 0; to: 10000
                            decimals: 0
                            onValueChanged: root.cellposeMinSize = value
                        }

                        RowLayout {
                            spacing: 20

                            Common.CheckBox {
                                text: "Invert"
                                checked: root.cellposeInvert
                                onCheckedChanged: root.cellposeInvert = checked
                            }

                            Common.CheckBox {
                                text: "Augment"
                                checked: root.cellposeAugment
                                onCheckedChanged: root.cellposeAugment = checked
                            }
                        }
                    }

                    // === CELLPOSE.JL PARAMETERS ===
                    Common.ParamCard {
                        visible: root.segmentationMethod === "cellpose_jl"
                        title: "Cellpose.jl"
                        description: "Julia native backend with ONNX model"

                        Common.ParamSlider {
                            label: "Diameter"
                            value: root.cellposeDiameter
                            from: 0; to: 200
                            decimals: 0
                            onValueChanged: root.cellposeDiameter = value
                        }

                        Common.ParamSlider {
                            label: "Flow Threshold"
                            value: root.cellposeFlowThreshold
                            from: 0; to: 2
                            onValueChanged: root.cellposeFlowThreshold = value
                        }

                        Common.ParamSlider {
                            label: "Cellprob Threshold"
                            value: root.cellposeCellprobThreshold
                            from: -10; to: 10
                            onValueChanged: root.cellposeCellprobThreshold = value
                        }

                        Common.ParamSlider {
                            label: "Min Size"
                            value: root.cellposeMinSize
                            from: 0; to: 10000
                            decimals: 0
                            onValueChanged: root.cellposeMinSize = value
                        }

                        RowLayout {
                            spacing: 20

                            Common.CheckBox {
                                text: "Invert"
                                checked: root.cellposeInvert
                                onCheckedChanged: root.cellposeInvert = checked
                            }

                            Common.CheckBox {
                                text: "Augment"
                                checked: root.cellposeAugment
                                onCheckedChanged: root.cellposeAugment = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Layout.topMargin: 8

                            Label {
                                text: "ONNX Model:"
                                color: "#CCCCCC"
                                font.pixelSize: 12
                                Layout.preferredWidth: 100
                            }

                            Label {
                                text: root.cellposeJlOnnxPath || "No model selected"
                                color: "#AAAAAA"
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                font.pixelSize: 12
                            }

                            Common.Button {
                                text: "Browse"
                                buttonHeight: 28
                                onClicked: onnxFileDialog.open()
                            }
                        }
                    }

                    // === JNET MODEL PATH ===
                    Common.ParamCard {
                        visible: root.segmentationMethod === "jnet"
                        title: "Model"
                        description: "Select trained JNet model (.bson)"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Label {
                                text: "Model file:"
                                color: "#CCCCCC"
                                font.pixelSize: 12
                                Layout.preferredWidth: 100
                            }

                            Label {
                                text: root.modelBsonPath || "No model selected"
                                color: "#AAAAAA"
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                font.pixelSize: 12
                            }

                            Common.Button {
                                text: "Browse"
                                buttonHeight: 28
                                onClicked: bsonFileDialog.open()
                            }
                        }
                    }
                }
            }

            // === APPLY BUTTON ===
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Common.Button {
                    text: "Apply"
                    isHighlighted: true
                    onClicked: {
                        propmap["segmentation_method"] = root.segmentationMethod

                        // GRAPH params
                        propmap["threshold_gray"] = root.thresholdGray
                        propmap["threshold_marker"] = root.thresholdMarker
                        propmap["min_threshold"] = root.minThreshold
                        propmap["max_threshold"] = root.maxThreshold

                        // CELLPOSE / CELLPOSE.JL
                        propmap["cellpose_diameter"] = root.cellposeDiameter
                        propmap["cellpose_flow_threshold"] = root.cellposeFlowThreshold
                        propmap["cellpose_cellprob_threshold"] = root.cellposeCellprobThreshold
                        propmap["cellpose_min_size"] = root.cellposeMinSize
                        propmap["cellpose_invert"] = root.cellposeInvert
                        propmap["cellpose_augment"] = root.cellposeAugment
                        propmap["cellpose_cache_models"] = root.cellposeCacheModels
                        propmap["cellpose_max_cached"] = root.cellposeMaxCachedModels
                        propmap["cellpose_pretrained"] = root.cellposePretrainedModel

                        // CELLPOSE.JL ONNX path
                        propmap["cellpose_jl_onnx_path"] = root.cellposeJlOnnxPath

                        // JNet model path
                        propmap["model_bson_path"] = root.modelBsonPath

                        root.settingsApplied()
                        settingsPopup.close()
                    }
                }
            }
        }
    }
}