import QtQuick 2.0

import SocketGame 1.0

GameObject {
    id: root

    property int entityId: -1
    property string filename: "Entity.qml"
    property bool toBeDeleted: false
    property var player
    property int playerId: player ? player.playerId : -1

    persistentProperties: QtObject {
        property alias entityId: root.entityId
        property alias filename: root.filename
        property alias playerId: root.playerId
    }
}
