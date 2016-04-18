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
    property vector2d position
    property vector2d velocity
    property vector2d force
    property vector2d target
    property bool hasTarget: false
    property real mass: 1.0
    property bool particle: true
    
    filename: "Particle.qml"

    x: position.x * scaleFactor - height * 0.5
    y: position.y * scaleFactor - width * 0.5
    width: 20 * mass
    height: 20 * mass
    
    persistentProperties: QtObject {
        property alias positionX: root.position.x
        property alias positionY: root.position.y
        property alias targetX: root.target.x
        property alias targetY: root.target.y
        property alias human: root.human
        property alias mass: root.mass
    }
    
    function reset() {
        position = Qt.vector2d(Math.random(), Math.random());
        mass = 1.0;
        position = Qt.vector2d(Math.random(), Math.random());
        velocity = Qt.vector2d(0, 0);
        force = Qt.vector2d(0, 0);
        resetNext = false;
        target = position;
    }
    
    Rectangle {
        anchors.fill: parent
        radius: width * 0.5
        color: player ? player.color : "purple"
    }
    
    Rectangle {
        id: targetRectangle
        x: (root.target.x - root.position.x) * scaleFactor - width * 0.5
        y: (root.target.y - root.position.y) * scaleFactor - height * 0.5
        visible: root.human
        width: 10
        height: width
        radius: width * 0.25
        color: "#01B0F0"
        
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
