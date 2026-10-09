pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property var events: []
    property bool loaded

    readonly property var calendars: [
        {
            id: "local",
            name: "Local",
            colour: "#43d17c",
            provider: "local",
            writable: true
        }
    ]

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

    function addEvent(properties) {
        const now = Date.now();
        const event = Object.assign({
            id: `local-${now}-${Math.floor(Math.random() * 1000000)}`,
            calendarId: "local",
            provider: "local",
            colour: calendars[0].colour,
            title: "",
            location: "",
            notes: "",
            allDay: false,
            createdMs: now,
            updatedMs: now,
            syncState: "local"
        }, properties);
        root.events = [...root.events, event];
        return event.id;
    }

    function updateEvent(id, properties) {
        root.events = root.events.map(event => event.id === id ? Object.assign({}, event, properties, {
                    updatedMs: Date.now()
                }) : event);
    }

    function removeEvent(id) {
        root.events = root.events.filter(event => event.id !== id);
    }

    onEventsChanged: {
        if (loaded)
            saveTimer.restart();
    }

    Timer {
        id: saveTimer

        interval: 250
        onTriggered: storage.setText(JSON.stringify({
                version: 1,
                events: root.events
            }, null, 2))
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/calendar-events.json`

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.events = Array.isArray(data) ? data : (data.events ?? []);
            } catch (error) {
                console.warn(`Unable to parse calendar events: ${error}`);
                root.events = [];
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

        target: "calendar"
    }
}
