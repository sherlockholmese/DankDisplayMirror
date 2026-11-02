import QtQuick
import qs.Modules.ControlCenter.Widgets
import "."

// One side of a route: a single-choice list of every connected display.
Column {
    id: root

    property string title: ""
    property var rows: []
    property string selectedName: ""

    signal picked(string name)

    CcSectionLabel {
        text: root.title
    }

    CcGroup {
        Repeater {
            model: root.rows

            CcListRow {
                id: row

                required property var modelData

                title: modelData.label
                subtitle: modelData.detail
                active: modelData.name === root.selectedName
                enabled: !modelData.inUse
                clickable: true
                Accessible.role: Accessible.RadioButton
                Accessible.name: root.title + " " + modelData.label
                Accessible.checkable: true
                Accessible.checked: active
                Accessible.onToggleAction: {
                    if (enabled)
                        root.picked(modelData.name);
                }
                onClicked: root.picked(modelData.name)

                leading: DisplayShape {
                    displayWidth: row.modelData.width
                    displayHeight: row.modelData.height
                    filled: row.active
                    color: row.iconColor
                }
            }
        }
    }
}
