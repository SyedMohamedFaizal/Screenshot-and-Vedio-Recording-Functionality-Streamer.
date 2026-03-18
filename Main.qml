import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

ApplicationWindow {
    id: root
    visible: true
    visibility: Window.Maximized
    title: "Vikra Deep Cam"

    color: "#020810"

    property color accent: "#00c8e8"
    property color panel: "#08111f"
    property color card: "#0c1826"
    property color border: "#1f4060"
    property color text: "#ddeeff"
    property color muted: "#4a6a82"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ================= HEADER =================
        Rectangle {
            Layout.fillWidth: true
            height: 64
            color: "#040f1e"
            border.color: root.border

            Column {
                anchors.fill: parent

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20

                    Text {
                        text: "VIKRA DEEP CAM"
                        color: root.accent
                        font.pixelSize: 18
                        font.bold: true
                        font.letterSpacing: 3
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        id: timeText
                        color: root.accent
                        font.pixelSize: 14
                        font.letterSpacing: 2
                    }

                    Rectangle {
                        width: 120
                        height: 32
                        radius: 4
                        color: root.card
                        border.color: root.border

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "red"
                            }

                            Text {
                                text: "OFFLINE"
                                color: root.accent
                                font.pixelSize: 11
                                font.letterSpacing: 2
                            }
                        }
                    }
                }

                Rectangle {
                    height: 1
                    width: parent.width
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.accent }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }

        // ================= MAIN =================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ===== VIDEO =====
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 12
                color: "black"
                border.color: root.border
                radius: 6
                clip: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.accent
                    shadowBlur: 0.8
                }

                Image {
                    id: opencvImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: "image://live/image"
                    cache: false

                    function reload() {
                        source = "image://live/image?" + Math.random()
                    }
                }

                // LIVE indicator
                Row {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 12
                    spacing: 6

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.accent

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.2; duration: 800 }
                            NumberAnimation { from: 0.2; to: 1; duration: 800 }
                        }
                    }

                    Text {
                        text: "LIVE"
                        color: "white"
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                }

                // HUD corners
                Rectangle { x: 10; y: 10; width: 20; height: 2; color: root.accent }
                Rectangle { x: 10; y: 10; width: 2; height: 20; color: root.accent }

                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 20; height: 2; color: root.accent; anchors.margins: 10 }
                Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 2; height: 20; color: root.accent; anchors.margins: 10 }

                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 20; height: 2; color: root.accent; anchors.margins: 10 }
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 2; height: 20; color: root.accent; anchors.margins: 10 }

                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 20; height: 2; color: root.accent; anchors.margins: 10 }
                Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 20; color: root.accent; anchors.margins: 10 }
            }

            // ===== RIGHT PANEL =====
            Rectangle {
                width: 300
                Layout.fillHeight: true
                color: root.panel
                border.color: root.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // BUTTON STYLE
                    component CyberButton: Button {
                        property bool active: false

                        implicitHeight: 36

                        background: Rectangle {
                            radius: 4
                            border.width: 1
                            border.color: active ? root.accent : root.border

                            color: control.down ? "#102b3c"
                                  : control.hovered ? "#0f2235"
                                  : root.panel

                            layer.enabled: active
                            layer.effect: MultiEffect {
                                shadowEnabled: active
                                shadowColor: root.accent
                                shadowBlur: 0.6
                            }
                        }

                        contentItem: Text {
                            text: control.text
                            color: active ? root.accent : root.text
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // RECORD
                    Rectangle {
                        Layout.fillWidth: true
                        height: 90
                        color: root.card
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text { text: "RECORDING"; color: root.accent }

                            RowLayout {
                                CyberButton {
                                    text: "REC"
                                    active: true
                                    Layout.fillWidth: true
                                    onClicked: VideoStreamer.openVideoCamera(0)
                                }

                                CyberButton {
                                    text: "STOP"
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // SNAPSHOT
                    Rectangle {
                        Layout.fillWidth: true
                        height: 90
                        color: root.card
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text { text: "SNAPSHOT"; color: root.accent }

                            CyberButton {
                                text: "CAPTURE"
                                Layout.fillWidth: true
                                onClicked: VideoStreamer.takeScreenshot()
                            }
                        }
                    }

                    // ZOOM
                    Rectangle {
                        Layout.fillWidth: true
                        height: 90
                        color: root.card
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text { text: "ZOOM"; color: root.accent }

                            Slider {
                                Layout.fillWidth: true
                                background: Rectangle { height: 3; color: root.border }
                                handle: Rectangle {
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: root.accent
                                }
                            }
                        }
                    }

                    // FOCUS
                    Rectangle {
                        Layout.fillWidth: true
                        height: 90
                        color: root.card
                        border.color: root.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text { text: "FOCUS"; color: root.accent }

                            RowLayout {
                                CyberButton { text: "AUTO"; Layout.fillWidth: true }
                                CyberButton { text: "MANUAL"; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }

        // ================= FOOTER =================
        Rectangle {
            Layout.fillWidth: true
            height: 120
            color: "#060e1a"
            border.color: root.border

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20

                Text { text: "SYSTEM"; color: root.accent }

                Item { Layout.fillWidth: true }

                Text { text: "CPU: 25%"; color: root.text }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            let d = new Date()
            timeText.text =
                d.getUTCHours() + ":" +
                d.getUTCMinutes() + ":" +
                d.getUTCSeconds() + " UTC"
        }
    }

    Connections {
        target: liveImageProvider
        function onImageChanged() {
            opencvImage.reload()
        }
    }
}
