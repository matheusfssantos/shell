pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    function create(parent: Item, props: var): void {
        const activeScreen = ShellState.forActive()?.modelData;
        const initialProps = Object.assign({}, activeScreen ? {
            screen: activeScreen
        } : {}, props ?? {});
        nexusComp.createObject(parent ?? dummy, initialProps);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            property int initialPageIdx: 0
            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: Math.min(contentItem.Tokens.sizes.nexus.minWidth, nexus.availableScreenWidth)
            minimumSize.height: Math.min(contentItem.Tokens.sizes.nexus.minHeight, nexus.availableScreenHeight)

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: Tr.tr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                nState.currentPageIdx: win.initialPageIdx
                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
