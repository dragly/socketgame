import QtQuick 2.0
import QtWebSockets 1.0

QtObject {
    id: player
    property real positionX: 500
    property real positionY: 200
    property real velocityX: 0
    property real velocityY: 0
    property real accelerationX: 0
    property real accelerationY: 0
    property real targetX: 600
    property real targetY: 500
    property WebSocket webSocket

    property QtObject properties: QtObject {
        property alias positionX: player.positionX
        property alias positionY: player.positionY
        property alias velocityX: player.velocityX
        property alias velocityY: player.velocityY
        property alias accelerationX: player.accelerationX
        property alias accelerationY: player.accelerationY
        property alias targetX: player.targetX
        property alias targetY: player.targetY
    }
}
