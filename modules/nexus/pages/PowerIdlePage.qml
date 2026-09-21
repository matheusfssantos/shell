import Caelestia.Config
import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var lockTimeout: GlobalConfig.general.idle.timeouts.values[0]
    readonly property var screenTimeout: GlobalConfig.general.idle.timeouts.values[1]
    readonly property var suspendTimeout: GlobalConfig.general.idle.timeouts.values[2]

    title: Tr.tr("Power & idle")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Screen")
        }

        ToggleRow {
            first: true
            last: true

            text: Tr.tr("Turn screen off automatically")
            subtext: Tr.tr("Disable this to keep the screen on while idle")

            checked: root.screenTimeout ? root.screenTimeout.enabled : true

            onToggled: {
                if (root.screenTimeout)
                    root.screenTimeout.enabled = checked
            }
        }

        SectionHeader {
            text: Tr.tr("Lock")
        }

        ToggleRow {
            first: true
            last: true

            text: Tr.tr("Lock automatically")
            subtext: Tr.tr("Disable this to keep the session unlocked while idle")

            checked: root.lockTimeout ? root.lockTimeout.enabled : true

            onToggled: {
                if (root.lockTimeout)
                    root.lockTimeout.enabled = checked
            }
        }

        SectionHeader {
            text: Tr.tr("Sleep")
        }

        ToggleRow {
            first: true
            last: true

            text: Tr.tr("Suspend automatically")
            subtext: Tr.tr("Disable this to prevent suspend while idle")

            checked: root.suspendTimeout ? root.suspendTimeout.enabled : true

            onToggled: {
                if (root.suspendTimeout)
                    root.suspendTimeout.enabled = checked
            }
        }
    }
}
