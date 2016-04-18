#include <QtGui/QGuiApplication>
#include <QQuickView>

#include "gameobject.h"

int main(int argc, char *argv[])
{
    qmlRegisterType<GameObject>("SocketGame", 1, 0, "GameObject");

    QGuiApplication app(argc, argv);

    QQuickView view;
    view.setSource(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.show();

    return app.exec();
}
