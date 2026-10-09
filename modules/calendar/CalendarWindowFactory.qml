pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property var currentWindow

    function open(date, screen) {
        if (currentWindow) {
            currentWindow.selectedDate = date;
            currentWindow.displayDate = date;
            currentWindow.visible = true;
            return;
        }

        const activeScreen = screen ?? ShellState.forActive()?.modelData;
        currentWindow = windowComponent.createObject(root, {
            screen: activeScreen,
            selectedDate: date ?? new Date(),
            displayDate: date ?? new Date()
        });
    }

    Component {
        id: windowComponent

        CalendarWindow {
            onClosing: root.currentWindow = null
        }
    }
}
