pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.calendar

CustomMouseArea {
    id: root

    required property ScreenState screenState

    property date currentDate: screenState.dashboardDate
    property string viewMode: "month"
    property var previewDay: null
    property var previewEvents: []
    property real previewX
    property real previewY
    readonly property int currMonth: currentDate.getMonth()
    readonly property int currYear: currentDate.getFullYear()
    readonly property int nonAnimCurrMonth: screenState.dashboardDate.getMonth()
    readonly property int nonAnimCurrYear: screenState.dashboardDate.getFullYear()

    readonly property int animDirection: screenState.dashboardDate > currentDate ? -1 : 1
    property real animTranslate
    property real animOpacity: 1

    function addDays(date, days) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
    }

    function startOfWeek(date) {
        return addDays(date, -date.getDay());
    }

    function formatEventTime(event) {
        if (event.allDay)
            return Tr.tr("All day");
        return Qt.locale().toString(new Date(event.startMs), "HH:mm");
    }

    function navigate(direction) {
        if (viewMode === "month")
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth + direction, 1);
        else
            screenState.dashboardDate = addDays(screenState.dashboardDate, direction * (viewMode === "week" ? 7 : 1));
        previewDay = null;
    }

    function setViewMode(mode) {
        viewMode = mode;
        previewDay = null;
    }

    function showPreview(dayItem, date, events) {
        if (!events.length) {
            previewDay = null;
            return;
        }
        const point = dayItem.mapToItem(root, dayItem.width / 2, dayItem.height);
        previewDay = date;
        previewEvents = events;
        previewX = Math.max(Tokens.padding.small, Math.min(point.x - previewCard.width / 2, root.width - previewCard.width - Tokens.padding.small));
        previewY = Math.max(Tokens.padding.small, Math.min(point.y + Tokens.spacing.extraSmall, root.height - previewCard.height - Tokens.padding.small));
    }

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            navigate(-1);
        else if (event.angleDelta.y < 0)
            navigate(1);
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    acceptedButtons: Qt.MiddleButton
    onClicked: root.screenState.dashboardDate = new Date()

    Anim {
        id: trOutAnim

        running: false
        target: root
        property: "animTranslate"
        to: root.Tokens.padding.extraLarge * root.animDirection
        type: Anim.FastSpatial
    }

    Behavior on currentDate {
        SequentialAnimation {
            ParallelAnimation {
                ScriptAction {
                    script: Qt.callLater(() => trOutAnim.start())
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 0
                    type: Anim.FastEffects
                }
            }
            ScriptAction {
                script: {
                    trOutAnim.complete();
                    root.animTranslate = root.Tokens.padding.extraLarge * -root.animDirection;
                }
            }
            PropertyAction {}
            ParallelAnimation {
                Anim {
                    target: root
                    property: "animTranslate"
                    to: 0
                    type: Anim.DefaultSpatial
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            id: monthNavigationRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                isRound: true
                icon: "chevron_left"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.navigate(-1)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2

                StateLayer {
                    color: Colours.palette.m3primary
                    radius: pressed ? Tokens.rounding.small : height / 2
                    disabled: {
                        const now = new Date();
                        return root.nonAnimCurrMonth === now.getMonth() && root.nonAnimCurrYear === now.getFullYear();
                    }
                    onClicked: root.screenState.dashboardDate = new Date()

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    opacity: root.animOpacity
                    transform: Translate {
                        x: root.animTranslate
                    }

                    anchors.centerIn: parent
                    text: {
                        if (root.viewMode === "month")
                            return grid.title;
                        if (root.viewMode === "day")
                            return Qt.locale().toString(root.screenState.dashboardDate, "ddd, d MMM");
                        const start = root.startOfWeek(root.screenState.dashboardDate);
                        const end = root.addDays(start, 6);
                        return `${Qt.locale().toString(start, "d MMM")} – ${Qt.locale().toString(end, "d MMM")}`;
                    }
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
                }
            }

            IconButton {
                isRound: true
                icon: "chevron_right"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.navigate(1)
            }

            IconButton {
                isRound: true
                icon: "open_in_new"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: CalendarWindowFactory.open(root.screenState.dashboardDate, ShellState.forActive()?.modelData)
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Repeater {
                model: [{
                        key: "month",
                        label: Tr.tr("Month")
                    }, {
                        key: "week",
                        label: Tr.tr("Week")
                    }, {
                        key: "day",
                        label: Tr.tr("Day")
                    }]

                delegate: TextButton {
                    required property var modelData

                    text: modelData.label
                    type: root.viewMode === modelData.key ? TextButton.Filled : TextButton.Text
                    horizontalPadding: Tokens.padding.small
                    verticalPadding: Tokens.padding.extraSmall
                    font: Tokens.font.label.small
                    onClicked: root.setViewMode(modelData.key)
                }
            }
        }

        DayOfWeekRow {
            id: daysRow

            Layout.fillWidth: true
            visible: root.viewMode === "month"
            locale: grid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
            }
        }

        Item {
            Layout.fillWidth: true
            visible: root.viewMode === "month"
            implicitHeight: grid.implicitHeight

            opacity: root.animOpacity
            transform: Translate {
                x: root.animTranslate
            }

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear

                anchors.fill: parent

                spacing: 3
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem

                    required property var model

                    readonly property var events: {
                        CalendarEvents.events;
                        return CalendarEvents.eventsForDate(model.date);
                    }
                    readonly property bool selected: CalendarEvents.dateKey(model.date) === CalendarEvents.dateKey(root.screenState.dashboardDate)

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(text.implicitWidth, text.implicitHeight) + Tokens.padding.extraSmall * 2
                        height: width
                        radius: width / 2
                        color: dayItem.selected && !dayItem.model.today ? Colours.palette.m3primaryContainer : "transparent"
                    }

                    StyledText {
                        id: text

                        anchors.centerIn: parent

                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            if (dayItem.selected && !dayItem.model.today)
                                return Colours.palette.m3onPrimaryContainer;
                            const dayOfWeek = dayItem.model.date.getDay();
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return Colours.palette.m3tertiary;

                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font: Tokens.font.body.small
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        spacing: 2
                        visible: dayItem.events.length > 0

                        Repeater {
                            model: dayItem.events.slice(0, 3)

                            delegate: Rectangle {
                                required property var modelData

                                width: 4
                                height: 4
                                radius: 2
                                color: modelData.colour ?? Colours.palette.m3primary
                            }
                        }
                    }

                    TapHandler {
                        onTapped: root.screenState.dashboardDate = dayItem.model.date
                        onDoubleTapped: CalendarWindowFactory.open(dayItem.model.date, ShellState.forActive()?.modelData)
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                root.showPreview(dayItem, dayItem.model.date, dayItem.events);
                            else if (root.previewDay && CalendarEvents.dateKey(root.previewDay) === CalendarEvents.dateKey(dayItem.model.date))
                                root.previewDay = null;
                        }
                    }
                }
            }

            MaterialShape {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                property Item today

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today ? today.y - Tokens.padding.extraSmall - 1 : 0

                implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Tokens.padding.extraSmall * 2 : 0
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary

                opacity: todayItem ? 1 : 0

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.viewMode === "week"
            spacing: 3

            Repeater {
                model: 7

                delegate: StyledRect {
                    id: weekRow

                    required property int index

                    readonly property date dayDate: root.addDays(root.startOfWeek(root.screenState.dashboardDate), index)
                    readonly property var dayEvents: {
                        CalendarEvents.events;
                        return CalendarEvents.eventsForDate(dayDate);
                    }
                    readonly property bool selected: CalendarEvents.dateKey(dayDate) === CalendarEvents.dateKey(root.screenState.dashboardDate)

                    Layout.fillWidth: true
                    implicitHeight: Math.max(34, weekEvent.implicitHeight) + Tokens.padding.extraSmall * 2
                    color: selected ? Colours.palette.m3primaryContainer : (weekHover.hovered ? Colours.tPalette.m3surfaceContainerHigh : "transparent")
                    radius: Tokens.rounding.medium

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.small

                        ColumnLayout {
                            Layout.preferredWidth: 42
                            spacing: 0

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.locale().toString(weekRow.dayDate, "ddd")
                                color: weekRow.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.locale().toString(weekRow.dayDate, "d")
                                color: weekRow.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                            }
                        }

                        MiniEventCard {
                            id: weekEvent

                            Layout.fillWidth: true
                            visible: weekRow.dayEvents.length > 0
                            eventData: weekRow.dayEvents[0] ?? ({})
                            showDelete: true
                        }

                        StyledText {
                            visible: weekRow.dayEvents.length === 0
                            Layout.fillWidth: true
                            text: Tr.tr("No events")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }

                        StyledText {
                            visible: weekRow.dayEvents.length > 1
                            text: `+${weekRow.dayEvents.length - 1}`
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.small
                        }
                    }

                    HoverHandler {
                        id: weekHover

                        onHoveredChanged: {
                            if (hovered)
                                root.showPreview(weekRow, weekRow.dayDate, weekRow.dayEvents);
                            else if (root.previewDay && CalendarEvents.dateKey(root.previewDay) === CalendarEvents.dateKey(weekRow.dayDate))
                                root.previewDay = null;
                        }
                    }

                    TapHandler {
                        onTapped: root.screenState.dashboardDate = weekRow.dayDate
                        onDoubleTapped: CalendarWindowFactory.open(weekRow.dayDate, ShellState.forActive()?.modelData)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            visible: root.viewMode === "day"
            implicitHeight: 242

            StyledText {
                anchors.centerIn: parent
                visible: dayList.count === 0
                text: Tr.tr("No events for this day")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }

            ListView {
                id: dayList

                anchors.fill: parent
                clip: true
                spacing: Tokens.spacing.extraSmall
                model: {
                    CalendarEvents.events;
                    return CalendarEvents.eventsForDate(root.screenState.dashboardDate);
                }

                delegate: MiniEventCard {
                    required property var modelData

                    width: ListView.view.width
                    eventData: modelData
                    showDelete: true
                }
            }
        }
    }

    StyledRect {
        id: previewCard

        z: 100
        visible: root.previewDay !== null && root.previewEvents.length > 0
        x: root.previewX
        y: root.previewY
        width: Math.min(310, root.width - Tokens.padding.small * 2)
        implicitHeight: previewLayout.implicitHeight + Tokens.padding.medium * 2
        color: Colours.tPalette.m3surfaceContainerHighest
        radius: Tokens.rounding.large
        border.width: 1
        border.color: Colours.palette.m3outlineVariant

        ColumnLayout {
            id: previewLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.previewDay ? Qt.locale().toString(root.previewDay, "dddd, d MMMM") : ""
                color: Colours.palette.m3primary
                font: Tokens.font.title.small
                elide: Text.ElideRight
            }

            Repeater {
                model: root.previewEvents.slice(0, 4)

                delegate: MiniEventCard {
                    required property var modelData

                    Layout.fillWidth: true
                    eventData: modelData
                }
            }

            StyledText {
                visible: root.previewEvents.length > 4
                text: Tr.tr("+%1 more").arg(root.previewEvents.length - 4)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }
        }
    }

    component MiniEventCard: StyledRect {
        id: eventCard

        required property var eventData
        property bool showDelete

        implicitHeight: eventRow.implicitHeight + Tokens.padding.extraSmall * 2
        color: eventHover.hovered ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.small

        RowLayout {
            id: eventRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall
            spacing: Tokens.spacing.extraSmall

            Rectangle {
                Layout.fillHeight: true
                width: 3
                radius: 2
                color: eventCard.eventData.colour ?? Colours.palette.m3primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: eventCard.eventData.title ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const location = eventCard.eventData.location ? ` · ${eventCard.eventData.location}` : "";
                        return `${root.formatEventTime(eventCard.eventData)}${location}`;
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                visible: eventCard.eventData.recurring ?? false
                text: "repeat"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            IconButton {
                visible: eventCard.showDelete && eventCard.eventData.writable !== false
                icon: "delete"
                type: IconButton.Text
                padding: Tokens.padding.extraSmall
                onClicked: CalendarEvents.removeEvent(eventCard.eventData.id)
            }
        }

        HoverHandler {
            id: eventHover
        }

        TapHandler {
            onTapped: CalendarWindowFactory.open(new Date(eventCard.eventData.startMs), ShellState.forActive()?.modelData, eventCard.eventData)
        }
    }
}
