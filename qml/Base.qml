import QtQuick 2.0

import SocketGame 1.0

Entity {
    id: root

    property bool base: true
    property real spawnInterval: 60*1000 / (energy * energy / (defaultEnergy * defaultEnergy))
//    property real spawnInterval: 2000
    property real timeSinceSpawn: 0.0
    property vector2d target

    defaultEnergy: 10.0
    energy: 10.0
    maximumEnergy: 20.0

    persistentProperties: QtObject {
        property alias spawnInterval: root.spawnInterval
        property alias timeSinceSpawn: root.timeSinceSpawn
        property alias maximumEnergy: root.maximumEnergy
        property alias targetX: root.target.x
        property alias targetY: root.target.y
    }

    filename: "Base.qml"

    width: 40
    height: 40
    Rectangle {
        anchors.fill: parent
        radius: width * 0.2
        color: root.player.color
        border.color: Qt.lighter(root.player.color, energy);
        border.width: 2.0
    }

    Rectangle {
        anchors {
            top: parent.bottom
            left: parent.left
            topMargin: 4
        }
        color: player.color
        width: parent.width * timeSinceSpawn / spawnInterval
        height: 4
    }

    Rectangle {
        id: targetRectangle
        x: root.selected ? (root.target.x - root.x / scaleFactor) * scaleFactor - width * 0.5 : 0
        y: root.selected ? (root.target.y - root.y / scaleFactor) * scaleFactor - height * 0.5 : 0
        visible: root.selected
        width: 10
        height: width
        radius: width * 0.25
        color: Qt.lighter(root.player.color, 1.5)

        SequentialAnimation {
            running: true
            loops: Animation.Infinite
            NumberAnimation {
                target: targetRectangle
                property: "width"
                duration: 600
                easing.type: Easing.InOutQuad
                from: 6
                to: 12
            }
            NumberAnimation {
                target: targetRectangle
                property: "width"
                duration: 600
                easing.type: Easing.InOutQuad
                from: 12
                to: 6
            }
        }
    }

    Behavior on timeSinceSpawn {
        NumberAnimation {
            duration: root.animationDuration
        }
    }
}
