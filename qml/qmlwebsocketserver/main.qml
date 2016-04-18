/****************************************************************************
**
** Copyright (C) 2014 Klarälvdalens Datakonsult AB, a KDAB Group company, info@kdab.com, author Milian Wolff <milian.wolff@kdab.com>
** Contact: http://www.qt.io/licensing/
**
** This file is part of the QtWebSocket module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL21$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see http://www.qt.io/terms-conditions. For further
** information use the contact form at http://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 or version 3 as published by the Free
** Software Foundation and appearing in the file LICENSE.LGPLv21 and
** LICENSE.LGPLv3 included in the packaging of this file. Please review the
** following information to ensure the GNU Lesser General Public License
** requirements will be met: https://www.gnu.org/licenses/lgpl.html and
** http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** As a special exception, The Qt Company gives you certain additional
** rights. These rights are described in The Qt Company LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** $QT_END_LICENSE$
**
****************************************************************************/

import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0

Rectangle {

    property real scaleFactor: playground.width
    property int playerId: 0
    property var players: []
    property var particles: []

    width: 1024
    height: 1024

    Component {
        id: particleComponent
        ParticleData {}
    }

    Component {
        id: particleItemComponent
        Rectangle {
            id: particle
            property ParticleData particleData: ParticleData {}
            x: particleData.position.x * scaleFactor - height * 0.5
            y: particleData.position.y * scaleFactor - width * 0.5
            width: 20 //* particleData.mass
            height: 20 //* particleData.mass
            radius: width * 0.5
            color: {
                if(particleData.playerId === playerId) {
                    return "yellow";
                }
                if(particleData.human) {
                    return "#AEEE00";
                }
                return "#FF358B";
            }

            Rectangle {
                id: leakingRectangle
                anchors.centerIn: parent
                visible: particleData.leaking
                width: 10
                height: width
                radius: width * 0.5
                color: Qt.rgba(0.0, 0.0, 0.0, 0.8)

                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation {
                        target: leakingRectangle
                        property: "width"
                        duration: 600
                        easing.type: Easing.InOutQuad
                        from: 6
                        to: 12
                    }
                    NumberAnimation {
                        target: leakingRectangle
                        property: "width"
                        duration: 600
                        easing.type: Easing.InOutQuad
                        from: 12
                        to: 6
                    }
                }
            }

            Rectangle {
                id: targetRectangle
                x: (particleData.target.x - particleData.position.x) * scaleFactor - width * 0.5
                y: (particleData.target.y - particleData.position.y) * scaleFactor - height * 0.5
                visible: particleData.human
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
    }

    WebSocketServer {
        id: server

        property var players: []
        property var particles: []
        property int nextId: 0

        Component.onCompleted: {
            for(var i = 0; i < 10; i++) {
                createRandomParticle();
            }
        }

        function createRandomParticle() {
            var particle = particleComponent.createObject(playground);
            particle.position.x = Math.random();
            particle.position.y = Math.random();
            console.log("Creating random particle at", particle.position)
            particles.push(particle);
        }

        function serialize() {
            var serializedPlayers = [];
            for(var i in server.players) {
                var player = server.players[i];
                serializedPlayers.push(player.properties);
            }
            var serializedParticles = [];
            for(var i in server.particles) {
                var particle = server.particles[i];
                serializedParticles.push(particle.properties);
            }
            return {
                players: serializedPlayers,
                particles: serializedParticles
            }
        }

        onClientConnected: {
            var properties = {
                webSocket: webSocket,
                hasTarget: true,
                human: true,
                atomType: 6,
            };
            var player = particleComponent.createObject(server, properties);
            player.playerId = nextId;
            player.reset();
            server.players.push(player);
            server.particles.push(player);
            webSocket.sendTextMessage(JSON.stringify({playerId: nextId}));
            nextId += 1;

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
                    server.particles.splice(server.particles.indexOf(player), 1);
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
        onTextMessageReceived: {
            var state = JSON.parse(message);
            if(state.playerId !== undefined) {
                console.log("Player ID set");
                playerId = state.playerId;
                return;
            }
            if(particles.length !== state.particles.length) {
                var difference = state.particles.length > particles.length;
                if(difference > 0) {
                    for(var i in state.particles) {
                        var particle = particleItemComponent.createObject(playground);
                        particles.push(particle);
                    }
                } else {
                    var particle = particles.pop();
                    particle.destroy(1);
                }
            }
            for(var i in particles) {
                var particle = particles[i];
                var particleData = state.particles[i];
                for(var j in particleData) {
                    particle.particleData.properties[j] = particleData[j];
                }
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

    Rectangle {
        id: playground
        anchors.fill: parent
        color: "#333333"

        MouseArea {
            property real previousTrigger: Date.now()
            anchors.fill: parent

            function trigger(mouse) {
                if(Date.now() - previousTrigger < 100) {
                    return;
                }

                var message = JSON.stringify({target: {x: mouse.x / scaleFactor, y: mouse.y / scaleFactor}});
                console.log("Sending message", message);
                socket.sendTextMessage(message);
                previousTrigger = Date.now();
            }

            onPressed: {
                trigger(mouse);
            }

            onPositionChanged: {
                trigger(mouse);
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
        running: true
        repeat: true
        onTriggered: {
            var particleFrequency = 0.1;
            if(Math.random() < particleFrequency * interval / 1000) {
                server.createRandomParticle();
            }

            var dt = 0.01;

            for(var i in server.particles) {
                var atom = server.particles[i]
                atom.force = Qt.vector2d(0, 0);
                atom.leaking = false;
            }

            for(var i in server.particles) {
                var atom1 = server.particles[i];
                for(var j in server.particles) {
                    var atom2 = server.particles[j]
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

                    var eps = 0.0005;

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

                    if((atom1.human || atom2.human) && length < 10 * sigma) {
                        var okay = false;
                        if((atom1.human && (atom2.leakingId === -1 || atom2.leakingId === atom1.playerId))) {
                            atom2.leakingId = atom1.playerId;
                            okay = true;
                        }
                        if((atom2.human && (atom1.leakingId === -1 || atom1.leakingId === atom2.playerId))) {
                            atom1.leakingId = atom2.playerId;
                            okay = true;
                        }
                        if(okay) {
                            if(!(atom1.human && atom2.human)) {
                                if(length > 6 * sigma) {
                                    force = force.plus(delta.times(1000.0 * (6 * sigma - length)));
                                }
                            }
                            var massChange = 0.01 * dt;
                            if(atom1.human && atom2.human) {
                                if(atom1.mass > atom2.mass) {
                                    atom2.leaking = true;
                                } else {
                                    atom1.leaking = true;
                                }
                            } else if(atom1.human) {
                                atom1.mass += massChange;
                                atom2.mass -= massChange;
                                atom2.leaking = true;
                            } else {
                                atom1.mass -= massChange;
                                atom2.mass += massChange;
                                atom1.leaking = true;
                            }
                        }
                    }

                    atom1.force = atom1.force.minus(force)
                }
            }

            for(var i in server.particles) {
                if(atom.resetNext) {
                    atom.reset();
                }

                if(!atom.leaking) {
                    atom.leakingId = -1;
                }

                var atom = server.particles[i]

                // mass check
                if(atom.mass < 0.1) {
                    if(atom.human) {
                        atom.reset();
                        continue;
                    }
                    server.particles.splice(server.particles.indexOf(atom), 1);
                    atom.destroy(1);
                }

                // target
                if(atom.hasTarget) {
                    atom.force = atom.force.plus(atom.target.minus(atom.position).times(1));
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
                if(atom.position.x > playground.width / scaleFactor) {
                    atom.position.x = playground.width / scaleFactor
                    atom.velocity.x = -atom.velocity.x
                }
                if(atom.position.y > playground.height / scaleFactor) {
                    atom.position.y = playground.height / scaleFactor
                    atom.velocity.y = -atom.velocity.y
                }
            }

            for(var i in server.players) {
                var particle = server.players[i];
                particle.webSocket.sendTextMessage(JSON.stringify(server.serialize()));
            }
        }
    }

    Settings {
        property alias serverHost: serverTextField.text
        property alias serverPort: serverPortTextField.text
        property alias socketUrl: clientTextField.text
    }
}
