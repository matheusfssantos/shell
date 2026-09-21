import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property bool fullscreen

    readonly property int hPadding: Tokens.padding.large

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.hPadding
        anchors.rightMargin: root.hPadding

        spacing: Tokens.spacing.medium

        // Left
        OsIcon {
            objectName: "topBarLogo"
        }

        Item {
            Layout.fillWidth: true
        }

        // Center
        TopClock {
            objectName: "topBarClock"
        }

        Item {
            Layout.fillWidth: true
        }

        // Right
        Power {
            objectName: "topBarPower"
            screenState: root.screenState
        }
    }
}
