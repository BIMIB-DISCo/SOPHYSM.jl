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

    // GRAPH
    property real thresholdGray: 0.5
    property real thresholdMarker: 0.3
    property real minThreshold: 50
    property real maxThreshold: 1000

    // CELLPOSE
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

    FileDialog {
        id: modelFileDialog
        nameFilters: ["BSON files (*.bson)"]

        onAccepted: {
            root.modelBsonPath = selectedFile.toString().slice(7)
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

                    // METHOD
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
                    }

                    // GRAPH
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
                            onValueChanged: root.thresholdMarker = v
                        }

                        Common.ParamSlider {
                            label: "Min Threshold"
                            value: root.minThreshold
                            from: 1; to: 1000
                            decimals: 0
                            onValueChanged: root.minThreshold = v
                        }

                        Common.ParamSlider {
                            label: "Max Threshold"
                            value: root.maxThreshold
                            from: 1; to: 10000
                            decimals: 0
                            onValueChanged: root.maxThreshold = v
                        }
                    }

                    // CELLPOSE WRAPPER
                    Common.ParamCard {
                        visible: root.segmentationMethod === "cellpose"
                        title: "Cellpose"
                        description: "Deep-learning based segmentation"

                        Common.ParamSlider {
                            label: "Diameter"
                            value: root.cellposeDiameter
                            from: 0; to: 200
                            decimals: 0
                            onValueChanged: root.cellposeDiameter = value   // ⚠ FIX
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

                    Common.ParamCard {
                        visible: root.segmentationMethod === "cellpose_jl"
                        title: "Cellpose.jl"
                        description: "Julia backend (ONNX)"

                        Label {
                            text: "⚠ Advanced parameters handled internally"
                            color: "#FFA726"
                        }

                        Common.ParamSlider {
                            label: "Diameter"
                            value: root.cellposeDiameter
                            from: 0; to: 200
                            decimals: 0
                            onValueChanged: root.cellposeDiameter = value
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

                            Label {
                                text: root.cellposePretrainedModel || "No ONNX model selected"
                                color: "#AAAAAA"
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            Common.Button {
                                text: "Browse"
                                onClicked: modelFileDialog.open()
                            }
                        }
                    }

                    // MODEL (JNET)
                    Common.ParamCard {
                        visible: root.segmentationMethod === "jnet"
                        title: "Model"
                        description: "Select trained model"

                        RowLayout {
                            Label {
                                text: root.modelBsonPath || "No model selected"
                                color: "#aaa"
                                Layout.fillWidth: true
                            }

                            Common.StyledButton {
                                text: "Browse"
                                isPrimary: true
                                onClicked: modelFileDialog.open()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Common.Button {
                    text: "Apply"
                    isHighlighted: true
                    onClicked: {
                        propmap["segmentation_method"] = root.segmentationMethod
                        propmap["model_bson_path"] = root.modelBsonPath

                        // GRAPH
                        propmap["threshold_gray"] = root.thresholdGray
                        propmap["threshold_marker"] = root.thresholdMarker
                        propmap["min_threshold"] = root.minThreshold
                        propmap["max_threshold"] = root.maxThreshold

                        // CELLPOSE
                        propmap["cellpose_diameter"] = root.cellposeDiameter
                        propmap["cellpose_invert"] = root.cellposeInvert
                        propmap["cellpose_augment"] = root.cellposeAugment

                        if (root.segmentationMethod === "cellpose") {
                            propmap["cellpose_flow_threshold"] = root.cellposeFlowThreshold
                            propmap["cellpose_cellprob_threshold"] = root.cellposeCellprobThreshold
                            propmap["cellpose_min_size"] = root.cellposeMinSize
                            propmap["cellpose_cache_models"] = root.cellposeCacheModels
                            propmap["cellpose_max_cached"] = root.cellposeMaxCachedModels
                            propmap["cellpose_pretrained"] = root.cellposePretrainedModel
                        }

                        if (root.segmentationMethod === "cellpose_jl") {
                            propmap["cellpose_jl_diameter"] = root.cellposeDiameter
                            propmap["cellpose_jl_invert"] = root.cellposeInvert
                            propmap["cellpose_jl_augment"] = root.cellposeAugment
                        }

                        root.settingsApplied()
                        settingsPopup.close()
                    }
                }
            }
        }
    }
}