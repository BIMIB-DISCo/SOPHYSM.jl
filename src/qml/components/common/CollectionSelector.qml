import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../common" as Common

Item {
    id: root
    
    property var model
    property bool hasSelections: false
    
    signal selectionChanged()
    
    function setAllCheckboxes(checked) {
        for (var i = 0; i < checkBoxColumn.children.length; i++) {
            var child = checkBoxColumn.children[i];
            if (child instanceof Common.CheckBox) {
                child.checked = checked;
            }
        }
        updateHasSelections();
    }
    
    function updateHasSelections() {
        for (var i = 0; i < checkBoxColumn.children.length; i++) {
            var child = checkBoxColumn.children[i];
            if (child instanceof Common.CheckBox && 
                child.checked) {
                root.hasSelections = true;
                selectionChanged();
                return;
            }
        }
        root.hasSelections = false;
        selectionChanged();
    }
    
    function getSelectedItems() {
        var selectedItems = [];
        for (var i = 0; i < checkBoxColumn.children.length; i++) {
            var child = checkBoxColumn.children[i];
            if (child instanceof Common.CheckBox && 
                child.checked) {
                selectedItems.push(child.objectName);
            }
        }
        return selectedItems;
    }
    
    RowLayout {
        anchors.top: parent.top
        width: parent.width
        
        Common.Button {
            text: "Select All"
            buttonWidth: 100
            onClicked: setAllCheckboxes(true)
        }
        
        Common.Button {
            text: "Deselect All"
            buttonWidth: 100
            onClicked: setAllCheckboxes(false)
        }
        
        Item { Layout.fillWidth: true }
    }
    
    Rectangle {
        anchors {
            top: parent.top
            topMargin: 50
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        color: "transparent"
        border.width: 1
        border.color: "#2D2D2D" 
        radius: 5
        
        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
    
            Column {
                id: checkBoxColumn
                width: scrollView.width - 30
                spacing: 8
                
                Repeater {
                    model: root.model
                    
                    Common.CheckBox {
                        objectName: model.code
                        text: ""
                        width: parent.width
                        
                        onCheckedChanged: {
                            updateHasSelections();
                        }
                        
                        contentItem: Row {
                            spacing: 4
                            leftPadding: 28
                            
                            Text {
                                text: "TCGA-" + model.code.toUpperCase() + " = "
                                color: "#FFFFFF"
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            Text {
                                text: model.description
                                color: "#AAAAAA"
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
