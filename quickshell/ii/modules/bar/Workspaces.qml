import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    
    // Dynamic workspace list grows from 1..maxVisited
    property var dynamicWorkspaces: []
    property int maxVisitedWorkspaceId: 1
    // Mixed list of either numbers (workspace ids) or { type: "ellipsis" }
    property var visibleItems: []

    property int widgetPadding: 4
    property int workspaceButtonWidth: 26
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4

    property bool showNumbers: false
    Timer {
        id: showNumbersTimer
        interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
        repeat: false
        onTriggered: { root.showNumbers = true }
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
            if (GlobalStates.superDown) showNumbersTimer.restart();
            else { showNumbersTimer.stop(); root.showNumbers = false; }
        }
        function onSuperReleaseMightTriggerChanged() { showNumbersTimer.stop() }
    }

    // Build base dynamic list 1..maxVisited
    function updateDynamicWorkspaces() {
        var currentWorkspaceId = monitor?.activeWorkspace?.id;
        if (currentWorkspaceId && currentWorkspaceId > 0 && currentWorkspaceId > maxVisitedWorkspaceId) {
            maxVisitedWorkspaceId = currentWorkspaceId;
        }
        var newWorkspaces = [];
        for (var i = 1; i <= maxVisitedWorkspaceId; i++) newWorkspaces.push(i);
        dynamicWorkspaces = newWorkspaces;
        buildVisibleItems();
    }

    function isOccupied(id) {
        return Hyprland.workspaces.values.some(ws => ws.id === id);
    }

    function clampUniqueSorted(arr) {
        // remove duplicates and sort ascending
        var s = new Set(arr.filter(x => typeof x === 'number'));
        return Array.from(s).sort((a,b)=>a-b);
    }

    function addRange(out, start, end) {
        for (var i = start; i <= end; i++) out.push(i);
    }

    function buildVisibleItems() {
        var firstN = Math.min(Config.options.bar.workspaces.alwaysShowFirstN, dynamicWorkspaces.length);
        var maxDots = Math.max(5, Config.options.bar.workspaces.maxVisibleDots);
        var neighborSpan = Math.max(0, Config.options.bar.workspaces.neighborSpan);
        var tailSpan = Math.max(0, Config.options.bar.workspaces.tailSpan);
        var showTail = Config.options.bar.workspaces.showTail;

        var current = monitor?.activeWorkspace?.id || 1;
        var lastVisited = dynamicWorkspaces.length;

        var selected = [];
        // Always first N
        addRange(selected, 1, firstN);
        // Current ± neighbors
        addRange(selected, Math.max(firstN+1, current - neighborSpan), Math.min(lastVisited, current + neighborSpan));
        // Tail (highest visited) cluster
        if (showTail) addRange(selected, Math.max(firstN+1, lastVisited - tailSpan), lastVisited);

        selected = clampUniqueSorted(selected);

        // If too many, reduce middle neighbors first
        while (selected.length > maxDots) {
            // Try removing farthest from current but not in firstN nor tail cluster
            var removable = selected.filter(id => id > firstN && id < (lastVisited - tailSpan) && Math.abs(id - current) > neighborSpan);
            if (removable.length === 0) break;
            // remove the farthest
            var far = removable.sort((a,b)=>Math.abs(b-current)-Math.abs(a-current))[0];
            selected = selected.filter(id => id !== far);
        }

        // Build items with ellipsis between non-consecutive blocks
        var items = [];
        var prev = null;
        for (var i = 0; i < selected.length; i++) {
            var id = selected[i];
            if (prev !== null && id !== prev + 1) {
                items.push({ type: 'ellipsis' });
            }
            items.push(id);
            prev = id;
        }
        visibleItems = items;
    }

    // Initialize and update
    Component.onCompleted: updateDynamicWorkspaces()
    Connections { target: Hyprland.workspaces; function onValuesChanged() { updateDynamicWorkspaces(); } }
    Connections { target: monitor; function onActiveWorkspaceChanged() { updateDynamicWorkspaces(); } }
    Timer { id: workspaceUpdateTimer; interval: 150; repeat: true; running: true; onTriggered: updateDynamicWorkspaces() }

    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: Appearance.sizes.barHeight

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0) Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0) Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.BackButton; onPressed: (event) => { if (event.button === Qt.BackButton) Hyprland.dispatch(`togglespecialworkspace`); } }

    // Background row (workspace occupancy ribbons)
    RowLayout {
        id: rowLayout
        z: 1
        spacing: 0
        anchors.fill: parent
        implicitHeight: Appearance.sizes.barHeight

        Repeater {
            model: root.visibleItems

            Item {
                width: workspaceButtonWidth
                height: workspaceButtonWidth

                // Ellipsis cell
                Loader {
                    anchors.fill: parent
                    active: (typeof modelData === 'object' && modelData?.type === 'ellipsis')
                    sourceComponent: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: workspaceButtonWidth * 0.4
                            height: workspaceButtonWidth * 0.22
                            radius: height/2
                            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1Inactive, 0.2)
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: workspaceButtonWidth * 0.08
                            Repeater { model: 3
                                Rectangle {
                                    width: workspaceButtonWidth * 0.06
                                    height: width
                                    radius: width/2
                                    color: Appearance.colors.colOnLayer1Inactive
                                }
                            }
                        }
                    }
                }

                // Workspace occupancy ribbon
                Loader {
                    anchors.fill: parent
                    active: (typeof modelData === 'number')
                    sourceComponent: Rectangle {
                        z: 1
                        implicitWidth: workspaceButtonWidth
                        implicitHeight: workspaceButtonWidth
                        radius: Appearance.rounding.full
                        property int workspaceId: modelData
                        property int idx: index
                        property bool isCurrentOccupied: isOccupied(workspaceId)
                        // Neighbors in visible sequence
                        property bool leftOccupied: idx > 0 && typeof root.visibleItems[idx-1] === 'number' && isOccupied(root.visibleItems[idx-1])
                        property bool rightOccupied: idx < (root.visibleItems.length - 1) && typeof root.visibleItems[idx+1] === 'number' && isOccupied(root.visibleItems[idx+1])
                        property var radiusLeft: leftOccupied ? 0 : Appearance.rounding.full
                        property var radiusRight: rightOccupied ? 0 : Appearance.rounding.full
                        topLeftRadius: radiusLeft
                        bottomLeftRadius: radiusLeft
                        topRightRadius: radiusRight
                        bottomRightRadius: radiusRight
                        color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
                        opacity: isCurrentOccupied ? 1 : 0.25
                        Behavior on opacity { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }
                        Behavior on radiusLeft { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }
                        Behavior on radiusRight { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }
                    }
                }
            }
        }
    }

    // Active workspace indicator
    Rectangle {
        z: 2
        property real activeWorkspaceMargin: 2
        implicitHeight: workspaceButtonWidth - activeWorkspaceMargin * 2
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        anchors.verticalCenter: parent.verticalCenter

        property int activeIndex: {
            for (var i = 0; i < root.visibleItems.length; i++) {
                if (typeof root.visibleItems[i] === 'number' && root.visibleItems[i] === monitor?.activeWorkspace?.id) return i;
            }
            return -1;
        }
        visible: activeIndex >= 0
        x: activeIndex >= 0 ? activeIndex * workspaceButtonWidth + activeWorkspaceMargin : 0
        implicitWidth: workspaceButtonWidth - activeWorkspaceMargin * 2
        Behavior on activeWorkspaceMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on visible { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
    }

    // Foreground: numbers/dots and interactions
    RowLayout {
        id: rowLayoutNumbers
        z: 3
        spacing: 0
        anchors.fill: parent
        implicitHeight: Appearance.sizes.barHeight

        Repeater {
            model: root.visibleItems

            Item {
                width: workspaceButtonWidth
                height: workspaceButtonWidth

                // Ellipsis cell (no interaction)
                Loader {
                    anchors.fill: parent
                    active: (typeof modelData === 'object' && modelData?.type === 'ellipsis')
                    sourceComponent: Item { }
                }

                // Workspace button
                Loader {
                    anchors.fill: parent
                    active: (typeof modelData === 'number')
                    sourceComponent: Button {
                        id: button
                        property int workspaceValue: modelData
                        Layout.fillHeight: true
                        onPressed: Hyprland.dispatch(`workspace ${workspaceValue}`)
                        width: workspaceButtonWidth
                        background: Item {
                            id: workspaceButtonBackground
                            implicitWidth: workspaceButtonWidth
                            implicitHeight: workspaceButtonWidth
                            property var biggestWindow: HyprlandData.biggestWindowForWorkspace(button.workspaceValue)
                            property var mainAppIconSource: Quickshell.iconPath(AppSearch.guessIcon(biggestWindow?.class), "image-missing")
                            StyledText {
                                opacity: root.showNumbers || ((Config.options?.bar.workspaces.alwaysShowNumbers && (!Config.options?.bar.workspaces.showAppIcons || !workspaceButtonBackground.biggestWindow || root.showNumbers)) || (root.showNumbers && !Config.options?.bar.workspaces.showAppIcons)) ? 1 : 0
                                z: 3
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                                text: `${button.workspaceValue}`
                                elide: Text.ElideRight
                                color: (monitor?.activeWorkspace?.id == button.workspaceValue) ? Appearance.m3colors.m3onPrimary : (isOccupied(button.workspaceValue) ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1Inactive)
                                Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                            }
                            Rectangle {
                                id: wsDot
                                opacity: (Config.options?.bar.workspaces.alwaysShowNumbers || root.showNumbers || (Config.options?.bar.workspaces.showAppIcons && workspaceButtonBackground.biggestWindow)) ? 0 : 1
                                visible: opacity > 0
                                anchors.centerIn: parent
                                width: workspaceButtonWidth * 0.18
                                height: width
                                radius: width / 2
                                color: (monitor?.activeWorkspace?.id == button.workspaceValue) ? Appearance.m3colors.m3onPrimary : (isOccupied(button.workspaceValue) ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1Inactive)
                                Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                            }
                            Item {
                                anchors.centerIn: parent
                                width: workspaceButtonWidth
                                height: workspaceButtonWidth
                                opacity: !Config.options?.bar.workspaces.showAppIcons ? 0 : (workspaceButtonBackground.biggestWindow && !root.showNumbers && Config.options?.bar.workspaces.showAppIcons) ? 1 : workspaceButtonBackground.biggestWindow ? workspaceIconOpacityShrinked : 0
                                visible: opacity > 0
                                IconImage {
                                    id: mainAppIcon
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    anchors.bottomMargin: (!root.showNumbers && Config.options?.bar.workspaces.showAppIcons) ? (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                                    anchors.rightMargin: (!root.showNumbers && Config.options?.bar.workspaces.showAppIcons) ? (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                                    source: workspaceButtonBackground.mainAppIconSource
                                    implicitSize: (!root.showNumbers && Config.options?.bar.workspaces.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked
                                    Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                    Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                    Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                    Behavior on implicitSize { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                }
                                Loader {
                                    active: Config.options.bar.workspaces.monochromeIcons
                                    anchors.fill: mainAppIcon
                                    sourceComponent: Item {
                                        Desaturate { id: desaturatedIcon; visible: false; anchors.fill: parent; source: mainAppIcon; desaturation: 0.8 }
                                        ColorOverlay { anchors.fill: desaturatedIcon; source: desaturatedIcon; color: ColorUtils.transparentize(wsDot.color, 0.9) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
