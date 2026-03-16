import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.0

Window {
    width: Screen.width
    height: Screen.height
    visible: true
    title: qsTr("OpencvToQml")

    Row{
        anchors.centerIn: parent
        spacing: 40

        // LEFT SIDE CONTROLS
        Column{
            spacing: 20
            width: 200

            Button{
                id: startButton
                text: "Open"

                onClicked: {
                    VideoStreamer.openVideoCamera(videoPath.text)
                    opencvImage.visible = true
                }
            }

            TextField{
                id: videoPath
                placeholderText: "Video Index (0 / 1)"
                width: 150
            }

            Button{
                id: screenshotButton
                text: "Screenshot"

                onClicked: {
                    VideoStreamer.takeScreenshot()
                }
            }

            Button{
                id: recordButton
                text: "Start Recording"

                onClicked: {
                    VideoStreamer.toggleRecording()

                    if(text === "Start Recording")
                        text = "Stop Recording"
                    else
                        text = "Start Recording"
                }
            }
        }

        // VIDEO AREA
        Rectangle{
            id: imageRect
            width: 800
            height: 600
            color: "transparent"
            border.color: "black"
            border.width: 3

            Image{
                id: opencvImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                property bool counter: false
                visible: false
                source: "image://live/image"
                asynchronous: false
                cache: false

                function reload()
                {
                    counter = !counter
                    source = "image://live/image?id=" + counter
                }
            }
        }
    }

    Connections{
        target: liveImageProvider

        function onImageChanged()
        {
            opencvImage.reload()
        }
    }
}
