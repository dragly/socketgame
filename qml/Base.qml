import QtQuick 2.0

import SocketGame 1.0

Entity {
    id: root

    property bool base: true

    filename: "Base.qml"

    width: 40
    height: 40
    Rectangle {
        anchors.fill: parent
        radius: width * 0.2
        color: root.player.color
    }
}
