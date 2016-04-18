QT += core qml quick websockets

TARGET = qmlwebsocketserver

TEMPLATE = app

CONFIG   -= app_bundle

SOURCES += main.cpp \
    gameobject.cpp

RESOURCES += data.qrc

OTHER_FILES += qml/qmlwebsocketserver/main.qml

DISTFILES += \
    qml/qmlwebsocketserver/PlayerData.qml \
    android/AndroidManifest.xml \
    android/gradle/wrapper/gradle-wrapper.jar \
    android/gradlew \
    android/res/values/libs.xml \
    android/build.gradle \
    android/gradle/wrapper/gradle-wrapper.properties \
    android/gradlew.bat

ANDROID_PACKAGE_SOURCE_DIR = $$PWD/android

HEADERS += \
    gameobject.h
