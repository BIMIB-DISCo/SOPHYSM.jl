import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    visible: true
    width: 800
    height: 600
    title: "SOPHYSM"

     ColumnLayout {
            Layout.alignment: Qt.AlignTop

            // Navbar
            RowLayout {
                Button {
                    text: "Workspace"
                    onClicked: console.log("Clicked Workspace")
                }

                Button {
                    text: "Image Segmentation"
                    onClicked: console.log("Clicked Image Segmentation")
                }

                Button {
                    text: "J-Space Simulation"
                    onClicked: console.log("Clicked J-Space Simulation")
                }
            }
        }
}