import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0
import SocketGame 1.0

Entity {
    id: root

    signal spaceClicked()
    
    property int playerId: -1
    property bool resetNext: false
    property bool human: false
    property vector2d velocity
    property vector2d force
    property vector2d target
    property var waypoints: []
    property bool hasTarget: false
    property real mass: 1.0
    property bool particle: true
    property bool bursting: false
    property real burstingFactor: 1.0
    property bool pushing: false
    
    filename: "Particle.qml"

    width: 20
    height: 20
    
    persistentProperties: QtObject {
        property alias targetX: root.target.x
        property alias targetY: root.target.y
        property alias human: root.human
        property alias mass: root.mass
        property alias hasTarget: root.hasTarget
        property alias waypoints: root.waypoints
        property alias bursting: root.bursting
        property alias pushing: root.pushing
        property alias burstingFactor: root.burstingFactor
    }

    function reset() {
        mass = 1.0;
        velocity = Qt.vector2d(0, 0);
        force = Qt.vector2d(0, 0);
        resetNext = false;
        target = position;
    }

    function addWaypoint(parsedTarget) {
        console.log("Adding target", parsedTarget.x, parsedTarget.y);
        if(!hasTarget) {
            console.log("Setting directly");
            setTarget(parsedTarget);
        } else {
            console.log("Pushing");
            waypoints.push([parsedTarget.x, parsedTarget.y]);
        }
    }

    function setTarget(parsedTarget) {
        waypoints = [];
        target.x = parsedTarget.x;
        target.y = parsedTarget.y;
        hasTarget = true;
    }

    function shiftNextTarget() {
        if(waypoints.length > 0) {
            var nextTarget = waypoints.shift();
            target.x = nextTarget[0];
            target.y = nextTarget[1];
            hasTarget = true;
        } else {
            hasTarget = false;
        }
    }
    
    Rectangle {
        anchors.centerIn: parent
        width: root.bursting ? parent.width * root.burstingFactor * 2.0 : parent.width
        height: width
        radius: width * 0.5
        color: root.bursting ? "orange" : Qt.darker(root.player.color, Math.max(1.0, 1.5 - 0.5 * (energy / defaultEnergy)))
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
        color: Qt.lighter(root.player.color, 1.2)

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

    Repeater {
        model: waypoints
        Rectangle {
            x: (modelData[0] - root.x / scaleFactor) * scaleFactor - width * 0.5
            y: (modelData[1] - root.y / scaleFactor) * scaleFactor - height * 0.5
            width: 10
            height: width
            radius: width * 0.25
            color: Qt.darker(root.player.color, 1.2)
        }
    }

    Behavior on burstingFactor {
        NumberAnimation {
            duration: root.animationDuration
        }
    }
}
