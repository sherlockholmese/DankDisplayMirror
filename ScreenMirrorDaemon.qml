import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var activeMirrors: []
    property var mirrorProcesses: ({})
    property var outputCache: []
    property bool refreshInFlight: false
    property double lastRefreshAt: 0
    readonly property int refreshMaxAgeMs: 5000
    readonly property int stderrLimit: 4096

    PluginGlobalVar {
        id: requestVar
        varName: "request"
        defaultValue: null
        onValueChanged: root.handleRequest(value)
    }

    function publish(name, value) {
        if (pluginService)
            pluginService.setGlobalVar(pluginId, name, value);
    }

    function handleRequest(request) {
        if (!request || !request.action)
            return;

        if (request.action === "refresh" || request.action === "refreshIfStale") {
            refreshOutputs(request.action === "refresh");
            return;
        }
        if (request.action === "stop") {
            stopMirror(String(request.routeId || ""));
            return;
        }
        if (request.action === "stopAll") {
            stopAllMirrors();
            return;
        }
        if (request.action === "start" && request.source && request.destination)
            startMirror(String(request.source), String(request.destination));
    }

    function refreshOutputs(force) {
        if (refreshInFlight)
            return;
        if (!force && outputCache.length > 0 && Date.now() - lastRefreshAt < refreshMaxAgeMs)
            return;

        refreshInFlight = true;
        if (outputCache.length === 0)
            publish("discoveryState", "loading");
        Proc.runCommand("dankDisplayMirror.outputs", ["dms", "randr", "--json"], (stdout, exitCode) => {
            refreshInFlight = false;
            if (exitCode !== 0) {
                outputCache = [];
                publish("outputs", []);
                publish("discoveryState", "error");
                publish("lastError", I18n.trFor("dankDisplayMirror", "Displays could not be loaded. Try refreshing."));
                return;
            }

            try {
                const payload = JSON.parse(stdout || "{}");
                const available = (payload.outputs || []).filter(output => output.enabled).map(output => ({
                    "name": String(output.name || ""),
                    "width": Number(output.width || 0),
                    "height": Number(output.height || 0),
                    "scale": Number(output.scale || 1),
                    "refresh": Number(output.refresh || 0)
                })).filter(output => output.name.length > 0);

                if (JSON.stringify(available) !== JSON.stringify(outputCache)) {
                    outputCache = available;
                    publish("outputs", available);
                }
                lastRefreshAt = Date.now();
                publish("discoveryState", "ready");
                publish("lastError", "");
            } catch (error) {
                outputCache = [];
                publish("outputs", []);
                publish("discoveryState", "error");
                publish("lastError", I18n.trFor("dankDisplayMirror", "The display list was not understood. Try refreshing."));
            }
        }, 0, 5000, root);
    }

    function mirrorCommand(sourceName, destinationName) {
        const showCursor = pluginService
            ? pluginService.loadPluginData(pluginId, "showCursor", true)
            : true;
        const scaling = pluginService
            ? pluginService.loadPluginData(pluginId, "scaling", "fit")
            : "fit";

        return [
            "wl-mirror",
            showCursor ? "--show-cursor" : "--no-show-cursor",
            "--scaling",
            ["fit", "cover", "exact"].indexOf(scaling) >= 0 ? scaling : "fit",
            "--fullscreen-output",
            destinationName,
            "--title",
            I18n.trFor("dankDisplayMirror", "Screen Mirroring") + " · " + sourceName + " → " + destinationName,
            sourceName
        ];
    }

    function routeId(sourceName, destinationName) {
        return sourceName + "\u001f" + destinationName;
    }

    function publishMirrors() {
        publish("activeMirrors", activeMirrors);
        publish("status", activeMirrors.length > 0 ? "active" : "idle");
    }

    function destinationInUse(destinationName) {
        return activeMirrors.some(route => route.destination === destinationName);
    }

    function startMirror(sourceName, destinationName) {
        if (!sourceName || !destinationName || sourceName === destinationName)
            return;

        const id = routeId(sourceName, destinationName);
        if (mirrorProcesses[id] || destinationInUse(destinationName))
            return;

        const process = mirrorProcessComponent.createObject(root, {
            "routeId": id,
            "sourceName": sourceName,
            "destinationName": destinationName,
            "command": mirrorCommand(sourceName, destinationName)
        });
        if (!process)
            return;

        const processes = Object.assign({}, mirrorProcesses);
        processes[id] = process;
        mirrorProcesses = processes;
        activeMirrors = activeMirrors.concat([{
            "id": id,
            "source": sourceName,
            "destination": destinationName,
            "status": "active"
        }]);
        publish("lastError", "");
        publishMirrors();
        process.running = true;
    }

    function setRouteStatus(id, status) {
        let changed = false;
        const updated = activeMirrors.map(route => {
            if (route.id !== id || route.status === status)
                return route;
            changed = true;
            return {
                "id": route.id,
                "source": route.source,
                "destination": route.destination,
                "status": status
            };
        });
        if (!changed)
            return;
        activeMirrors = updated;
        publishMirrors();
    }

    function stopMirror(id) {
        const process = mirrorProcesses[id];
        if (!process)
            return;
        process.stopRequested = true;
        setRouteStatus(id, "stopping");
        process.running = false;
    }

    function stopAllMirrors() {
        const ids = Object.keys(mirrorProcesses);
        for (let i = 0; i < ids.length; i++)
            stopMirror(ids[i]);
    }

    function handleMirrorExit(id, exitCode, requested, stderrText) {
        const route = activeMirrors.find(candidate => candidate.id === id);
        const routeName = route ? route.source + " → " + route.destination : "";
        const processes = Object.assign({}, mirrorProcesses);
        delete processes[id];
        mirrorProcesses = processes;
        activeMirrors = activeMirrors.filter(candidate => candidate.id !== id);

        if (!requested && exitCode !== 0) {
            if (stderrText)
                console.warn("dankDisplayMirror: wl-mirror failed:", stderrText.trim());
            publish("lastError", routeName
                ? I18n.trFor("dankDisplayMirror", "Mirror %1 stopped unexpectedly.").arg(routeName)
                : I18n.trFor("dankDisplayMirror", "A screen mirror stopped unexpectedly."));
            publish("activeMirrors", activeMirrors);
            publish("status", activeMirrors.length > 0 ? "active" : "error");
            ToastService.showError(
                I18n.trFor("dankDisplayMirror", "Mirror stopped unexpectedly"),
                routeName
            );
            return;
        }
        if (routeName) {
            ToastService.showInfo(
                I18n.trFor("dankDisplayMirror", "Mirror stopped"),
                routeName
            );
        }
        publishMirrors();
    }

    Component {
        id: mirrorProcessComponent

        Process {
            id: mirrorProcess

            property string routeId: ""
            property string sourceName: ""
            property string destinationName: ""
            property bool stopRequested: false
            property string stderrText: ""

            running: false

            onStarted: {
                ToastService.showInfo(
                    I18n.trFor("dankDisplayMirror", "Mirror started"),
                    sourceName + " → " + destinationName
                );
            }

            stderr: SplitParser {
                onRead: line => {
                    const message = line.trim();
                    if (!message)
                        return;
                    mirrorProcess.stderrText = (mirrorProcess.stderrText + message + "\n").slice(-root.stderrLimit);
                }
            }

            onExited: exitCode => {
                root.handleMirrorExit(routeId, exitCode, stopRequested, stderrText);
                destroy();
            }
        }
    }

    Component.onCompleted: {
        publish("status", "idle");
        publish("activeMirrors", []);
        publish("lastError", "");
        refreshOutputs(true);
    }

    Component.onDestruction: {
        const ids = Object.keys(mirrorProcesses);
        for (let i = 0; i < ids.length; i++) {
            const process = mirrorProcesses[ids[i]];
            process.stopRequested = true;
            process.running = false;
        }
        Proc.release("dankDisplayMirror.outputs");
    }
}
