import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0
import SocketGame 1.0

import "io.js" as IO
import "random.js" as Random

Item {
    id: serverContainer
    property alias url: server.url
    property alias host: server.host
    property alias port: server.port
    property alias listen: server.listen

    Playground {
        id: serverPlayground

        visible: false

        scaleFactor: 512
        width: 2560
        height: 2560
    }

    WebSocketServer {
        id: server

        property var players: []
        property var entities: []
        property int currentPlayerId: 0
        property int currentEntityId: 0
        property var availableColors: ["pink", "lightgreen", "lightblue", "yellow", "orange", "#dd3333"]

        Component.onCompleted: {
            server.currentPlayerId += 1;

            // create non-playing player
            var playerProperties = {
                playerId: server.currentPlayerId,
                color: "lightgrey"
            };
             // TODO turn playerComponent into file
            var dummyPlayer = playerComponent.createObject(server, playerProperties);
            server.players.push(dummyPlayer);

            for(var i = 0; i < 4; i++) {
                var baseProperties = {
                    player: dummyPlayer
                };
                var base = server.createEntityFromUrl("Base.qml", baseProperties);

                var w = serverPlayground.width / serverPlayground.scaleFactor;
                var h = serverPlayground.height / serverPlayground.scaleFactor;

                base.position.x = w * 0.5 + Random.centered() * w * 0.1;
                base.position.y = h * 0.5 + Random.centered() * h * 0.1;
                base.target = base.position;
                base.timeSinceSpawn = Math.random() * base.spawnInterval;
            }

            for(var i = 0; i < 20; i++) {
                server.createRandomParticle();
            }
        }

        function buildNeighborList(entity1) {
            entity1.neighbors = [];
            for(var j in server.entities) {
                var entity2 = server.entities[j];
                if(entity1 === entity2) {
                    continue
                }
                var delta = entity2.position.minus(entity1.position);
                if(delta.length() < 0.2) {
                    entity1.neighbors.push(entity2);
                }
            }
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

            properties.visible = false;

            var component = Qt.createComponent(url);
            var entity = component.createObject(serverPlayground, properties);
            entities.push(entity);
            rebuildNeighborLists();
            return entity;
        }

        function createRandomParticle() {
            var particle = createEntityFromUrl("Particle.qml", {
                                                   player: players[0],
                                                   mass: 1.0
                                               });
            particle.position.x = Math.random() * serverPlayground.width / serverPlayground.scaleFactor;
            particle.position.y = Math.random() * serverPlayground.height / serverPlayground.scaleFactor;

            particle.velocity.x = Random.centered() * 0.1;
            particle.velocity.y = Random.centered() * 0.1;
        }

        function serialize() {
            var serializedPlayers = [];
            for(var i in server.players) {
                var player = server.players[i];
                serializedPlayers.push(IO.generateProperties(player));
            }
            var serializedEntities = [];
            for(var i in server.entities) {
                var particle = server.entities[i];
                serializedEntities.push(IO.generateProperties(particle));
            }
            return {
                type: "state",
                playground: IO.generateProperties(serverPlayground),
                players: serializedPlayers,
                entities: serializedEntities
            }
        }

        function rebuildNeighborLists() {
            for(var i in server.entities) {
                var entity = server.entities[i];
                buildNeighborList(entity);
            }
        }

        function removeEntity(entity) {
            if(entity.base) {
                console.log("Server removing entity", entity.entityId);
                console.log("LOL");
            }
            var index = server.entities.indexOf(entity);
            if(index === -1) {
                throw("Trying to remove already removed entity");
            }
            server.entities.splice(server.entities.indexOf(entity), 1);
            entity.destroy(100);

            rebuildNeighborLists();
        }

        onClientConnected: {
            console.log("Client connected");
            currentPlayerId += 1;
            var color = availableColors[currentPlayerId % availableColors.length];
            console.log("Player color:", color);
            var playerProperties = {
                webSocket: webSocket,
                playerId: currentPlayerId,
                color: color,
                human: true
            };
            // TODO turn playerComponent into file
            var player = playerComponent.createObject(serverPlayground, playerProperties);
            player.playerId = currentPlayerId;
            server.players.push(player);
            var welcomeMessage = {
                type: "welcome",
                playerId: currentPlayerId
            }

            var baseProperties = {
                player: player,
                timeSinceSpawn: 1.0 / 0.0 // infinite
            };
            var base = server.createEntityFromUrl("Base.qml", baseProperties);

            var w = serverPlayground.width / serverPlayground.scaleFactor;
            var h = serverPlayground.height / serverPlayground.scaleFactor;

            var topOrBottom = (Math.random() > 0.5);
            var offset = (Math.random() > 0.5) ? 0.9 : 0.0;
            if(topOrBottom) {
                base.position.x = Math.random() * w;
                base.position.y = Math.random() * h * 0.1 + offset * h;
            } else {
                base.position.x = Math.random() * w * 0.1 + offset * w;
                base.position.y = Math.random() * h;
            }

            base.target = base.position;

            var offsetY = (Math.random() > 0.5) ? 0.9 : 0.0;

            webSocket.sendTextMessage(JSON.stringify(welcomeMessage));

            webSocket.onTextMessageReceived.connect(function(message) {
                var parsed = JSON.parse(message);
                switch(parsed.type) {
                case "move":
                    for(var j in parsed.entities) {
                        var parsedEntity = parsed.entities[j];
                        for(var i in entities) {
                            var entity = entities[i];
                            if(parsedEntity.entityId !== entity.entityId) {
                                continue;
                            }
                            if(entity.player !== player) {
                                continue;
                            }
                            if(entity.particle) {
                                entity.hasTarget = true;
                            }
                            entity.target.x = parsed.target.x;
                            entity.target.y = parsed.target.y;
                        }
                    }
                    break;
                case "burst":
                    for(var j in parsed.entities) {
                        var parsedEntity = parsed.entities[j];
                        for(var i in entities) {
                            var entity = entities[i];
                            if(parsedEntity.entityId !== entity.entityId) {
                                continue;
                            }
                            if(entity.player !== player) {
                                continue;
                            }
                            if(!entity.particle) {
                                continue;
                            }
                            entity.bursting = true;
                        }
                    }
                    break;
                }
            });
            webSocket.onStatusChanged.connect(function(status) {
                if(status === WebSocket.Closed) {
                    server.players.splice(server.players.indexOf(player), 1);
                    var toDelete = [];
                    for(var i in server.entities) {
                        var entity = server.entities[i];
                        if(entity.player === player) {
                            toDelete.push(entity);
                        }
                    }
                    for(var i in toDelete) {
                        var entity = toDelete[i];
                        server.removeEntity(entity);
                    }

                    player.destroy(100);
                }
            });
        }
        onErrorStringChanged: {
            console.log(qsTr("Server error: %1").arg(errorString));
        }
    }

    Timer {
        id: timer
        interval: 16
        running: serverRunningCheckbox.checked
        repeat: true

        property int neighborUpdate: 0
        property int neighborUpdateInterval: 20
        property int messageInterval: 10
        property int tickCount: 0
        property real time: 0
        property real previousTime: Date.now();

        onTriggered: {
            var dt = 0.01;

            var currentTime = Date.now();
            var deltaTime = currentTime - previousTime;
            time += deltaTime;

            for(var i in server.entities) {
                var base = server.entities[i];
                if(!base.base) {
                    continue;
                }

                base.timeSinceSpawn += deltaTime;

                if(base.timeSinceSpawn < base.spawnInterval) {
                    continue;
                }

                console.log("Spawning particle");
                var particleProperties = {
                    human: true,
                    player: base.player
                }

                var particle = server.createEntityFromUrl("Particle.qml", particleProperties);
                particle.velocity.x = 0.2 * Random.centered();
                particle.velocity.y = 0.2 * Random.centered();
                particle.position = base.position;
                particle.target = base.target;
                particle.hasTarget = true;
                base.timeSinceSpawn = 0.0;
            }

            for(var i in server.entities) {
                var entity = server.entities[i];
                if(entity.particle) {
                    entity.force = Qt.vector2d(0, 0);
                }
                if(entity.entityId % neighborUpdateInterval === neighborUpdate) {
                    server.buildNeighborList(entity);
                }
            }

            for(var i in server.entities) {
                var entity1 = server.entities[i];
//                var secondList = server.entities;
                var secondList = entity1.neighbors;
                for(var j in secondList) {
                    var entity2 = secondList[j];
                    if(entity1 === entity2) {
                        continue;
                    }

                    var delta = entity2.position.minus(entity1.position)
                    var direction = delta.normalized()
                    var length = delta.length()

                    if(length < 0.2 && entity2.bursting && entity2.burstingFactor > 0.9) {
                        entity1.energy -= 0.0002 / (length * length);
                    }

                    if(entity1.particle && entity2.particle) {

                        if(length < 0.001) {
                            length = 0.001
                        }

                        var r2 = length * length
                        var r6 = r2*r2*r2
                        var r12 = r6*r6

                        var sigma = 0.01;

                        var eps = 0.02;

                        var sigma2 = sigma * sigma
                        var sigma6 = sigma2 * sigma2
                        var sigma12 = sigma6 * sigma6
                        var eps24 = 24 * eps

                        var force;
                        force = delta.times((eps24 / r2) * (2.0 * sigma12 / r12 - sigma6 / r6));
                        if(length < 0.2 && entity2.bursting && entity2.burstingFactor > 0.9) {
                            entity1.velocity = entity1.velocity.plus(direction.times(-0.0004 / (length*length)))
                        }

                        if(isNaN(force.x) || isNaN(force.y)) {
                            force = Qt.vector2d(0, 0)
                        }

                        entity1.force = entity1.force.minus(force)
                    } else if(entity1.base && entity2.particle) {
                        if(entity1.player.human && entity1.player.playerId !== entity2.player.playerId) {
                            var delta = entity1.position.minus(entity2.position);
                            var direction = delta.normalized();
                            var length = delta.length();

                            if(length < 0.04) {
                                entity1.energy += 0.05;
                                entity2.player = entity1.player;
                            }

                            if(length < 0.2) {
                                var force = direction.times(1.0);
                                entity2.force = entity2.force.plus(force);
                            }
                        }
                    }
                }
            }

            for(var i in server.entities) {
                var entity = server.entities[i]

                if(entity.particle) {
                    // target
                    if(entity.hasTarget) {
                        entity.force = entity.force.plus(entity.target.minus(entity.position).normalized().times(1.4));
                        if(entity.target.minus(entity.position).length() < 0.1 && entity.velocity.length() < 0.01) {
                            entity.hasTarget = false;
                        }
                    }

                    // drag
                    entity.force = entity.force.plus(entity.velocity.times(-4.0));

                    // clamp
                    if(entity.force.length() > 10) {
                        entity.force = entity.force.times(10 / entity.force.length())
                    }

                    // bursting reduce factor
                    if(entity.bursting) {
                        entity.burstingFactor -= dt;
                        if(entity.burstingFactor < 0.0) {
                            entity.toBeDeleted = true;
                        }
                    }

                    // integration
                    entity.velocity = entity.velocity.plus(entity.force.times(dt / entity.mass))
                    if(entity.velocity.length() > 1) {
                        entity.velocity = entity.velocity.times(1 / entity.velocity.length())
                    }
                    entity.position = entity.position.plus(entity.velocity.times(dt))

                    if(entity.position.x < 0) {
                        entity.position.x = 0
                        entity.velocity.x = -entity.velocity.x
                    }
                    if(entity.position.y < 0) {
                        entity.position.y = 0
                        entity.velocity.y = -entity.velocity.y
                    }
                    if(entity.position.x > serverPlayground.width / serverPlayground.scaleFactor) {
                        entity.position.x = serverPlayground.width / serverPlayground.scaleFactor
                        entity.velocity.x = -entity.velocity.x
                    }
                    if(entity.position.y > serverPlayground.height / serverPlayground.scaleFactor) {
                        entity.position.y = serverPlayground.height / serverPlayground.scaleFactor
                        entity.velocity.y = -entity.velocity.y
                    }
                }

                // reduce overcharge
                if(entity.energy > entity.defaultEnergy) {;
                    entity.energy = Math.max(entity.defaultEnergy, entity.energy - dt * 0.2);
                }

                // delete those without energy
                if(entity.energy < 0.0) {
                    if(entity.particle) {
                        entity.bursting = true;
                    } else {
                        entity.toBeDeleted = true;
                    }
                }
            }

            var toDelete = [];
            for(var i in server.entities) {
                var entity = server.entities[i];
                if(entity.toBeDeleted) {
                    toDelete.push(entity);
                }
            }

            if(toDelete.length > 0) {
                console.log("Deleting entities");
            }

            for(var i in toDelete) {
                var entity = toDelete[i];
                server.removeEntity(entity);
            }

            if(toDelete.length > 0) {
                console.log("Deleted entities");
            }

            if(tickCount % messageInterval === 0) {
                for(var i in server.players) {
                    var player = server.players[i];
                    if(player.webSocket) {
                        player.webSocket.sendTextMessage(JSON.stringify(server.serialize()));
                    }
                }
            }
            neighborUpdate += 1;
            if(neighborUpdate >= neighborUpdateInterval) {
                neighborUpdate = 0;
            }
            tickCount += 1;
            previousTime = currentTime;
        }
    }
}
