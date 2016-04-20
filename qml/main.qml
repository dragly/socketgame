import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0
import SocketGame 1.0

import "io.js" as IO

Rectangle {
    id: root

    property int playerId: -1
    property var players: []
    property var entities: []
    property var player

    property var selectedEntities: []

    width: 1280
    height: 1024
    focus: true

    color: "#222222"

    function createEntityFromUrl(url, properties) {
        var component = Qt.createComponent(url);
        var container = playgroundParticleLayer;
        if(url === "Base.qml") {
            container = playgroundBaseLayer;
        }

        properties.scaleFactor = Qt.binding(function() {return playground.scaleFactor;});

        var entity = component.createObject(container, properties);

        entity.clicked.connect(function(mouse) {
            if(!(mouse.modifiers & Qt.ShiftModifier)) {
                deselectAll();
            }
            if((mouse.modifiers & Qt.ShiftModifier) && entity.selected) {
                selectedEntities.splice(selectedEntities.indexOf(entity), 1);
                entity.selected = false;
            } else {
                selectedEntities.push(entity);
                entity.selected = true;
            }
        });

        entities.push(entity);
        return entity;
    }

    function deselectAll() {
        selectedEntities = [];
        for(var i in entities) {
            var entity = entities[i];
            entity.selected = false;
        }
    }

    function removeEntity(entity) {
        entities.splice(entities.indexOf(entity), 1);
        entity.destroy(100);
    }

    Component {
        id: playerComponent
        GameObject {
            id: player
            property WebSocket webSocket
            property int playerId: -1
            property color color: "purple"
            property bool toBeDeleted: false
            property bool human: false

            persistentProperties: QtObject {
                id: props
                property alias playerId: player.playerId
                property alias human: player.human
                property string color: player.color
            }
            Binding {
                target: player
                property: "color"
                value: props.color
            }
        }
    }

    Component {
        id: baseComponent
        Entity {

        }
    }

    Server {
        id: server
    }

    WebSocket {
        id: socket

        property real lastReceivedTime: Date.now()
        property bool firstState: true

        url: server.url

        onTextMessageReceived: {
            var currentTime = Date.now();
            var deltaTime = currentTime - lastReceivedTime;

            var parsed = JSON.parse(message);
            switch(parsed.type) {
            case "welcome":
                playerId = parsed.playerId;
                break;
            case "state":
                for(var i in entities) {
                    var entity = entities[i];
                    entity.animationDuration = deltaTime;
                    entity.toBeDeleted = true;
                }

                for(var i in players) {
                    var player = players;
                    player.toBeDeleted = true;
                }

                IO.applyProperties(playground, parsed.playground);

                for(var i in parsed.players) {
                    var parsedPlayer = parsed.players[i];
                    var foundPlayer = false;
                    var player;
                    for(var j in players) {
                        var existingPlayer = players[j];
                        if(parsedPlayer.playerId === existingPlayer.playerId) {
                            player = existingPlayer;
                            foundPlayer = true;
                        }
                    }
                    if(!foundPlayer) {
                        player = playerComponent.createObject(root, {playerId: parsedPlayer.playerId});
                        players.push(player);
                    }
                    player.toBeDeleted = false;
                    IO.applyProperties(player, parsedPlayer);
                }

                for(var i in parsed.entities) {
                    var parsedEntity = parsed.entities[i];
                    var entity;
                    var parsedEntityPlayer;

                    var foundPlayer = false;
                    for(var k in players) {
                        var existingPlayer = players[k];
                        if(existingPlayer.playerId === parsedEntity.playerId) {
                            parsedEntityPlayer = existingPlayer;
                            foundPlayer = true;
                        }
                    }

                    if(!foundPlayer) {
                        console.log("WARNING: Got entity with unknown player", parsedEntity.playerId);
                    }

                    var foundEntity = false;
                    for(var j in entities) {
                        var existingEntity = entities[j];
                        if(existingEntity.entityId === parsedEntity.entityId) {
                            entity = existingEntity;
                            foundEntity = true;
                        }
                    }

                    if(!foundEntity) {
                        entity = createEntityFromUrl(parsedEntity.filename, {entityId: parsedEntity.entityId, player: parsedEntityPlayer});
                    }

                    IO.applyProperties(entity, parsedEntity);
                    entity.player = parsedEntityPlayer;
                    entity.toBeDeleted = false;
                }

                var deletedEntities = [];

                for(var i in entities) {
                    var entity = entities[i];
                    if(entity.toBeDeleted) {
                        deletedEntities.push(entity);
                    }
                }

                for(var i in deletedEntities) {
                    var entity = deletedEntities[i];
                    if(entity.base) {
                        console.log("Removing", entity.entityId);
                        console.log("Removing...");
                    }
                    removeEntity(entity);
                }

                for(var i in players) {
                    var player = players[i];
                    if(player.toBeDeleted) {
                        console.log("Should remove player", player);
                        //                        removeplayersEntities(player);
                    }

                    if(player.playerId === root.playerId) {
                        root.player = player;
                    }
                }

                if(firstState) {
                    for(var i in entities) {
                        var entity = entities[i];
                        if(entity.player === root.player) {
                            // center on one of the first entities we got
                            playground.x = -entity.x + root.width * 0.5;
                            playground.y = -entity.y + root.height * 0.5;
                        }
                    }

                    firstState = false;
                }
                break;
            }
            lastReceivedTime = currentTime;
        }

        onStatusChanged: {
            if (socket.status == WebSocket.Error) {
                console.log(qsTr("Client error: %1").arg(socket.errorString));
            } else if (socket.status == WebSocket.Closed) {
                console.log(qsTr("Client socket closed."));
            }
        }
    }

    Playground {
        id: playground

        Rectangle {
            anchors.fill: parent
            color: "#333333"
            border.width: 2.0
            border.color: "#cccccc"
        }

        MouseArea {
            id: playgroundMouseArea

            property real previousTrigger: Date.now()
            property bool selecting: false
            property point selectionStart
            property point selectionEnd
            property bool ignoreClick: false

            anchors.fill: parent
            drag.target: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onPressed: {
                root.forceActiveFocus();
                if(mouse.button === Qt.RightButton) {
                    drag.target = undefined;
                    if(Date.now() - previousTrigger < 100) {
                        return;
                    }

                    var movedEntities = [];
                    for(var i in selectedEntities) {
                        movedEntities.push({entityId: selectedEntities[i].entityId});
                    }

                    var moveMessage = {
                        type: "move",
                        entities: movedEntities,
                        target: {
                            x: mouse.x / playground.scaleFactor,
                            y: mouse.y / playground.scaleFactor
                        }
                    };
                    var message = JSON.stringify(moveMessage);
                    socket.sendTextMessage(message);
                    previousTrigger = Date.now();
                    return;
                }
                if(mouse.modifiers & Qt.ShiftModifier) {
                    drag.target = undefined;
                    selectionStart = Qt.point(mouse.x, mouse.y);
                    selectionEnd = selectionStart;
                    selecting = true;
                    ignoreClick = true;
                    return;
                }
                ignoreClick = false;
            }

            onPositionChanged: {
                selectionEnd = Qt.point(mouse.x, mouse.y);
            }

            onReleased: {
                if(selecting) {
                    for(var i in entities) {
                        var entity = entities[i];
                        if(entity.player.playerId === player.playerId &&
                                entity.x > selectionRectangle.x &&
                                entity.y > selectionRectangle.y &&
                                entity.x + entity.width < selectionRectangle.x + selectionRectangle.width &&
                                entity.y + entity.height < selectionRectangle.y + selectionRectangle.height) {
                            entity.selected = true;
                            selectedEntities.push(entity);
                        }
                    }
                }

                drag.target = parent;
                selecting = false;
            }

            onClicked: {
                if(ignoreClick) {
                    return;
                }

                switch(mouse.button) {
                case Qt.LeftButton:
                    deselectAll();
                    break;
                }
            }

            Rectangle {
                id: selectionRectangle

                x: Math.min(playgroundMouseArea.selectionStart.x, playgroundMouseArea.selectionEnd.x)
                y: Math.min(playgroundMouseArea.selectionStart.y, playgroundMouseArea.selectionEnd.y)

                width: Math.abs(playgroundMouseArea.selectionStart.x - playgroundMouseArea.selectionEnd.x)
                height: Math.abs(playgroundMouseArea.selectionStart.y - playgroundMouseArea.selectionEnd.y)

                z: 99999
                color: "transparent"
                border.width: 2.0
                border.color: "lightgrey"
                visible: playgroundMouseArea.selecting
            }
        }

        Item {
            id: playgroundBaseLayer
            anchors.fill: parent
        }

        Item {
            id: playgroundParticleLayer
            anchors.fill: parent
        }
    }

    Row {
        anchors {
            bottom: parent.bottom
        }

        TextField {
            id: serverTextField
            text: "127.0.0.1"
        }

        TextField {
            id: serverPortTextField
            text: "47960"
        }

        Button {
            text: "Serve"
            onClicked: {
                server.host = serverTextField.text;
                server.port = parseInt(serverPortTextField.text);
                server.listen = true;
            }
        }

        TextField {
            id: clientTextField
            text: "ws://127.0.0.1:47960"
        }

        Button {
            text: "Connect"
            onClicked: {
                socket.url = clientTextField.text;
            }
        }

        CheckBox {
            id: serverRunningCheckbox
            text: "Server running"
        }
    }

    Rectangle {
        anchors.fill: serverUrlText
    }
    Text {
        id: serverUrlText
        text: "Server url: " + server.url
    }

    Rectangle {
        anchors {
            right: parent.right
            top: parent.top
            margins: 24
        }
        width: 192
        height: width

        color: "#AA111111"
        clip: true

        ShaderEffectSource {
            anchors {
                fill: parent
                margins: 16
            }

            sourceItem: playground
            smooth: true
        }

        Rectangle {
            width: root.width / playground.width * parent.width
            height: root.height / playground.height * parent.height
            x: -playground.x / playground.width * parent.width
            y: -playground.y / playground.height * parent.height

            color: "#33000000"
            border.width: 1.0
            border.color: "#99999999"
        }

        MouseArea {
            anchors.fill: parent

            function movePlayground(mouse) {
                playground.x = -mouse.x / parent.width * playground.width + root.width * 0.5;
                playground.y = -mouse.y / parent.height * playground.height + root.height * 0.5;
            }

            onPressed: {
                movePlayground(mouse);
            }

            onPositionChanged: {
                movePlayground(mouse);
            }
        }
    }

    Timer {
        id: playgroundMoveTimer

        property vector2d velocity
        property vector2d acceleration

        property real previousTime: Date.now()

        property bool leftDown: false
        property bool rightDown: false
        property bool upDown: false
        property bool downDown: false
        property bool aDown: false
        property bool dDown: false
        property bool wDown: false
        property bool sDown: false

        interval: 16
        running: true
        repeat: true
        onTriggered: {
            var currentTime = Date.now();
            var deltaTime = (currentTime - previousTime);

            velocity = Qt.vector2d(0, 0);

            if(leftDown || aDown) {
                acceleration.x += 1.0;
            }
            if(rightDown || dDown) {
                acceleration.x -= 1.0;
            }
            if(upDown || wDown) {
                acceleration.y += 1.0;
            }
            if(downDown || sDown) {
                acceleration.y -= 1.0;
            }

            velocity = velocity.plus(acceleration.times(0.01*deltaTime))
            acceleration = acceleration.plus(velocity.times(-0.9));

            if(velocity.length() > 0.01) {
                playground.x += velocity.x * deltaTime;
                playground.y += velocity.y * deltaTime;
            }

            previousTime = currentTime;
        }
    }

    Keys.onPressed: {
        switch(event.key) {
        case Qt.Key_Left:
            playgroundMoveTimer.leftDown = true;
            break;
        case Qt.Key_Right:
            playgroundMoveTimer.rightDown = true;
            break;
        case Qt.Key_Up:
            playgroundMoveTimer.upDown = true;
            break;
        case Qt.Key_Down:
            playgroundMoveTimer.downDown = true;
            break;
        case Qt.Key_A:
            playgroundMoveTimer.aDown = true;
            break;
        case Qt.Key_D:
            playgroundMoveTimer.dDown = true;
            break;
        case Qt.Key_W:
            playgroundMoveTimer.wDown = true;
            break;
        case Qt.Key_S:
            playgroundMoveTimer.sDown = true;
            break;
        case Qt.Key_Space:
            console.log("Send burst message");
            var burstEntities = [];
            for(var i in selectedEntities) {
                var entity = selectedEntities[i];
                burstEntities.push({entityId: entity.entityId});
            }

            var burstMessage = {
                type: "burst",
                entities: burstEntities
            };
            var message = JSON.stringify(burstMessage);
            socket.sendTextMessage(message);
        }
    }

    Keys.onReleased: {
        switch(event.key) {
        case Qt.Key_Left:
            playgroundMoveTimer.leftDown = false;
            break;
        case Qt.Key_Right:
            playgroundMoveTimer.rightDown = false;
            break;
        case Qt.Key_Up:
            playgroundMoveTimer.upDown = false;
            break;
        case Qt.Key_Down:
            playgroundMoveTimer.downDown = false;
            break;
        case Qt.Key_A:
            playgroundMoveTimer.aDown = false;
            break;
        case Qt.Key_D:
            playgroundMoveTimer.dDown = false;
            break;
        case Qt.Key_W:
            playgroundMoveTimer.wDown = false;
            break;
        case Qt.Key_S:
            playgroundMoveTimer.sDown = false;
            break;
        }
    }

    Settings {
        property alias serverHost: serverTextField.text
        property alias serverPort: serverPortTextField.text
        property alias socketUrl: clientTextField.text
    }
}
