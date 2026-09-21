import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Keyboard shortcuts")

    property string query: ""

    readonly property var shortcuts: [
      	{ category: "Windows", keys: "Super + Alt + F", action: "Fullscreen" },
        { category: "Windows", keys: "Super + F", action: "Maximize" },
        { category: "Windows", keys: "Super + Q", action: "Close window" },
        { category: "Windows", keys: "Super + P", action: "Pin window" },
        { category: "Windows", keys: "Super + Alt + Space", action: "Toggle floating" },

        { category: "Apps", keys: "Super + T", action: "Open terminal" },
        { category: "Apps", keys: "Super + W", action: "Open browser" },
        { category: "Apps", keys: "Super + E", action: "Open file explorer" },
        { category: "Apps", keys: "Super + C", action: "Open editor" },

        { category: "Caelestia", keys: "Super", action: "Open launcher" },
        { category: "Caelestia", keys: "Super + N", action: "Open sidebar" },
        { category: "Caelestia", keys: "Super + K", action: "Show panels" },
        { category: "Caelestia", keys: "Super + L", action: "Lock session" },
        { category: "Caelestia", keys: "Super + V", action: "Clipboard" },
        { category: "Caelestia", keys: "Super + Period", action: "Emoji picker" },

        { category: "Workspaces", keys: "Super + 1..0", action: "Switch workspace" },
        { category: "Workspaces", keys: "Super + Alt + 1..0", action: "Move window to workspace" },
        { category: "Workspaces", keys: "Super + S", action: "Special workspace" },
        { category: "Workspaces", keys: "Super + D", action: "Communication workspace" },
        { category: "Workspaces", keys: "Super + M", action: "Music workspace" },
        { category: "Workspaces", keys: "Super + R", action: "Todo workspace" },

        { category: "Utilities", keys: "Print", action: "Screenshot" },
        { category: "Utilities", keys: "Super + Shift + S", action: "Screenshot freeze" },
        { category: "Utilities", keys: "Super + Shift + Alt + S", action: "Screenshot region" },
        { category: "Utilities", keys: "Super + Shift + C", action: "Color picker" }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        SearchBar {
            Layout.fillWidth: true
            placeholderText: Tr.tr("Search shortcuts...")
            onTextChanged: root.query = text.toLowerCase()
        }

        Repeater {
            model: root.shortcuts

            delegate: Rectangle {
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: visible ? 58 : 0
                visible: root.query === ""
                    || modelData.keys.toLowerCase().includes(root.query)
                    || modelData.action.toLowerCase().includes(root.query)
                    || modelData.category.toLowerCase().includes(root.query)

                radius: 12
                color: Colours.tPalette.m3surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: modelData.action
                            font: Tokens.font.body.large
                        }

                        StyledText {
                            text: modelData.category
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }

                    Rectangle {
                        implicitWidth: keyText.implicitWidth + 20
                        implicitHeight: 32
                        radius: 8
                        color: Colours.tPalette.m3surfaceContainer

                        StyledText {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData.keys
                            font: Tokens.font.label.large
                        }
                    }
                }
            }
        }
    }
}
