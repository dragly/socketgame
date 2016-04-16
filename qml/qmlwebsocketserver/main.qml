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

Rectangle {
    property var players: []

    width: 1280
    height: 1024

    Component {
        id: playerComponent
        PlayerData {}
    }

    Component {
        id: playerItemComponent
        Rectangle {
            property PlayerData playerData: PlayerData {}
            x: playerData.positionX
            y: playerData.positionY
            width: 20
            height: 20
            radius: width * 0.5
            color: "red"

            Rectangle {
                x: (playerData.targetX - playerData.positionX)
                y: (playerData.targetY - playerData.positionY)
                width: 10
                height: 10
                color: "blue"
            }
        }
    }

    WebSocketServer {
        id: server

        property var players: []

        port: 44789
        host: "192.168.2.2"
        accept: true
        listen: true

        function serialize() {
            var serializedPlayers = [];
            for(var i in players) {
                var player = players[i];
                serializedPlayers.push(player.properties);
            }
            return {
                players: serializedPlayers
            }
        }
        onClientConnected: {
            var player = playerComponent.createObject(server, {webSocket: webSocket});
            players.push(player);
            webSocket.onTextMessageReceived.connect(function(message) {
                var parsed = JSON.parse(message);
                if(parsed.target) {
                    player.targetX = parsed.target.x;
                    player.targetY = parsed.target.y;
                }
            });
            webSocket.onStatusChanged.connect(function(status) {
                if(status === WebSocket.Closed) {
                    server.players.splice(server.players.indexOf(player), 1);
                    player.destroy();
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
        running: true
        repeat: true
        onTriggered: {
            var dt = 0.01;

            for(var i in server.players) {
                var player = server.players[i];
                player.positionX += player.velocityX * dt;
                player.positionY += player.velocityY * dt;
                player.velocityX += player.accelerationX * dt;
                player.velocityY += player.accelerationY * dt;

                player.accelerationX = 0.0;
                player.accelerationY = 0.0;

                player.accelerationX += -1 * player.velocityX;
                player.accelerationY += -1 * player.velocityY;

                player.accelerationX += player.targetX - player.positionX;
                player.accelerationY += player.targetY - player.positionY;
            }

            for(var i in server.players) {
                var player = server.players[i];
                player.webSocket.sendTextMessage(JSON.stringify(server.serialize()));
            }
        }
    }

    WebSocket {
        id: socket
        url: "ws://192.168.2.2:44789"
        active: true
        onTextMessageReceived: {
            var state = JSON.parse(message);
            if(players.length !== state.players.length) {
                for(var i in players) {
                    var player = players[i];
                    player.destroy();
                }
                players.length = 0;
                for(var i in state.players) {
                    var player = playerItemComponent.createObject(playground);
                    players.push(player);
                }
            }
            for(var i in players) {
                var player = players[i];
                var playerData = state.players[i];
                for(var j in playerData) {
                    player.playerData.properties[j] = playerData[j];
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

        MouseArea {
            anchors.fill: parent

            function trigger(mouse) {
                socket.sendTextMessage(JSON.stringify({target: {x: mouse.x, y: mouse.y}}));
            }

            onPressed: {
                trigger(mouse);
            }

            onPositionChanged: {
                trigger(mouse);
            }
        }
    }

    Column {
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        Text {
            text: "Server: " + server.url
        }

        TextField {
            id: serverTextField
            anchors {
                left: parent.left
                right: parent.rigt
                margins: 16
            }
            text: "ws://192.168.2.2:44789"
            width: 300
        }

        Button {
            text: "Connect"
            onClicked: {
                socket.url = serverTextField.text;
            }
        }
    }
}
