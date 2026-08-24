/*
    SPDX-FileCopyrightText: 2024 Kelvin Fonseca
    SPDX-License-Identifier: GPL-2.0-or-later

    Renders either the task icon or a dock-style window thumbnail.

    Geometry contract (matters for KWin minimize effects such as
    yet-another-magiclamp, which squash the window towards the task
    manager's published iconGeometry):

    - The published geometry is the whole task button.
    - Effects target buttonRect inset by half the FrameSvg "widgets/tasks"
      frame margins (see YetAnotherMagicLampEffect::iconMargins).
    - Therefore the thumbnail occupies exactly that same rect, using the
      same frame margin values, so the animation always lands on the
      visible thumbnail regardless of button width or icon spacing.

    The plain icon keeps the upstream task manager's icon-box geometry:
    a centered square on horizontal panels, full-width on vertical ones,
    and a compact square in group popup rows.
*/

import QtQuick
import Qt5Compat.GraphicalEffects as GE

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

Item {
    id: taskThumbnailSourceItem

    // --- inputs from the Task delegate ---
    property var decoration
    property var winIdList: []
    property bool highlighted
    property bool isLauncher
    property bool isMinimized
    property bool isHovered
    property bool drawThumbnail

    // Compact (group popup row) layout instead of a full task button.
    property bool compactLayout: false
    // Horizontal axis: 0 = left, 1 = centered, 2 = right (main.xml)
    property int iconAlignment: 1
    // Vertical axis: 0 = top, 1 = middle, 2 = bottom (main.xml)
    property int iconVerticalAlignment: 1
    // task.parent?.minimumWidth, needed to reproduce the upstream icon width.
    property real parentMinimumWidth: 0
    // FrameSvg "widgets/tasks" margins, matching the ones KWin effects read.
    property real frameMarginLeft: 0
    property real frameMarginRight: 0
    property real frameMarginTop: 0
    property real frameMarginBottom: 0

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool rightEdge: Plasmoid.location === PlasmaCore.Types.RightEdge
    readonly property bool bottomEdge: Plasmoid.location === PlasmaCore.Types.BottomEdge

    readonly property var winId: winIdList.length > 0 ? winIdList[0] : undefined

    property bool isCaptured: false

    // --- frame-margin fitting ---
    // Margins shrink proportionally when a button becomes too small to fit
    // them (mirroring upstream's adjustMargin), and every derived rect is
    // clamped, so squeezed tasks can never render outside their frame.
    function fittedMargin(available: real, margin: real): real {
        if (available <= 0 || margin <= 0) {
            return 0;
        }
        if (available - margin >= Kirigami.Units.iconSizes.small) {
            return margin;
        }
        return Math.max(0, Math.ceil((margin * (Kirigami.Units.iconSizes.small / available)) / 2));
    }

    readonly property real fittedMarginLeft: fittedMargin(width, frameMarginLeft)
    readonly property real fittedMarginRight: fittedMargin(width, frameMarginRight)
    readonly property real fittedMarginTop: fittedMargin(height, frameMarginTop)
    readonly property real fittedMarginBottom: fittedMargin(height, frameMarginBottom)
    readonly property real contentWidth: Math.max(0, width - fittedMarginLeft - fittedMarginRight)
    readonly property real contentHeight: Math.max(0, height - fittedMarginTop - fittedMarginBottom)

    // --- plain-icon geometry (upstream icon-box equivalent) ---
    readonly property real compactSide: Math.max(Kirigami.Units.iconSizes.sizeForLabels, Kirigami.Units.iconSizes.medium)

    readonly property real iconAreaWidth: compactLayout ? compactSide
        : vertical ? contentWidth
        : Math.max(0, Math.min(parentMinimumWidth, height) - fittedMarginLeft - fittedMarginRight)
    readonly property real iconAreaHeight: compactLayout ? compactSide
        : vertical ? Math.min(contentWidth, contentHeight)
        : contentHeight
    // Plain icons are ALWAYS centered in the task button, exactly like the
    // upstream task manager, independent of button width. The alignment
    // options only place the mini icon shown next to a thumbnail.
    readonly property real iconAreaX: compactLayout ? frameMarginLeft
        : (width - iconAreaWidth) / 2
    readonly property real iconAreaY: compactLayout ? frameMarginTop
        : (height - iconAreaHeight) / 2

    // Position of the mini icon shown next to a thumbnail. Both alignments
    // apply relative to the task area on every orientation: the horizontal
    // one places it left/center/right, the vertical one top/middle/bottom.
    // It shrinks with the button instead of overflowing it.
    readonly property real miniIconInset: Kirigami.Units.smallSpacing
    readonly property real miniIconSize: Math.max(0,
        Math.min(Kirigami.Units.gridUnit,
                 thumbWidth - 2 * miniIconInset,
                 thumbHeight - 2 * miniIconInset))
    readonly property real miniIconX: iconAlignment === 0 ? miniIconInset
        : iconAlignment === 2 ? width - miniIconSize - miniIconInset
        : (width - miniIconSize) / 2
    readonly property real miniIconY: iconVerticalAlignment === 0 ? miniIconInset
        : iconVerticalAlignment === 2 ? height - miniIconSize - miniIconInset
        : (height - miniIconSize) / 2

    // --- thumbnail geometry: published button rect inset by frame margins ---
    // Mirrors YetAnotherMagicLampEffect::iconMargins exactly: it builds
    // QMarginsF(left, top, left, top), i.e. the left/top margin values are
    // used for all four sides. insetFactor pairs with that effect's margin
    // multiplier (1.0 = legacy sizing inside the content area).
    readonly property real thumbInsetFactor: 1
    readonly property real thumbX: compactLayout ? frameMarginLeft : fittedMarginLeft * thumbInsetFactor
    readonly property real thumbY: compactLayout ? frameMarginTop : fittedMarginTop * thumbInsetFactor
    readonly property real thumbWidth: compactLayout ? compactSide
        : Math.max(0, width - 2 * fittedMarginLeft * thumbInsetFactor)
    readonly property real thumbHeight: compactLayout ? compactSide
        : Math.max(0, height - 2 * fittedMarginTop * thumbInsetFactor)

    function resetThumbnail(redraw = true) {
        isCaptured = false

        if (redraw) {
            thumbnailClipperBehavior.enabled = false
            thumbnailClipper.clipProgress = 0
        }
    }

    onIsHoveredChanged: {
        if (!drawThumbnail || !isCaptured) {
            return
        }

        if (isHovered) {
            resetThumbnail(false)
        }
    }

    onDrawThumbnailChanged: {
        if (!drawThumbnail) {
            resetThumbnail()
        }
    }

    // Shrunken icon while a thumbnail is shown, full icon otherwise.
    Item {
        id: iconContainer

        z: 2

        states: [
            State {
                name: "active"
                when: !taskThumbnailSourceItem.drawThumbnail

                PropertyChanges {
                    iconContainer.x: taskThumbnailSourceItem.iconAreaX
                    iconContainer.y: taskThumbnailSourceItem.iconAreaY
                    iconContainer.width: taskThumbnailSourceItem.iconAreaWidth
                    iconContainer.height: taskThumbnailSourceItem.iconAreaHeight
                }
            },
            State {
                name: "thumbnail"
                when: taskThumbnailSourceItem.drawThumbnail

                PropertyChanges {
                    iconContainer.x: taskThumbnailSourceItem.miniIconX
                    iconContainer.y: taskThumbnailSourceItem.miniIconY
                    iconContainer.width: taskThumbnailSourceItem.miniIconSize
                    iconContainer.height: taskThumbnailSourceItem.miniIconSize
                }
            }
        ]

        transitions: [
            // Only animate real minimize/restore morphs. An unqualified
            // transition would also fire on creation ("" -> active) while the
            // button geometry is still settling, making new icons appear to
            // grow from the top-left corner.
            Transition {
                from: "active"
                to: "thumbnail"

                NumberAnimation {
                    properties: "x,y,width,height"
                    duration: Kirigami.Units.longDuration
                }
            },
            Transition {
                from: "thumbnail"
                to: "active"

                NumberAnimation {
                    properties: "x,y,width,height"
                    duration: Kirigami.Units.longDuration
                }
            }
        ]

        Kirigami.Icon {
            id: icon
            source: taskThumbnailSourceItem.decoration
            anchors.fill: parent
            enabled: true
            active: taskThumbnailSourceItem.highlighted
        }
    }

    // Invisible capture surface: grabs one frame of the live stream, then
    // deactivates until something invalidates the frozen thumbnail.
    Loader {
        id: taskPipeWireLoader

        x: taskThumbnailSourceItem.thumbX
        y: taskThumbnailSourceItem.thumbY
        width: taskThumbnailSourceItem.thumbWidth
        height: taskThumbnailSourceItem.thumbHeight
        opacity: 0

        active: !taskThumbnailSourceItem.isLauncher
            && taskThumbnailSourceItem.drawThumbnail
            && !taskThumbnailSourceItem.isCaptured

        asynchronous: true
        sourceComponent: PipeWire.PipeWireSourceItem {
            id: pipeWireSourceItem
            nodeId: taskWaylandItem.nodeId

            TaskManager.ScreencastingRequest {
                id: taskWaylandItem
                uuid: taskThumbnailSourceItem.winId
            }

            onReadyChanged: {
                if (!ready) {
                    return
                }

                pipeWireSourceItem.grabToImage(function(result) {
                    frozenThumbnail.item.source = result.url
                    thumbnailClipperBehavior.enabled = true
                    thumbnailClipper.clipProgress = taskThumbnailSourceItem.vertical
                        ? taskThumbnailSourceItem.thumbWidth
                        : taskThumbnailSourceItem.thumbHeight
                })
            }
        }
    }

    // Soft shadow behind the revealed region. Lives OUTSIDE the clipper so
    // the shadow is never clipped by the reveal window. It sources the
    // clipper itself, whose painted content already has the image
    // compensation applied, so the shadow quad must track the clipper's
    // animated position and size exactly (anchors.fill) or its embedded
    // source copy would drift against the live foreground.
    Loader {
        id: shadowLoader
        active: taskThumbnailSourceItem.drawThumbnail
            && frozenThumbnail.item !== undefined
            && frozenThumbnail.item.status == Image.Ready

        asynchronous: true
        visible: status === Loader.Ready // Only show when fully loaded
        anchors.fill: thumbnailClipper
        z: -1

        sourceComponent: GE.DropShadow {
            anchors.fill: parent
            horizontalOffset: 0
            verticalOffset: 0
            radius: 3
            samples: 7
            transparentBorder: true
            cached: true
            color: "Black"
            source: thumbnailClipper
        }
    }

    // Reveals the frozen thumbnail with an animated wipe from the panel edge.
    Item {
        id: thumbnailClipper
        clip: true

        property real clipProgress: 0

        x: {
            if (vertical && rightEdge) {
                return taskThumbnailSourceItem.thumbX + taskThumbnailSourceItem.thumbWidth - clipProgress
            }
            return taskThumbnailSourceItem.thumbX
        }
        y: !vertical && bottomEdge
            ? taskThumbnailSourceItem.thumbY + taskThumbnailSourceItem.thumbHeight - clipProgress
            : taskThumbnailSourceItem.thumbY
        width: vertical ? clipProgress : taskThumbnailSourceItem.thumbWidth
        height: vertical ? taskThumbnailSourceItem.thumbHeight : clipProgress

        Behavior on clipProgress {
            id: thumbnailClipperBehavior
            enabled: false
            SequentialAnimation {
                PauseAnimation { duration: Kirigami.Units.shortDuration * 2 }
                NumberAnimation {
                    duration: Kirigami.Units.longDuration * (taskThumbnailSourceItem.isMinimized ? 2 : 0)
                    easing.type: Easing.Quart
                }
            }
        }

        Loader {
            id: frozenThumbnail
            active: taskThumbnailSourceItem.drawThumbnail

            // Keep the image fixed in button space while the clip window
            // grows from the panel edge: the child lives in clipper
            // coordinates, so cancel the clipper's origin offset (note the
            // sign) so only the revealed region changes, never the image
            // position.
            x: taskThumbnailSourceItem.thumbX - thumbnailClipper.x
            y: taskThumbnailSourceItem.thumbY - thumbnailClipper.y
            width: taskThumbnailSourceItem.thumbWidth
            height: taskThumbnailSourceItem.thumbHeight

            sourceComponent: Image {
                id: frozenThumbnailImage
                onSourceChanged: { taskThumbnailSourceItem.isCaptured = true }
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }
    }
}
