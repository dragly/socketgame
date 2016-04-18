#ifndef GAMEOBJECT_H
#define GAMEOBJECT_H

#include <QQuickItem>
#include <QQmlListProperty>

class GameObject : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY(QQmlListProperty<QObject> persistentProperties READ persistentProperties)
public:
    explicit GameObject(QQuickItem *parent = 0);

    QQmlListProperty<QObject> persistentProperties();

signals:

public slots:

private:
    QList<QObject*> m_persistentProperties;
};

#endif // GAMEOBJECT_H
