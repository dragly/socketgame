import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0
import SocketGame 1.0

Rectangle {
    id: root

    property real scaleFactor: 512
    property int playerId: 0
    property var players: []
    property var entities: []

    width: 1280
    height: 1024

    Component.onCompleted: {
        timer.start();
    }

    function createEntityFromUrl(url, properties) {
        var component = Qt.createComponent(url);
        var entity = component.createObject(playground, properties);
        entities.push(entity);
        return entity;
    }

    function removeEntity(entity) {
        entities.splice(entities.indexOf(entity), 1);
        entity.destroy(100);
    }

    function applyProperties(object, properties) {
        if(!object){
            console.warn("WARNING: apply properties got missing object: " + object);
            return;
        }

        if(!object.hasOwnProperty("persistentProperties")) {
            console.warn("WARNING: Object " + object + " is missing persistentProperties property.");
            return;
        }

        for(var i in properties) {
            var prop = properties[i];
            var found = false;
            for(var j in object.persistentProperties) {
                var propertyGroup = object.persistentProperties[j];
                if(!propertyGroup.hasOwnProperty(i)) {
                    continue;
                }
                found = true;
                if(typeof(prop) === "object" && typeof(propertyGroup[i]) == "object") {
                    applyProperties(propertyGroup[i], prop);
                } else {
                    propertyGroup[i] = prop;
                }
            }
            if(!found) {
                console.warn("WARNING: Cannot assign to " + i + " on savedProperties of " + object);
            }
        }
    }

    function generateProperties(entity) {
        if(!entity) {
            return undefined;
        }
        var result = {};
        for(var i in entity.persistentProperties) {
            var properties = entity.persistentProperties[i];
            for(var name in properties) {
                var prop = properties[name];
                if(typeof(prop) === "object") {
                    result[name] = generateProperties(prop);
                } else {
                    result[name] = prop;
                }
            }
        }
        return result;
    }

    Component {
        id: playerComponent
        GameObject {
            id: player
            property WebSocket webSocket
            property int playerId: -1
            property color color: "purple"
            property bool toBeDeleted: false

            persistentProperties: QtObject {
                id: props
                property alias playerId: player.playerId
                property string color: root.color
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

    WebSocketServer {
        id: server

        property var players: []
        property var entities: []
        property int currentPlayerId: 0
        property int currentEntityId: 0
        property var availableColors: ["red", "green", "blue", "pink", "yellow", "lightblue", "lightgreen", "orange"]

        listen: true

        Component.onCompleted: {
            server.currentPlayerId += 1;

            // create non-playing player
            var playerProperties = {
                playerId: server.currentPlayerId,
                color: "lightgrey"
            };
            var player = playerComponent.createObject(server, playerProperties);
            server.players.push(player);

            for(var i = 0; i < 10; i++) {
                server.createRandomParticle();
            }
            timer.start();
        }

        function createEntityFromUrl(url, properties) {
            if(properties === undefined) {
                properties = {}
            }

            if(properties.entityId === undefined) {
                properties.entityId = currentEntityId;
                currentEntityId += 1;
            }

            if(properties.player === undefined) {
                console.log("WARNING: Making entity without player!");
            } else {
                properties.playerId = properties.player.playerId;
            }

            var component = Qt.createComponent(url);
            var entity = component.createObject(serverPlayground, properties);
            entities.push(entity);
            return entity;
        }

        function createRandomParticle() {
            var particle = createEntityFromUrl("Particle.qml", {
                                                   player: players[0]
                                               });
            particle.position.x = Math.random() * serverPlayground.width / scaleFactor;
            particle.position.y = Math.random() * serverPlayground.height / scaleFactor;
        }

        function serialize() {
            var serializedPlayers = [];
            for(var i in server.players) {
                var player = server.players[i];
                serializedPlayers.push(generateProperties(player));
            }
            var serializedEntities = [];
            for(var i in server.entities) {
                var particle = server.entities[i];
                serializedEntities.push(generateProperties(particle));
            }
            return {
                type: "state",
                playground: generateProperties(serverPlayground),
                players: serializedPlayers,
                entities: serializedEntities
            }
        }

        onClientConnected: {
            currentPlayerId += 1;
            var playerProperties = {
                webSocket: webSocket,
                playerId: currentPlayerId,
                color: availableColors[currentPlayerId % availableColors.length]
            };
            var player = playerComponent.createObject(serverPlayground, playerProperties);
            player.playerId = currentPlayerId;
            server.players.push(player);
            var welcomeMessage = {
                type: "welcome",
                playerId: currentPlayerId
            }
            webSocket.sendTextMessage(JSON.stringify(welcomeMessage));

            webSocket.onTextMessageReceived.connect(function(message) {
                var parsed = JSON.parse(message);
                if(parsed.target) {
                    player.hasTarget = true;
                    player.target.x = parsed.target.x;
                    player.target.y = parsed.target.y;
                }
            });
            webSocket.onStatusChanged.connect(function(status) {
                if(status === WebSocket.Closed) {
                    server.players.splice(server.players.indexOf(player), 1);
                    server.entities.splice(server.entities.indexOf(player), 1);
                    player.destroy(1);
                }
            });
        }
        onErrorStringChanged: {
            console.log(qsTr("Server error: %1").arg(errorString));
        }
    }

    WebSocket {
        id: socket

        url: server.url

        onTextMessageReceived: {
            var parsed = JSON.parse(message);
            switch(parsed.type) {
            case "welcome":
                playerId = parsed.playerId;
                break;
            case "state":
                for(var i in entities) {
                    var entity = entities[i];
                    entity.toBeDeleted = true;
                }

                for(var i in players) {
                    var player = players;
                    player.toBeDeleted = true;
                }

                applyProperties(playground, parsed.playground);

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
                    applyProperties(player, parsedPlayer);
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
                        entities.push(entity);
                    }

                    applyProperties(entity, parsedEntity);
                    entity.player = parsedEntityPlayer;
                    entity.toBeDeleted = false;
                }

                for(var i in entities) {
                    var entity = entities[i];
                    if(entity.toBeDeleted) {
                        removeEntity(entity);
                    }
                }

//                for(var i in players) {
//                    var player = players[i];
//                    if(player.toBeDeleted) {
//                        console.log("Removing player", player);
//                        removeplayersEntities(player);
//                    }
//                }
                break;
            }
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
        id: serverPlayground
        visible: false

        width: 2560
        height: 2560
    }

    Playground {
        id: playground

        Rectangle {
            anchors.fill: parent
            color: "#333333"
        }

        MouseArea {
            property real previousTrigger: Date.now()
            anchors.fill: parent
            drag.target: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            function trigger(mouse) {
                if(Date.now() - previousTrigger < 100) {
                    return;
                }

                var moveMessage = {
                    target: {
                        x: mouse.x / scaleFactor,
                        y: mouse.y / scaleFactor
                    }
                };
                var message = JSON.stringify(moveMessage);
                console.log("Sending message", message);
                socket.sendTextMessage(message);
                previousTrigger = Date.now();
            }


            onClicked: {
                if(mouse.button === Qt.RightButton) {
                    trigger(mouse);
                }
            }
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
    }


    Timer {
        id: timer
        interval: 16
        running: false
        repeat: true
        onTriggered: {
            var particleFrequency = 0.1;
            if(Math.random() < particleFrequency * interval / 1000) {
                server.createRandomParticle();
            }

            var dt = 0.01;

            for(var i in server.entities) {
                var atom = server.entities[i];
                if(atom.particle) {
                    atom.force = Qt.vector2d(0, 0);
                }
            }

            for(var i in server.entities) {
                var atom1 = server.entities[i];
                for(var j in server.entities) {
                    var atom2 = server.entities[j]
                    if(!atom1.particle || !atom2.particle) {
                        continue;
                    }

                    if(atom1 === atom2) {
                        continue
                    }

                    var delta = atom2.position.minus(atom1.position)
                    var direction = delta.normalized()
                    var length = delta.length()

                    if(length < 0.001) {
                        length = 0.001
                    }

                    var r2 = length * length
                    var r6 = r2*r2*r2
                    var r12 = r6*r6

                    var sigma = 0.01;

                    var eps = 0.01;

                    var sigma2 = sigma * sigma
                    var sigma6 = sigma2 * sigma2
                    var sigma12 = sigma6 * sigma6
                    var eps24 = 24 * eps

                    var force = delta.times((eps24 / r2) * (2.0 * sigma12 / r12 - sigma6 / r6))

                    if(isNaN(force.x) || isNaN(force.y)) {
                        force = Qt.vector2d(0, 0)
                    }

                    if(atom1.human && atom2.human) {
                        force = Qt.vector2d(0, 0);
                    }

                    atom1.force = atom1.force.minus(force)
                }
            }

            for(var i in server.entities) {
                if(!atom.particle) {
                    continue;
                }

                if(atom.resetNext) {
                    atom.reset();
                }

                var atom = server.entities[i]

                // mass check
                if(atom.mass < 0.1) {
                    if(atom.human) {
                        atom.reset();
                        continue;
                    }
                    server.entities.splice(server.entities.indexOf(atom), 1);
                    atom.destroy(1);
                }

                // target
                if(atom.hasTarget) {
                    atom.force = atom.force.plus(atom.target.minus(atom.position).normalized().times(0.4));
                }

                // drag
                atom.force = atom.force.plus(atom.velocity.times(-1));

                // clamp
                if(atom.force.length() > 10) {
                    atom.force = atom.force.times(10 / atom.force.length())
                }

                // integration
                atom.velocity = atom.velocity.plus(atom.force.times(dt / atom.mass))
                if(atom.velocity.length() > 1) {
                    atom.velocity = atom.velocity.times(1 / atom.velocity.length())
                }
                atom.position = atom.position.plus(atom.velocity.times(dt))

                if(atom.position.x < 0) {
                    atom.position.x = 0
                    atom.velocity.x = -atom.velocity.x
                }
                if(atom.position.y < 0) {
                    atom.position.y = 0
                    atom.velocity.y = -atom.velocity.y
                }
                if(atom.position.x > serverPlayground.width / scaleFactor) {
                    atom.position.x = serverPlayground.width / scaleFactor
                    atom.velocity.x = -atom.velocity.x
                }
                if(atom.position.y > serverPlayground.height / scaleFactor) {
                    atom.position.y = serverPlayground.height / scaleFactor
                    atom.velocity.y = -atom.velocity.y
                }
            }

            for(var i in server.players) {
                var player = server.players[i];
                if(player.webSocket) {
                    player.webSocket.sendTextMessage(JSON.stringify(server.serialize()));
                }
            }
        }
    }

    Settings {
        property alias serverHost: serverTextField.text
        property alias serverPort: serverPortTextField.text
        property alias socketUrl: clientTextField.text
    }
}
