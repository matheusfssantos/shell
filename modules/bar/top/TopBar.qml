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

    function closeTray(): void {
    }
    
    function checkPopout(x: real): void {
    }
    
    function handleWheel(x: real, angleDelta: point): void {
        if (x < root.screen.width / 2 && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(root.screen);
    
            if (angleDelta.y > 0)
                monitor.setBrightness(
                    monitor.brightness + GlobalConfig.services.brightnessIncrement
                );
            else if (angleDelta.y < 0)
                monitor.setBrightness(
                    monitor.brightness - GlobalConfig.services.brightnessIncrement
                );
        }
    }

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
