pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property var localEvents: []
    property var remoteEvents: []
    property var accounts: []
    property var remoteCalendars: []
    property var statuses: []
    property list<var> activeProcesses: []
    property bool loaded
    property bool syncing
    property bool authorizing
    property string authorizationProvider: ""
    property string lastError: ""
    property double syncedAt

    readonly property var localCalendar: ({
            id: "local",
            name: "Local",
            colour: "#43d17c",
            provider: "local",
            writable: true,
            primary: true
        })
    readonly property var calendars: [localCalendar, ...remoteCalendars]
    readonly property var events: [...localEvents, ...remoteEvents]
    readonly property string bridgePath: `${Quickshell.shellDir}/scripts/calendar-sync.py`

    signal syncCompleted(bool success)
    signal authorizationCompleted(bool success)

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function dateKey(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, "0");
        const day = String(date.getDate()).padStart(2, "0");
        return `${year}-${month}-${day}`;
    }

    function eventsForDate(date) {
        const from = startOfDay(date).getTime();
        const to = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
        return events.filter(event => event.startMs < to && event.endMs > from).sort((a, b) => a.startMs - b.startMs);
    }

    function eventById(id) {
        return events.find(event => event.id === id) ?? null;
    }

    function calendarById(id) {
        return calendars.find(calendar => calendar.id === id) ?? localCalendar;
    }

    function defaultWritableCalendar() {
        return remoteCalendars.find(calendar => calendar.primary && calendar.writable) ?? remoteCalendars.find(calendar => calendar.writable) ?? localCalendar;
    }

    function encodePayload(payload) {
        return JSON.stringify(payload);
    }

    function addEvent(properties) {
        const calendar = calendarById(properties.calendarId ?? "local");
        if (calendar.provider !== "local") {
            mutateRemote("create", Object.assign({}, properties, {
                        calendarId: calendar.id
                    }));
            return "";
        }

        const now = Date.now();
        const event = Object.assign({
            id: `local-${now}-${Math.floor(Math.random() * 1000000)}`,
            calendarId: "local",
            provider: "local",
            colour: localCalendar.colour,
            title: "",
            location: "",
            notes: "",
            allDay: false,
            writable: true,
            createdMs: now,
            updatedMs: now,
            syncState: "local"
        }, properties);
        root.localEvents = [...root.localEvents, event];
        return event.id;
    }

    function updateEvent(id, properties) {
        const existing = eventById(id);
        if (!existing)
            return;
        if (existing.provider !== "local") {
            mutateRemote("update", Object.assign({}, existing, properties));
            return;
        }
        root.localEvents = root.localEvents.map(event => event.id === id ? Object.assign({}, event, properties, {
                    updatedMs: Date.now()
                }) : event);
    }

    function removeEvent(id) {
        const existing = eventById(id);
        if (!existing)
            return;
        if (existing.provider !== "local") {
            mutateRemote("delete", existing);
            return;
        }
        root.localEvents = root.localEvents.filter(event => event.id !== id);
    }

    function applyBridgeResult(result) {
        root.accounts = result.accounts ?? root.accounts;
        root.remoteCalendars = result.calendars ?? root.remoteCalendars;
        root.remoteEvents = result.events ?? root.remoteEvents;
        root.statuses = result.statuses ?? root.statuses;
        root.syncedAt = result.syncedAt ?? root.syncedAt;
    }

    function runBridge(args, callback) {
        const process = bridgeProcess.createObject(root);
        process.callback = callback;
        root.activeProcesses.push(process);
        Qt.callLater(() => process.exec(["python", root.bridgePath, ...args]));
    }

    function loadStatus() {
        runBridge(["status"], result => {
            if (result.success)
                applyBridgeResult(result.data);
            if (root.accounts.length > 0)
                sync();
        });
    }

    function sync() {
        if (syncing)
            return;
        syncing = true;
        lastError = "";
        runBridge(["sync"], result => {
            root.syncing = false;
            if (result.success) {
                root.applyBridgeResult(result.data);
                const failures = root.statuses.filter(status => !status.ok);
                root.lastError = failures.map(status => status.error).join("\n");
                root.syncCompleted(failures.length === 0);
            } else {
                root.lastError = result.error;
                root.syncCompleted(false);
            }
        });
    }

    function mutateRemote(action, payload) {
        lastError = "";
        runBridge([action, encodePayload(payload)], result => {
            if (result.success)
                root.sync();
            else
                root.lastError = result.error;
        });
    }

    function connectGoogle(credentialsPath, label) {
        if (!credentialsPath || authorizing)
            return;
        authorizing = true;
        authorizationProvider = "google";
        lastError = "";
        runBridge(["connect-google", "--credentials", credentialsPath, "--label", label ?? ""], result => {
            root.authorizing = false;
            root.authorizationProvider = "";
            if (result.success) {
                root.loadStatus();
                root.authorizationCompleted(true);
            } else {
                root.lastError = result.error;
                root.authorizationCompleted(false);
            }
        });
    }

    function connectMicrosoft(clientId, label) {
        if (!clientId || authorizing)
            return;
        authorizing = true;
        authorizationProvider = "microsoft";
        lastError = "";
        runBridge(["connect-microsoft", "--client-id", clientId, "--label", label ?? ""], result => {
            root.authorizing = false;
            root.authorizationProvider = "";
            if (result.success) {
                root.loadStatus();
                root.authorizationCompleted(true);
            } else {
                root.lastError = result.error;
                root.authorizationCompleted(false);
            }
        });
    }

    function disconnect(accountId) {
        runBridge(["disconnect", accountId], result => {
            if (result.success)
                root.sync();
            else
                root.lastError = result.error;
        });
    }

    onLocalEventsChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Component.onCompleted: loadStatus()

    Timer {
        id: saveTimer

        interval: 250
        onTriggered: storage.setText(JSON.stringify({
                version: 1,
                events: root.localEvents
            }, null, 2))
    }

    Timer {
        running: root.accounts.length > 0
        interval: 300000
        repeat: true
        onTriggered: root.sync()
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/calendar-events.json`

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.localEvents = Array.isArray(data) ? data : (data.events ?? []);
            } catch (error) {
                console.warn(`Unable to parse calendar events: ${error}`);
                root.localEvents = [];
            }
            root.loaded = true;
        }

        onLoadFailed: error => {
            root.loaded = true;
            if (error === FileViewError.FileNotFound)
                Qt.callLater(() => setText(JSON.stringify({ version: 1, events: [] }, null, 2)));
            else
                console.warn(`Unable to load calendar events: ${error}`);
        }
    }

    Component {
        id: bridgeProcess

        Process {
            id: process

            property var callback

            stdout: StdioCollector {
                id: output
            }

            stderr: StdioCollector {
                id: errors
            }

            onExited: code => { // qmllint disable signal-handler-parameters
                let data = {};
                try {
                    data = JSON.parse(output.text || "{}");
                } catch (error) {
                    data = {};
                }
                const errorText = errors.text?.trim() || data.error || `Calendar bridge exited with code ${code}`;
                const result = {
                    success: code === 0,
                    data: data,
                    error: errorText
                };
                const index = root.activeProcesses.indexOf(process);
                if (index >= 0)
                    root.activeProcesses.splice(index, 1);
                const done = process.callback;
                process.destroy();
                done?.(result);
            }
        }
    }

    IpcHandler {
        function add(title: string, startMs: string, endMs: string, allDay: string): string {
            return root.addEvent({
                title: title,
                startMs: Number(startMs),
                endMs: Number(endMs),
                allDay: allDay === "true"
            });
        }

        function remove(id: string): void {
            root.removeEvent(id);
        }

        function count(): int {
            return root.events.length;
        }

        function list(): string {
            return JSON.stringify(root.events);
        }

        function sync(): void {
            root.sync();
        }

        function accounts(): string {
            return JSON.stringify(root.accounts);
        }

        target: "calendar"
    }
}
