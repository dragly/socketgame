import QtQuick 2.0

import SocketGame 1.0

GameObject {
    id: root

    property int entityId: -1
    property string filename: "Entity.qml"
    property bool toBeDeleted: false
    property var player
    property int playerId: player ? player.playerId : -1
    property vector2d position
    property var neighbors: []
    property real animationDuration: 0

    x: visible ? position.x * scaleFactor - height * 0.5 : 0
    y: visible ? position.y * scaleFactor - width * 0.5 : 0

    Behavior on x {
        NumberAnimation {
            duration: Math.min(500, root.animationDuration)
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: Math.min(500, root.animationDuration)
        }
    }

    persistentProperties: QtObject {
        property alias positionX: root.position.x
        property alias positionY: root.position.y
        property alias entityId: root.entityId
        property alias filename: root.filename
        property alias playerId: root.playerId
    }
}
