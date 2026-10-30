pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property ScreenState screenState

    color: Qt.alpha(Colours.tPalette.m3surfaceContainerHigh, 0.92)
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: height / 2
    bottomRightRadius: height / 2

    MaterialIcon {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1

        text: root.screenState.dashboard ? "keyboard_arrow_up" : "keyboard_arrow_down"
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.builders.small.build()
    }

    StateLayer {
        onClicked: root.screenState.dashboard = !root.screenState.dashboard
    }
}
