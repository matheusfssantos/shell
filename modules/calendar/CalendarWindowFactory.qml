pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property var currentWindow

    function open(date, screen, eventData) {
        if (currentWindow) {
            currentWindow.selectedDate = date;
            currentWindow.displayDate = date;
            currentWindow.visible = true;
            if (eventData)
                currentWindow.beginEdit(eventData);
            return;
        }

        const activeScreen = screen ?? ShellState.forActive()?.modelData;
        currentWindow = windowComponent.createObject(root, {
            screen: activeScreen,
            selectedDate: date ?? new Date(),
            displayDate: date ?? new Date()
        });
        if (eventData)
            Qt.callLater(() => {
                if (currentWindow)
                    currentWindow.beginEdit(eventData);
            });
    }

    Component {
        id: windowComponent

        CalendarWindow {
            onClosing: root.currentWindow = null
        }
    }
}
