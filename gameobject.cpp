#include "gameobject.h"

GameObject::GameObject(QQuickItem *parent)
{

}

QQmlListProperty<QObject> GameObject::persistentProperties()
{
    return QQmlListProperty<QObject>(this, m_persistentProperties);
}
