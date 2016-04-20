import QtQuick 2.0

import SocketGame 1.0

Entity {
    id: root

    property bool base: true
    property real spawnInterval: 120*1000 / (energy * energy / (defaultEnergy * defaultEnergy))
//    property real spawnInterval: 2000
    property real timeSinceSpawn: 0.0

    defaultEnergy: 5.0
    energy: 7.0
    maximumEnergy: 10.0

    persistentProperties: QtObject {
        property alias spawnInterval: root.spawnInterval
        property alias timeSinceSpawn: root.timeSinceSpawn
        property alias maximumEnergy: root.maximumEnergy
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

    Behavior on timeSinceSpawn {
        NumberAnimation {
            duration: root.animationDuration
        }
    }
}
