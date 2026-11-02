import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "dankDisplayMirror"

    StyledText {
        width: parent.width
        text: I18n.trFor("dankDisplayMirror", "Screen Mirroring")
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("dankDisplayMirror", "Applies to new mirrors.")
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        settingKey: "showCursor"
        label: I18n.trFor("dankDisplayMirror", "Show pointer")
        description: I18n.trFor("dankDisplayMirror", "Include the pointer in the mirrored image.")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "scaling"
        label: I18n.trFor("dankDisplayMirror", "Scaling")
        description: I18n.trFor("dankDisplayMirror", "Choose how the image fits inside the mirror window.")
        options: [
            {
                "label": I18n.trFor("dankDisplayMirror", "Fit"),
                "value": "fit"
            },
            {
                "label": I18n.trFor("dankDisplayMirror", "Fill"),
                "value": "cover"
            },
            {
                "label": I18n.trFor("dankDisplayMirror", "Integer"),
                "value": "exact"
            }
        ]
        defaultValue: "fit"
    }
}
