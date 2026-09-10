import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string mirrorStatus: statusVar.value || "idle"
    readonly property var activeMirrors: activeMirrorsVar.value || []
    readonly property var availableOutputs: outputsVar.value || []
    readonly property bool isMirroring: activeMirrors.length > 0

    PluginGlobalVar {
        id: requestVar
        varName: "request"
        defaultValue: null
    }

    PluginGlobalVar {
        id: statusVar
        varName: "status"
        defaultValue: "idle"
    }

    PluginGlobalVar {
        id: activeMirrorsVar
        varName: "activeMirrors"
        defaultValue: []
    }

    PluginGlobalVar {
        id: outputsVar
        varName: "outputs"
        defaultValue: []
    }

    PluginGlobalVar {
        id: discoveryStateVar
        varName: "discoveryState"
        defaultValue: "loading"
    }

    PluginGlobalVar {
        id: lastErrorVar
        varName: "lastError"
        defaultValue: ""
    }

    function tr(text) {
        return I18n.trFor("dankDisplayMirror", text);
    }

    function request(action, sourceName, destinationName, routeId) {
        requestVar.set({
            "action": action,
            "source": sourceName || "",
            "destination": destinationName || "",
            "routeId": routeId || "",
            "nonce": Date.now() + Math.random()
        });
    }

    function hasOutput(outputName) {
        return availableOutputs.some(output => output.name === outputName);
    }

    function destinationInUse(outputName) {
        return activeMirrors.some(route => route.destination === outputName);
    }

    function sourceAvailable(outputName) {
        return hasOutput(outputName) && !destinationInUse(outputName);
    }

    function preferredSource() {
        const saved = String(pluginData.lastSource || "");
        if (sourceAvailable(saved))
            return saved;
        for (let i = 0; i < availableOutputs.length; i++) {
            if (sourceAvailable(availableOutputs[i].name))
                return availableOutputs[i].name;
        }
        return "";
    }

    function preferredDestination(sourceName) {
        const saved = String(pluginData.lastDestination || "");
        if (saved !== sourceName && hasOutput(saved) && !destinationInUse(saved))
            return saved;
        for (let i = 0; i < availableOutputs.length; i++) {
            const name = availableOutputs[i].name;
            if (name !== sourceName && !destinationInUse(name))
                return name;
        }
        return "";
    }

    function startMirror(sourceName, destinationName) {
        if (!sourceName || !destinationName || sourceName === destinationName || destinationInUse(destinationName))
            return;
        if (pluginService) {
            pluginService.savePluginData(pluginId, "lastSource", sourceName);
            pluginService.savePluginData(pluginId, "lastDestination", destinationName);
        }
        request("start", sourceName, destinationName);
    }

    function stopMirror(routeId) {
        if (routeId)
            request("stop", "", "", routeId);
    }

    function secondaryText() {
        if (activeMirrors.length === 1)
            return activeMirrors[0].source + " → " + activeMirrors[0].destination;
        if (activeMirrors.length > 1)
            return tr("%1 active mirrors").arg(activeMirrors.length);
        if (mirrorStatus === "error")
            return tr("A mirror stopped unexpectedly");
        if (discoveryStateVar.value === "loading" && availableOutputs.length === 0)
            return tr("Finding displays…");
        if (discoveryStateVar.value === "error")
            return tr("Displays unavailable");
        if (availableOutputs.length < 2)
            return tr("Connect another display");
        return tr("%1 displays connected").arg(availableOutputs.length);
    }

    ccWidgetIcon: isMirroring ? "stop_screen_share" : "screen_share"
    ccWidgetPrimaryText: tr("Screen Mirroring")
    ccWidgetSecondaryText: secondaryText()
    ccWidgetIsActive: isMirroring
    ccWidgetIsToggle: true
    ccDetailHeight: 440

    onCcWidgetToggled: {
        if (isMirroring) {
            request("stopAll");
            return;
        }

        const sourceName = preferredSource();
        const destinationName = preferredDestination(sourceName);
        if (!sourceName || !destinationName) {
            request("refresh");
            ToastService.showError(tr("Screen Mirroring"), tr("Connect a second display, then choose a route."));
            return;
        }
        startMirror(sourceName, destinationName);
    }

    onCcWidgetExpanded: request("refreshIfStale")

    ccDetailContent: Component {
        StyledRect {
            id: detailRoot

            readonly property var outputs: root.availableOutputs
            readonly property var outputNames: outputs.map(output => output.name)
            readonly property var sourceNames: outputNames.filter(name => !root.destinationInUse(name))
            readonly property var destinationNames: outputNames.filter(name => name !== selectedSource && !root.destinationInUse(name))
            readonly property bool loading: discoveryStateVar.value === "loading" && outputs.length === 0
            readonly property bool failed: discoveryStateVar.value === "error"
            property string selectedSource: ""
            property string selectedDestination: ""

            anchors.fill: parent
            color: Theme.surfaceContainerHigh
            radius: Theme.cornerRadius
            clip: true

            function ensureSelections() {
                if (outputs.length < 2) {
                    selectedSource = "";
                    selectedDestination = "";
                    return;
                }

                if (sourceNames.indexOf(selectedSource) < 0)
                    selectedSource = root.preferredSource();
                if (destinationNames.indexOf(selectedDestination) < 0)
                    selectedDestination = root.preferredDestination(selectedSource);
            }

            onOutputsChanged: ensureSelections()
            onSourceNamesChanged: ensureSelections()
            onDestinationNamesChanged: {
                if (destinationNames.indexOf(selectedDestination) < 0)
                    selectedDestination = root.preferredDestination(selectedSource);
            }
            Component.onCompleted: ensureSelections()

            Column {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXXS

                Row {
                    width: parent.width
                    height: Theme.iconSizeLarge
                    spacing: Theme.spacingS

                    DankIcon {
                        width: Theme.iconSizeLarge
                        anchors.verticalCenter: parent.verticalCenter
                        name: "screen_share"
                        size: Theme.iconSize
                        color: root.isMirroring ? Theme.primary : Theme.surfaceText
                    }

                    Column {
                        width: parent.width - Theme.iconSizeLarge - refreshButton.width - parent.spacing * 2
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXXS

                        StyledText {
                            width: parent.width
                            text: root.tr("Screen Mirroring")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Medium
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: root.secondaryText()
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                        }
                    }

                    DankActionButton {
                        id: refreshButton
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "refresh"
                        tooltipText: root.tr("Refresh displays")
                        enabled: !detailRoot.loading
                        onClicked: root.request("refresh")
                    }
                }
            }

            Column {
                id: content

                anchors.top: header.bottom
                anchors.topMargin: Theme.spacingM
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: addButton.top
                anchors.bottomMargin: Theme.spacingS
                anchors.leftMargin: Theme.spacingM
                anchors.rightMargin: Theme.spacingM
                spacing: Theme.spacingS
                visible: !detailRoot.loading && !detailRoot.failed && detailRoot.outputs.length >= 2

                Row {
                    id: routePicker
                    width: parent.width
                    height: Theme.iconSizeLarge * 3 + Theme.spacingXL
                    spacing: Theme.spacingS

                    Column {
                        width: (parent.width - arrow.width - parent.spacing * 2) / 2
                        height: parent.height
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: root.tr("From")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }

                        DankListView {
                            id: sourceList
                            width: parent.width
                            height: parent.height - Theme.fontSizeSmall - parent.spacing
                            spacing: Theme.spacingXS
                            clip: true
                            model: detailRoot.sourceNames

                            delegate: StyledRect {
                                id: sourceRow
                                required property string modelData

                                width: sourceList.width
                                height: Theme.iconSizeLarge + Theme.spacingL
                                radius: Theme.cornerRadius
                                color: modelData === detailRoot.selectedSource || sourceMouse.containsMouse
                                    ? Theme.surfaceContainerHighest
                                    : Theme.surfaceContainer
                                border.width: modelData === detailRoot.selectedSource || sourceMouse.activeFocus
                                    ? 2
                                    : Theme.layerOutlineWidth
                                border.color: modelData === detailRoot.selectedSource
                                    ? Theme.primary
                                    : (sourceMouse.activeFocus ? Theme.surfaceText : Theme.outlineMedium)

                                DankIcon {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingS
                                    name: "desktop_windows"
                                    size: Theme.iconSize
                                    color: modelData === detailRoot.selectedSource
                                        ? Theme.primary
                                        : Theme.surfaceVariantText
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.iconSize + Theme.spacingL
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: sourceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    activeFocusOnTab: true
                                    cursorShape: Qt.PointingHandCursor
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: root.tr("Mirror from %1").arg(modelData)
                                    Accessible.checked: modelData === detailRoot.selectedSource
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            detailRoot.selectedSource = modelData;
                                            detailRoot.ensureSelections();
                                            event.accepted = true;
                                        }
                                    }
                                    onClicked: {
                                        detailRoot.selectedSource = modelData;
                                        detailRoot.ensureSelections();
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: arrow
                        width: Theme.iconSizeLarge
                        height: parent.height

                        DankIcon {
                            anchors.centerIn: parent
                            name: "arrow_forward"
                            size: Theme.iconSize
                            color: Theme.primary
                        }
                    }

                    Column {
                        width: (parent.width - arrow.width - parent.spacing * 2) / 2
                        height: parent.height
                        spacing: Theme.spacingXS

                        StyledText {
                            width: parent.width
                            text: root.tr("To")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                        }

                        DankListView {
                            id: destinationList
                            width: parent.width
                            height: parent.height - Theme.fontSizeSmall - parent.spacing
                            spacing: Theme.spacingXS
                            clip: true
                            model: detailRoot.destinationNames

                            delegate: StyledRect {
                                id: destinationRow
                                required property string modelData

                                width: destinationList.width
                                height: Theme.iconSizeLarge + Theme.spacingL
                                radius: Theme.cornerRadius
                                color: modelData === detailRoot.selectedDestination || destinationMouse.containsMouse
                                    ? Theme.surfaceContainerHighest
                                    : Theme.surfaceContainer
                                border.width: modelData === detailRoot.selectedDestination || destinationMouse.activeFocus
                                    ? 2
                                    : Theme.layerOutlineWidth
                                border.color: modelData === detailRoot.selectedDestination
                                    ? Theme.primary
                                    : (destinationMouse.activeFocus ? Theme.surfaceText : Theme.outlineMedium)

                                DankIcon {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingS
                                    name: "tv"
                                    size: Theme.iconSize
                                    color: modelData === detailRoot.selectedDestination
                                        ? Theme.primary
                                        : Theme.surfaceVariantText
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.iconSize + Theme.spacingL
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingS
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: destinationMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    activeFocusOnTab: true
                                    cursorShape: Qt.PointingHandCursor
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.name: root.tr("Mirror to %1").arg(modelData)
                                    Accessible.checked: modelData === detailRoot.selectedDestination
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            detailRoot.selectedDestination = modelData;
                                            event.accepted = true;
                                        }
                                    }
                                    onClicked: detailRoot.selectedDestination = modelData
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.tr("Active mirrors")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    visible: root.activeMirrors.length > 0
                }

                DankListView {
                    id: activeList
                    width: parent.width
                    height: Math.max(0, content.height - routePicker.height
                        - (root.activeMirrors.length > 0 ? Theme.fontSizeSmall + content.spacing * 2 : content.spacing))
                    spacing: Theme.spacingXS
                    clip: true
                    visible: root.activeMirrors.length > 0
                    model: root.activeMirrors

                    delegate: StyledRect {
                        required property var modelData

                        width: activeList.width
                        height: Theme.iconSizeLarge + Theme.spacingS
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHighest

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingXS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "screen_share"
                                size: Theme.iconSizeSmall
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                width: parent.width - Theme.iconSizeSmall - stopButton.width - parent.spacing * 2
                                text: modelData.source + " → " + modelData.destination
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            DankActionButton {
                                id: stopButton
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: modelData.status === "stopping" ? "hourglass_top" : "close"
                                tooltipText: root.tr("Stop this mirror")
                                enabled: modelData.status !== "stopping"
                                onClicked: root.stopMirror(modelData.id)
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    height: Math.max(0, content.height - routePicker.height - content.spacing)
                    visible: root.activeMirrors.length === 0
                    text: root.tr("No active mirrors")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Item {
                anchors.top: header.bottom
                anchors.topMargin: Theme.spacingS
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: addButton.top
                visible: !content.visible

                DankSpinner {
                    anchors.centerIn: parent
                    visible: detailRoot.loading
                    running: visible
                    size: Theme.iconSizeLarge
                    color: Theme.primary
                }

                Column {
                    width: parent.width - Theme.spacingXL * 2
                    anchors.centerIn: parent
                    spacing: Theme.spacingS
                    visible: !detailRoot.loading

                    DankIcon {
                        name: detailRoot.failed ? "error_outline" : "desktop_access_disabled"
                        size: Theme.iconSizeLarge
                        color: detailRoot.failed ? Theme.error : Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        width: parent.width
                        text: detailRoot.failed
                            ? (lastErrorVar.value || root.tr("Displays could not be loaded."))
                            : root.tr("Connect a second display to create a mirror route")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            DankButton {
                id: addButton
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.spacingM
                visible: content.visible
                enabled: detailRoot.selectedSource.length > 0
                    && detailRoot.selectedDestination.length > 0
                    && detailRoot.selectedSource !== detailRoot.selectedDestination
                    && !root.destinationInUse(detailRoot.selectedDestination)
                text: root.tr("Add Mirror")
                iconName: "add_to_queue"
                backgroundColor: Theme.buttonBg
                textColor: Theme.buttonText
                onClicked: root.startMirror(detailRoot.selectedSource, detailRoot.selectedDestination)
            }
        }
    }
}
