import QtQuick 2.0

import SocketGame 1.0

GameObject {
    id: root

    signal clicked(var mouse)

    property int entityId: -1
    property string filename: "Entity.qml"

    property bool selected
    property bool toBeDeleted: false

    property var player
    property int playerId: player ? player.playerId : -1

    property vector2d position
    property real energy: defaultEnergy
    property real defaultEnergy: 1.0
    property real maximumEnergy: 3.0

    property var neighbors: []
    property real animationDuration: 0
    property real scaleFactor: parent.scaleFactor

    x: visible ? position.x * scaleFactor - height * 0.5 : 0
    y: visible ? position.y * scaleFactor - width * 0.5 : 0

    width: 16
    height: 16

    persistentProperties: QtObject {
        property alias positionX: root.position.x
        property alias positionY: root.position.y
        property alias entityId: root.entityId
        property alias filename: root.filename
        property alias playerId: root.playerId
        property alias energy: root.energy
        property alias maximumEnergy: root.maximumEnergy
    }

    onEnergyChanged: {
        energy = Math.min(maximumEnergy, energy);
    }

    Rectangle {
        anchors {
            fill: parent
            margins: -4
        }
        visible: root.selected
        color: "transparent"
        border.width: 2.0
        border.color: "white"
    }

    Rectangle {
        id: energyBar
        anchors {
            bottom: root.top
            left: root.left
            bottomMargin: 6
        }
        opacity: mouseArea.hovered || root.selected

        antialiasing: true
        smooth: true
        color: "#cc6633"

        width: root.width
        height: 3

        Rectangle {
            width: root.width * Math.min(1.0, energy / defaultEnergy)
            height: parent.height
            color: "lightgreen"
        }

        Rectangle {
            id: overchargeBar
            anchors {
                left: parent.left
                top: parent.top
            }
            width: root.width * (energy - defaultEnergy) / (maximumEnergy - defaultEnergy)
            height: parent.height
            color: "yellow"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            root.clicked(mouse);
        }
    }

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
}
