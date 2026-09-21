pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Variants {
    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        TopExclusions {
            screen: scope.modelData
            bar: content.bar
        }

        TopContentWindow {
            id: content

            screen: scope.modelData
        }
    }
}
