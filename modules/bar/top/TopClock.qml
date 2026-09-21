import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background
        ? Tokens.padding.medium
        : Tokens.padding.small

    implicitHeight: Tokens.sizes.bar.innerWidth
    implicitWidth: layout.implicitWidth + padding * 2

    color: Qt.alpha(
        Colours.tPalette.m3surfaceContainer,
        Config.bar.clock.background
            ? Colours.tPalette.m3surfaceContainer.a
            : 0
    )

    radius: Tokens.rounding.full

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Loader {
            Layout.alignment: Qt.AlignVCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter

            visible: Config.bar.clock.showDate
            text: Time.format("ddd, d")

            font: Tokens.font.body.small
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter

            text: Time.hourStr
                + ":"
                + Time.minuteStr
                + (Config.bar.clock.showSeconds ? ":" + Time.format("ss") : "")
                + (Units.twelveHourClock ? " " + Time.amPmStr : "")

            font: Tokens.font.body.small
            color: root.colour
        }
    }
}
