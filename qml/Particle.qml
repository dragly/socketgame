import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0
import SocketGame 1.0

Entity {
    id: root
    
    property int playerId: -1
    property bool resetNext: false
    property bool human: false
    property vector2d velocity
    property vector2d force
    property vector2d target
    property bool hasTarget: false
    property real mass: 1.0
    property bool particle: true
    
    filename: "Particle.qml"

    width: 20
    height: 20
    
    persistentProperties: QtObject {
        property alias targetX: root.target.x
        property alias targetY: root.target.y
        property alias human: root.human
        property alias mass: root.mass
        property alias hasTarget: root.hasTarget
    }

    function reset() {
        mass = 1.0;
        velocity = Qt.vector2d(0, 0);
        force = Qt.vector2d(0, 0);
        resetNext = false;
        target = position;
    }
    
    Rectangle {
        anchors.fill: parent
        radius: width * 0.5
        color: root.player ? root.player.color : "purple"
        border.color: Qt.darker(color, 1.5)
        border.width: 2.0
    }

    Rectangle {
        id: targetRectangle
        x: root.hasTarget ? (root.target.x - root.x / scaleFactor) * scaleFactor - width * 0.5 : 0
        y: root.hasTarget ? (root.target.y - root.y / scaleFactor) * scaleFactor - height * 0.5 : 0
        visible: root.hasTarget
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
}
