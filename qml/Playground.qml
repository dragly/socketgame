import QtQuick 2.0
import QtQuick.Controls 1.4
import QtWebSockets 1.0
import Qt.labs.settings 1.0
import SocketGame 1.0

GameObject {
    id: root
    property real scaleFactor: 1
    persistentProperties: QtObject {
        property alias width: root.width
        property alias height: root.height
        property alias scaleFactor: root.scaleFactor
    }
}
