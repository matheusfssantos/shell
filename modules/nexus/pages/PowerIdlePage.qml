import Caelestia.Config
import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

	readonly property var screenTimeout: GlobalConfig.general.idle.timeouts.values[1]
	
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
    }
}
