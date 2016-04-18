import QtQuick 2.0
import QtWebSockets 1.0

QtObject {
    id: player
    property int atomType: 8

    property int playerId: -1
    property bool resetNext: false
    property bool human: false
    property bool leaking: false
    property int leakingId: -1
    property vector2d position
    property vector2d velocity
    property vector2d force
    property vector2d target
    property bool hasTarget: false
    property real mass: 1.0
    property WebSocket webSocket

    function reset() {
        position = Qt.vector2d(Math.random(), Math.random());
        mass = 1.0;
        position = Qt.vector2d(Math.random(), Math.random());
        velocity = Qt.vector2d(0, 0);
        force = Qt.vector2d(0, 0);
        resetNext = false;
        target = position;
    }

    property QtObject properties: QtObject {
        property alias positionX: player.position.x
        property alias positionY: player.position.y
        property alias targetX: player.target.x
        property alias targetY: player.target.y
        property alias player: player.human
        property alias mass: player.mass
        property alias leaking: player.leaking
        property alias playerId: player.playerId
    }
}
