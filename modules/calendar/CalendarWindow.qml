pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

FloatingWindow {
    id: root

    property date selectedDate: new Date()
    property date displayDate: new Date()
    property bool editing
    property string editingId: ""
    property string draftTitle: ""
    property string draftDate: ""
    property string draftStart: "09:00"
    property string draftEnd: "10:00"
    property string draftLocation: ""
    property string draftNotes: ""
    property bool draftAllDay

    readonly property var selectedEvents: {
        CalendarEvents.events;
        return CalendarEvents.eventsForDate(selectedDate);
    }
    readonly property real availableWidth: Math.max(800, screen.width - 96)
    readonly property real availableHeight: Math.max(560, screen.height - 96)

    signal closing

    function pad(value) {
        return String(value).padStart(2, "0");
    }

    function dateInput(date) {
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }

    function timeInput(ms) {
        const date = new Date(ms);
        return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
    }

    function parseDateTime(dateText, timeText) {
        const dateParts = dateText.split("-").map(Number);
        const timeParts = timeText.split(":").map(Number);
        if (dateParts.length !== 3 || dateParts.some(isNaN) || timeParts.length !== 2 || timeParts.some(isNaN))
            return null;
        const value = new Date(dateParts[0], dateParts[1] - 1, dateParts[2], timeParts[0], timeParts[1]);
        return isNaN(value.getTime()) ? null : value;
    }

    function formatDay(date) {
        return Qt.locale().toString(date, "dddd, d MMMM");
    }

    function formatEventTime(event) {
        if (event.allDay)
            return Tr.tr("All day");
        return `${Qt.locale().toString(new Date(event.startMs), "HH:mm")}–${Qt.locale().toString(new Date(event.endMs), "HH:mm")}`;
    }

    function beginCreate() {
        editingId = "";
        draftTitle = "";
        draftDate = dateInput(selectedDate);
        draftStart = "09:00";
        draftEnd = "10:00";
        draftLocation = "";
        draftNotes = "";
        draftAllDay = false;
        editing = true;
    }

    function beginEdit(event) {
        editingId = event.id;
        draftTitle = event.title;
        draftDate = dateInput(new Date(event.startMs));
        draftStart = timeInput(event.startMs);
        draftEnd = timeInput(event.endMs);
        draftLocation = event.location ?? "";
        draftNotes = event.notes ?? "";
        draftAllDay = event.allDay ?? false;
        editing = true;
    }

    function saveEditor() {
        const start = parseDateTime(draftDate, draftAllDay ? "00:00" : draftStart);
        if (!start || !draftTitle.trim()) {
            Toaster.toast(Tr.tr("Unable to save event"), Tr.tr("Enter a title and a valid date."), "event_busy");
            return;
        }

        let end;
        if (draftAllDay)
            end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1);
        else
            end = parseDateTime(draftDate, draftEnd);

        if (!end || end <= start) {
            Toaster.toast(Tr.tr("Unable to save event"), Tr.tr("The end time must be after the start time."), "event_busy");
            return;
        }

        const properties = {
            title: draftTitle.trim(),
            startMs: start.getTime(),
            endMs: end.getTime(),
            allDay: draftAllDay,
            location: draftLocation.trim(),
            notes: draftNotes.trim()
        };

        if (editingId)
            CalendarEvents.updateEvent(editingId, properties);
        else
            CalendarEvents.addEvent(properties);

        selectedDate = start;
        displayDate = start;
        editing = false;
    }

    title: Tr.tr("Calendar")
    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false

    implicitWidth: Math.min(1180, availableWidth)
    implicitHeight: Math.min(780, availableHeight)
    minimumSize.width: Math.min(850, availableWidth)
    minimumSize.height: Math.min(580, availableHeight)

    contentItem.Config.screen: screen.name
    contentItem.Tokens.screen: screen.name

    onVisibleChanged: {
        if (!visible) {
            closing();
            destroy();
        }
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.tPalette.m3surface
        radius: Tokens.rounding.extraLarge

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            spacing: Tokens.spacing.large

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    text: Tr.tr("Calendar")
                    font: Tokens.font.title.large
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: Tr.tr("Today")
                    type: TextButton.Text
                    onClicked: {
                        root.selectedDate = new Date();
                        root.displayDate = new Date();
                        root.editing = false;
                    }
                }

                TextButton {
                    text: Tr.tr("New event")
                    type: TextButton.Filled
                    onClicked: root.beginCreate()
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: root.visible = false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.large

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    color: Colours.tPalette.m3surfaceContainer
                    radius: Tokens.rounding.large

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.medium

                        RowLayout {
                            Layout.fillWidth: true

                            IconButton {
                                icon: "chevron_left"
                                type: IconButton.Text
                                onClicked: root.displayDate = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() - 1, 1)
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: monthGrid.title
                                color: Colours.palette.m3primary
                                font: Tokens.font.title.medium
                            }

                            IconButton {
                                icon: "chevron_right"
                                type: IconButton.Text
                                onClicked: root.displayDate = new Date(root.displayDate.getFullYear(), root.displayDate.getMonth() + 1, 1)
                            }
                        }

                        DayOfWeekRow {
                            Layout.fillWidth: true
                            locale: monthGrid.locale

                            delegate: StyledText {
                                required property var model

                                horizontalAlignment: Text.AlignHCenter
                                text: model?.shortName ?? ""
                                color: Colours.palette.m3onSurfaceVariant
                                font: root.contentItem.Tokens.font.label.medium
                            }
                        }

                        MonthGrid {
                            id: monthGrid

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            month: root.displayDate.getMonth()
                            year: root.displayDate.getFullYear()
                            locale: Qt.locale()
                            spacing: Tokens.spacing.extraSmall

                            delegate: Item {
                                id: dayCell

                                required property var model

                                readonly property date cellDate: model?.date ?? new Date()
                                readonly property int cellMonth: model?.month ?? -1
                                readonly property int dayNumber: model?.day ?? 0
                                readonly property bool isToday: model?.today ?? false
                                readonly property var dayEvents: {
                                    CalendarEvents.events;
                                    return CalendarEvents.eventsForDate(cellDate);
                                }
                                readonly property bool selected: CalendarEvents.dateKey(cellDate) === CalendarEvents.dateKey(root.selectedDate)

                                implicitWidth: 80
                                implicitHeight: 64

                                StyledRect {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: root.contentItem.Tokens.rounding.medium
                                    color: dayCell.selected ? Colours.palette.m3primaryContainer : (hoverHandler.hovered ? Colours.tPalette.m3surfaceContainerHigh : "transparent")

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: root.contentItem.Tokens.spacing.extraSmall

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: monthGrid.locale.toString(dayCell.dayNumber)
                                            color: dayCell.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                            opacity: dayCell.cellMonth === monthGrid.month ? 1 : 0.35
                                            font: dayCell.isToday ? root.contentItem.Tokens.font.body.builders.medium.weight(Font.Bold).build() : root.contentItem.Tokens.font.body.medium
                                        }

                                        Row {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 3
                                            visible: dayCell.dayEvents.length > 0

                                            Repeater {
                                                model: dayCell.dayEvents.slice(0, 3)

                                                delegate: Rectangle {
                                                    required property var modelData

                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    color: modelData.colour ?? Colours.palette.m3primary
                                                }
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: hoverHandler
                                    }

                                    TapHandler {
                                        onTapped: {
                                            root.selectedDate = dayCell.cellDate;
                                            root.editing = false;
                                        }
                                        onDoubleTapped: {
                                            root.selectedDate = dayCell.cellDate;
                                            root.beginCreate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    color: Colours.tPalette.m3surfaceContainer
                    radius: Tokens.rounding.large

                    Loader {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        sourceComponent: root.editing ? editorComponent : agendaComponent
                    }
                }
            }
        }
    }

    Component {
        id: agendaComponent

        ColumnLayout {
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                text: root.formatDay(root.selectedDate)
                font: Tokens.font.title.small
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.selectedEvents.length === 0
                text: Tr.tr("No events for this day")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
                horizontalAlignment: Text.AlignHCenter
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small
                clip: true
                model: root.selectedEvents

                delegate: StyledRect {
                    id: eventCard

                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: eventLayout.implicitHeight + Tokens.padding.large * 2
                    color: Colours.tPalette.m3surfaceContainerHigh
                    radius: Tokens.rounding.medium

                    RowLayout {
                        id: eventLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.medium

                        Rectangle {
                            Layout.fillHeight: true
                            width: 4
                            radius: 2
                            color: eventCard.modelData.colour ?? Colours.palette.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            StyledText {
                                Layout.fillWidth: true
                                text: eventCard.modelData.title
                                font: Tokens.font.body.large
                                wrapMode: Text.WordWrap
                            }

                            StyledText {
                                text: root.formatEventTime(eventCard.modelData)
                                color: Colours.palette.m3primary
                                font: Tokens.font.label.medium
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: !!eventCard.modelData.location
                                text: eventCard.modelData.location ?? ""
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }
                        }
                    }

                    TapHandler {
                        onTapped: root.beginEdit(eventCard.modelData)
                    }
                }
            }

            TextButton {
                Layout.alignment: Qt.AlignRight
                text: Tr.tr("Add event")
                type: TextButton.Filled
                onClicked: root.beginCreate()
            }
        }
    }

    Component {
        id: editorComponent

        Flickable {
            contentHeight: editorLayout.implicitHeight
            clip: true

            ColumnLayout {
                id: editorLayout

                width: parent.width
                spacing: Tokens.spacing.medium

                StyledText {
                    text: root.editingId ? Tr.tr("Edit event") : Tr.tr("New event")
                    font: Tokens.font.title.small
                }

                StyledTextField {
                    id: editorTitle

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Title")
                    text: root.draftTitle
                    emptyIsValid: false
                    errorText: Tr.tr("A title is required")
                    onTextEdited: root.draftTitle = text
                }

                StyledTextField {
                    id: editorDate

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Date (YYYY-MM-DD)")
                    text: root.draftDate
                    validate: /^\d{4}-\d{2}-\d{2}$/
                    emptyIsValid: false
                    onTextEdited: root.draftDate = text
                }

                TextButton {
                    id: allDayButton

                    checked: root.draftAllDay
                    text: checked ? Tr.tr("All day") : Tr.tr("Timed event")
                    type: checked ? TextButton.Filled : TextButton.Text
                    onClicked: root.draftAllDay = !root.draftAllDay
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.draftAllDay

                    StyledTextField {
                        id: editorStart

                        Layout.fillWidth: true
                        placeholderText: Tr.tr("Start (HH:MM)")
                        text: root.draftStart
                        validate: /^([01]\d|2[0-3]):[0-5]\d$/
                        emptyIsValid: false
                        onTextEdited: root.draftStart = text
                    }

                    StyledTextField {
                        id: editorEnd

                        Layout.fillWidth: true
                        placeholderText: Tr.tr("End (HH:MM)")
                        text: root.draftEnd
                        validate: /^([01]\d|2[0-3]):[0-5]\d$/
                        emptyIsValid: false
                        onTextEdited: root.draftEnd = text
                    }
                }

                StyledTextField {
                    id: editorLocation

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Location")
                    text: root.draftLocation
                    onTextEdited: root.draftLocation = text
                }

                StyledTextField {
                    id: editorNotes

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Notes")
                    text: root.draftNotes
                    onTextEdited: root.draftNotes = text
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.medium

                    TextButton {
                        visible: !!root.editingId
                        text: Tr.tr("Delete")
                        type: TextButton.Text
                        onClicked: {
                            CalendarEvents.removeEvent(root.editingId);
                            root.editing = false;
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: Tr.trCtx("Cancel", "button")
                        type: TextButton.Text
                        onClicked: root.editing = false
                    }

                    TextButton {
                        text: Tr.tr("Save")
                        type: TextButton.Filled
                        onClicked: root.saveEditor()
                    }
                }
            }
        }
    }
}
