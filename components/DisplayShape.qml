import QtQuick
import qs.Common
import "mirrorGeometry.js" as Geometry

// A display drawn in its true proportions. With a source size, it also shows where the mirrored picture lands.
Item {
    id: root

    property real displayWidth: 0
    property real displayHeight: 0
    property real sourceWidth: 0
    property real sourceHeight: 0
    property string scaling: "fit"
    property bool filled: false
    property color color: Theme.surfaceText
    property real outlineWidth: Theme.outlineWidthFocused

    readonly property bool sized: displayWidth > 0 && displayHeight > 0
    readonly property real aspect: sized ? displayWidth / displayHeight : 16 / 10
    readonly property real frameWidth: Math.min(width, height * aspect)
    readonly property real frameHeight: frameWidth / aspect
    readonly property bool showsPicture: sized && sourceWidth > 0 && sourceHeight > 0
    readonly property var picture: Geometry.pictureSize(sourceWidth, sourceHeight, displayWidth, displayHeight, scaling)
    readonly property real frameScale: sized ? frameWidth / displayWidth : 1
    readonly property bool animated: !SettingsData.reduceMotion && Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None

    implicitWidth: Theme.iconSize + Theme.spacingS
    implicitHeight: Theme.iconSize
    Accessible.ignored: true

    Item {
        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        clip: true

        Rectangle {
            anchors.centerIn: parent
            width: root.showsPicture ? root.picture.width * root.frameScale : parent.width
            height: root.showsPicture ? root.picture.height * root.frameScale : parent.height
            visible: root.showsPicture || root.filled
            color: root.color

            Behavior on width {
                enabled: root.animated
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.standard
                }
            }

            Behavior on height {
                enabled: root.animated
                NumberAnimation {
                    duration: Theme.expressiveDurations.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.expressiveCurves.standard
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.frameWidth
        height: root.frameHeight
        radius: Theme.cornerRadiusXXS
        color: "transparent"
        border.width: root.outlineWidth
        border.color: root.color
    }
}
