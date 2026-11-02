import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.ControlCenter
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Plugins
import "./components"
import "./components/mirrorGeometry.js" as Geometry

PluginComponent {
    id: root

    readonly property string mirrorStatus: statusVar.value || "idle"
    readonly property var activeMirrors: activeMirrorsVar.value || []
    readonly property var availableOutputs: outputsVar.value || []
    readonly property bool isMirroring: activeMirrors.length > 0
    readonly property var failedRoute: failedRouteVar.value
    readonly property var scalingModes: ["fit", "cover", "exact"]
    readonly property string scaling: scalingModes.indexOf(pluginData.scaling) >= 0 ? pluginData.scaling : "fit"

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

    PluginGlobalVar {
        id: failedRouteVar
        varName: "failedRoute"
        defaultValue: null
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

    function output(outputName) {
        return availableOutputs.find(candidate => candidate.name === outputName) || null;
    }

    function hasOutput(outputName) {
        return output(outputName) !== null;
    }

    function displayLabel(outputName) {
        const match = output(outputName);
        return match ? match.label : outputName;
    }

    function outputDetail(candidate) {
        const size = tr("%1 × %2").arg(candidate.width).arg(candidate.height);
        const hertz = Math.round(candidate.refresh / 1000);
        return hertz > 0 ? tr("%1 · %2 Hz").arg(size).arg(hertz) : size;
    }

    function routeRows() {
        return availableOutputs.map(candidate => {
            const inUse = destinationInUse(candidate.name);
            return {
                "name": candidate.name,
                "label": candidate.label,
                "width": candidate.width,
                "height": candidate.height,
                "inUse": inUse,
                "detail": inUse ? tr("Showing a mirror") : outputDetail(candidate)
            };
        });
    }

    function scalingSummary(source, destination) {
        if (!source || !destination)
            return "";
        switch (Geometry.edgeFit(source.width, source.height, destination.width, destination.height, scaling)) {
        case "barsSides":
            return tr("Black bars left and right");
        case "barsEnds":
            return tr("Black bars above and below");
        case "barsAll":
            return tr("Black bars on every side");
        case "cropSides":
            return tr("Crops the left and right edges");
        case "cropEnds":
            return tr("Crops the top and bottom edges");
        default:
            return tr("Fills the display");
        }
    }

    function setScaling(mode) {
        if (pluginService)
            pluginService.savePluginData(pluginId, "scaling", mode);
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

    function routeName(sourceName, destinationName) {
        return displayLabel(sourceName) + " → " + displayLabel(destinationName);
    }

    function secondaryText() {
        if (activeMirrors.length === 1)
            return routeName(activeMirrors[0].source, activeMirrors[0].destination);
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
    ccDetailHeight: CcMetrics.emptyStateMinHeight

    onCcWidgetToggled: {
        if (isMirroring) {
            request("stopAll");
            return;
        }

        const sourceName = preferredSource();
        const destinationName = preferredDestination(sourceName);
        if (!sourceName || !destinationName) {
            request("refresh");
            ToastService.showError(tr("Screen Mirroring"), tr("Connect a second display"));
            return;
        }
        startMirror(sourceName, destinationName);
    }

    onCcWidgetExpanded: request("refreshIfStale")

    ccDetailContent: Component {
        Item {
            id: detailRoot

            readonly property var rows: root.routeRows()
            readonly property int freeDisplays: rows.filter(row => !row.inUse).length
            readonly property bool canRoute: freeDisplays >= 2
            readonly property bool loading: discoveryStateVar.value === "loading" && rows.length === 0
            readonly property bool failed: discoveryStateVar.value === "error"
            readonly property var sourceOutput: root.output(selectedSource)
            readonly property var destinationOutput: root.output(selectedDestination)
            readonly property bool canRetry: !!root.failedRoute
                && root.hasOutput(root.failedRoute.source)
                && root.hasOutput(root.failedRoute.destination)
                && !root.destinationInUse(root.failedRoute.destination)
            property string selectedSource: ""
            property string selectedDestination: ""

            function selectable(name) {
                return rows.some(row => row.name === name && !row.inUse);
            }

            function ensureSelections() {
                // reads rows directly: canRoute may not have re-evaluated yet when rows changes
                if (rows.filter(row => !row.inUse).length < 2) {
                    selectedSource = "";
                    selectedDestination = "";
                    return;
                }
                if (!selectable(selectedSource))
                    selectedSource = root.preferredSource();
                if (!selectable(selectedDestination) || selectedDestination === selectedSource)
                    selectedDestination = root.preferredDestination(selectedSource);
            }

            function pickSource(name) {
                if (name === selectedDestination)
                    selectedDestination = selectedSource;
                selectedSource = name;
            }

            function pickDestination(name) {
                if (name === selectedSource)
                    selectedSource = selectedDestination;
                selectedDestination = name;
            }

            onRowsChanged: ensureSelections()
            Component.onCompleted: ensureSelections()

            Binding {
                target: root
                property: "ccDetailHeight"
                value: Math.ceil(detailColumn.implicitHeight)
            }

            DFlickable {
                anchors.fill: parent
                contentHeight: detailColumn.height
                clip: true

                Column {
                    id: detailColumn

                    width: parent.width
                    spacing: CcMetrics.detailContentGap

                    CcEmptyState {
                        visible: detailRoot.failed || (!detailRoot.canRoute && !root.isMirroring)
                        spinning: detailRoot.loading
                        iconName: detailRoot.failed ? "error" : "desktop_access_disabled"
                        iconColor: detailRoot.failed ? Theme.error : Theme.surfaceVariantText
                        title: {
                            if (detailRoot.loading)
                                return root.tr("Finding displays…");
                            if (detailRoot.failed)
                                return lastErrorVar.value || root.tr("Displays could not be loaded");
                            return root.tr("Connect a second display");
                        }
                        subtitle: detailRoot.loading || detailRoot.failed ? "" : root.tr("It appears here when connected")

                        DButton {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: detailRoot.failed
                            buttonHeight: Theme.buttonHeightXS
                            iconName: "refresh"
                            iconSize: Theme.iconSizeSmall
                            text: root.tr("Try again")
                            backgroundColor: Theme.chipSurface
                            textColor: Theme.surfaceText
                            onClicked: root.request("refresh")
                        }
                    }

                    CcGroup {
                        visible: !!root.failedRoute

                        CcListRow {
                            iconName: "error"
                            iconColor: Theme.error
                            title: root.tr("Mirror stopped unexpectedly")
                            subtitle: root.failedRoute ? root.routeName(root.failedRoute.source, root.failedRoute.destination) : ""

                            DButton {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: detailRoot.canRetry
                                buttonHeight: Theme.buttonHeightXS
                                minimumWidth: 0
                                text: root.tr("Try again")
                                backgroundColor: Theme.chipSurface
                                textColor: Theme.surfaceText
                                onClicked: root.startMirror(root.failedRoute.source, root.failedRoute.destination)
                            }

                            DActionButton {
                                anchors.verticalCenter: parent.verticalCenter
                                iconName: "close"
                                tooltipText: root.tr("Dismiss")
                                onClicked: root.request("dismissFailure")
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        visible: root.isMirroring

                        CcSectionLabel {
                            text: root.tr("Mirroring")

                            actions: DButton {
                                visible: root.activeMirrors.length > 1
                                buttonHeight: Theme.buttonHeightXS
                                minimumWidth: 0
                                text: root.tr("Stop all")
                                backgroundColor: Theme.chipSurface
                                textColor: Theme.surfaceText
                                onClicked: root.request("stopAll")
                            }
                        }

                        CcGroup {
                            Repeater {
                                model: root.activeMirrors

                                CcListRow {
                                    id: routeRow

                                    required property var modelData
                                    readonly property bool stopping: modelData.status === "stopping"
                                    readonly property var sourceOutput: root.output(modelData.source)
                                    readonly property var destinationOutput: root.output(modelData.destination)

                                    title: root.displayLabel(modelData.destination)
                                    subtitle: stopping ? root.tr("Stopping…") : root.tr("Showing %1").arg(root.displayLabel(modelData.source))

                                    leading: DisplayShape {
                                        displayWidth: routeRow.destinationOutput?.width ?? 0
                                        displayHeight: routeRow.destinationOutput?.height ?? 0
                                        sourceWidth: routeRow.sourceOutput?.width ?? 0
                                        sourceHeight: routeRow.sourceOutput?.height ?? 0
                                        scaling: routeRow.modelData.scaling || "fit"
                                        outlineWidth: Theme.outlineWidth
                                        color: Theme.primary
                                    }

                                    DActionButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        iconName: "stop_screen_share"
                                        iconColor: Theme.surfaceText
                                        tooltipText: root.tr("Stop this mirror")
                                        enabled: !routeRow.stopping
                                        onClicked: root.stopMirror(routeRow.modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: CcMetrics.detailContentGap
                        visible: detailRoot.canRoute

                        DisplayColumn {
                            width: (parent.width - parent.spacing) / 2
                            title: root.tr("From")
                            rows: detailRoot.rows
                            selectedName: detailRoot.selectedSource
                            onPicked: name => detailRoot.pickSource(name)
                        }

                        DisplayColumn {
                            width: (parent.width - parent.spacing) / 2
                            title: root.tr("To")
                            rows: detailRoot.rows
                            selectedName: detailRoot.selectedDestination
                            onPicked: name => detailRoot.pickDestination(name)
                        }
                    }

                    CcGroup {
                        visible: detailRoot.canRoute

                        CcListRow {
                            title: root.tr("Scaling")
                            subtitle: root.scalingSummary(detailRoot.sourceOutput, detailRoot.destinationOutput)

                            leading: DisplayShape {
                                implicitWidth: Theme.iconSizeLarge * 2
                                implicitHeight: Theme.iconSizeLarge + Theme.spacingS
                                outlineWidth: Theme.outlineWidth
                                displayWidth: detailRoot.destinationOutput?.width ?? 0
                                displayHeight: detailRoot.destinationOutput?.height ?? 0
                                sourceWidth: detailRoot.sourceOutput?.width ?? 0
                                sourceHeight: detailRoot.sourceOutput?.height ?? 0
                                scaling: root.scaling
                                color: Theme.primary
                            }

                            DButtonGroup {
                                anchors.verticalCenter: parent.verticalCenter
                                size: "small"
                                checkEnabled: false
                                model: [root.tr("Fit"), root.tr("Fill"), root.tr("Integer")]
                                currentIndex: root.scalingModes.indexOf(root.scaling)
                                onSelectionChanged: (index, selected) => {
                                    if (selected)
                                        root.setScaling(root.scalingModes[index]);
                                }
                            }
                        }
                    }

                    DButton {
                        width: parent.width
                        maximumWidth: parent.width
                        visible: detailRoot.canRoute
                        enabled: !!detailRoot.sourceOutput && !!detailRoot.destinationOutput
                        iconName: "screen_share"
                        text: root.tr("Mirror to %1").arg(root.displayLabel(detailRoot.selectedDestination))
                        onClicked: root.startMirror(detailRoot.selectedSource, detailRoot.selectedDestination)
                    }
                }
            }
        }
    }
}
