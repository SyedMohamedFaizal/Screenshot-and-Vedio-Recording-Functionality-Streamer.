pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1920
    height: 960
    minimumWidth: 1280
    minimumHeight: 720
    visibility: Window.Maximized
    title: "Vikra Deep Cam"
    color: bgBase

    readonly property color bgBase: "#020810"
    readonly property color bgSurface: "#060e1a"
    readonly property color bgPanel: "#08111f"
    readonly property color bgCard: "#0c1826"
    readonly property color bgHover: "#101f32"
    readonly property color accent: "#00c8e8"
    readonly property color accentDim: "#007a8e"
    readonly property color danger: "#ff3a3a"
    readonly property color textPrimary: "#ddeeff"
    readonly property color textMuted: "#4a6a82"
    readonly property color textDim: "#2a4a62"
    readonly property color borderColor: "#0d2035"
    readonly property color borderBright: "#1f4060"
    readonly property color headerBgLeft: "#020d18"
    readonly property color headerBgMid: "#040f1e"

    readonly property string displayFontFamily: "Segoe UI"
    readonly property string monoFontFamily: "Consolas"
    property var streamController
    property var liveProvider

    property bool autoStartCamera: true
    property string logoSource: ""
    property string utcClock: ""
    property string streamTs: ""
    property double lastFrameTick: 0
    property bool digitalZoomEnabled: false
    property bool manualFocus: false
    property int videoLayoutIndex: 0
    property var snapshotLabels: ["Instant", "1s", "2s", "5s", "10s", "15s", "20s", "30s"]
    property var snapshotDelayValues: [0, 1000, 2000, 5000, 10000, 15000, 20000, 30000]
    property var videoLayoutModes: [
        { label: "Fit", fillMode: Image.PreserveAspectFit, description: "Shows the full frame without cropping." },
        { label: "Zoom", fillMode: Image.PreserveAspectCrop, description: "Fills the viewport and crops the edges." },
        { label: "Stretch", fillMode: Image.Stretch, description: "Fills the viewport edge to edge for maximum coverage." }
    ]
    property var telemetryGroups: [
        {
            icon: "⬡",
            title: "SYSTEM",
            items: [
                { label: "CPU", value: "90%" },
                { label: "MEMORY", value: "76.2%" },
                { label: "STORAGE", value: "84.4%" },
                { label: "UPTIME", value: "30h 30m" }
            ]
        },
        {
            icon: "⚡",
            title: "POWER",
            items: [
                { label: "BATTERY", value: "No Sensor" },
                { label: "VOLTAGE", value: "No Sensor" },
                { label: "CURRENT", value: "No Sensor" },
                { label: "POWER", value: "No Sensor" }
            ]
        },
        {
            icon: "◉",
            title: "ENVIRONMENT",
            items: [
                { label: "DEPTH", value: "20 m" },
                { label: "PRESSURE", value: "10 bar" },
                { label: "TEMP", value: "24.8 C" },
                { label: "HEADING", value: "052 deg" }
            ]
        },
        {
            icon: "◈",
            title: "COMMS",
            items: [
                { label: "SIGNAL", value: "Strong" },
                { label: "LATENCY", value: "0 ms" },
                { label: "PKT LOSS", value: "0%" }
            ]
        }
    ]

    QtObject {
        id: streamBackend

        property string streamUrl: "rtsp://192.168.56.2:8554/quality_h264"
        property string statusText: "Viewer ready"
        property bool online: false
        property bool requestedRunning: false
        property bool recordingActive: false
        property bool pendingRecordingStart: false

        function startFeed() {
            requestedRunning = true
            online = false
            statusText = "Connecting viewer to " + streamUrl
            root.lastFrameTick = 0
            root.streamController.openVideoCamera(streamUrl)
        }

        function stopFeed() {
            pendingRecordingStart = false
            if (recordingActive) {
                root.streamController.toggleRecording()
                recordingActive = false
            }
            requestedRunning = false
            online = false
            statusText = "Stream stopped"
            root.streamController.stopVideoCamera()
        }

        function startRecording() {
            if (recordingActive || pendingRecordingStart)
                return

            if (!requestedRunning) {
                pendingRecordingStart = true
                statusText = "Opening live stream for recording..."
                startFeed()
                return
            }

            if (root.lastFrameTick <= 0) {
                pendingRecordingStart = true
                statusText = "Waiting for first frame before recording..."
                return
            }

            root.streamController.toggleRecording()
            recordingActive = true
            pendingRecordingStart = false
            statusText = "Recording started"
        }

        function stopRecording() {
            pendingRecordingStart = false

            if (recordingActive) {
                root.streamController.toggleRecording()
                recordingActive = false
                statusText = "Recording stopped"
                return
            }

            stopFeed()
        }

        function reportPlaybackState(playing, details) {
            online = playing
            statusText = details && details.length > 0 ? details
                                                     : (playing ? "Live stream online" : "Waiting for live stream")
        }

        function captureSnapshot() {
            root.streamController.takeScreenshot()
        }

        function updateStreamUrl(value, reopenAfterApply) {
            const nextUrl = (value || "").trim()
            if (nextUrl.length === 0) {
                statusText = "Enter an RTSP URL or camera index"
                return false
            }

            const shouldResume = reopenAfterApply === true
            const wasRecording = recordingActive || pendingRecordingStart
            const wasRunning = requestedRunning || wasRecording

            if (wasRunning)
                stopFeed()

            streamUrl = nextUrl
            statusText = "Camera source updated"

            if (shouldResume) {
                if (wasRecording)
                    startRecording()
                else
                    startFeed()
            }

            return true
        }

        function enableDigitalZoom() {}
        function disableDigitalZoom() {}
        function setZoomPosition(value) {}
        function setFocusAuto() {}
        function setFocusManual() {}
        function setFocusPosition(value) {}
    }

    function utcString() {
        const d = new Date()
        const hh = String(d.getUTCHours()).padStart(2, "0")
        const mm = String(d.getUTCMinutes()).padStart(2, "0")
        const ss = String(d.getUTCSeconds()).padStart(2, "0")
        return hh + ":" + mm + ":" + ss + " UTC"
    }

    function tsString() {
        return new Date().toISOString().replace("T", " ").split(".")[0] + "Z"
    }

    function asAssetUrl(value) {
        const trimmed = (value || "").trim()
        if (trimmed.length === 0)
            return ""
        if (trimmed.indexOf("qrc:/") === 0 || trimmed.indexOf("file:/") === 0
                || trimmed.indexOf("http://") === 0 || trimmed.indexOf("https://") === 0)
            return trimmed
        if (/^[A-Za-z]:[\\/]/.test(trimmed))
            return "file:///" + trimmed.replace(/\\/g, "/")
        return trimmed
    }

    function percentString(value, maximum) {
        const max = Math.max(1, maximum)
        const pct = (value / max) * 100
        let formatted = pct.toFixed(1)
        if (formatted.endsWith(".0"))
            formatted = formatted.slice(0, -2)
        return formatted + "%"
    }

    function streamTransportLabel(url) {
        const value = (url || "").toLowerCase()
        if (value.indexOf("rtsp://") === 0)
            return "H.264 · RTSP LIVE"
        if (value.indexOf("tcp://") === 0)
            return "H.264 · TCP LIVE"
        if (value.indexOf("camera://") === 0)
            return "OPENCV · CAMERA LIVE"
        return "H.264 · LIVE"
    }

    function snapshotSavedText() {
        return "Snapshot saved to Pictures/test_streamer"
    }

    function currentDisplayZoomScale() {
        if (!root.digitalZoomEnabled)
            return 1.0

        return 1.0 + (zoomSlider.value / Math.max(1, zoomSlider.to)) * 1.8
    }

    function currentDisplayFocusBlur() {
        if (!root.manualFocus)
            return 0.0

        return (1.0 - (focusSlider.value / Math.max(1, focusSlider.to))) * 0.55
    }

    function currentDisplayFocusContrast() {
        if (!root.manualFocus)
            return 0.0

        return (focusSlider.value / Math.max(1, focusSlider.to)) * 0.18
    }

    component HudButton: Button {
        id: control
        property string variant: "default"
        property bool active: false

        hoverEnabled: true
        implicitHeight: 36
        implicitWidth: 118

        font.family: root.displayFontFamily
        font.pixelSize: 12

        background: Rectangle {
            radius: 4
            border.width: 1
            border.color: {
                if (!control.enabled)
                    return root.borderColor
                if (control.variant === "primary")
                    return "#1a4a6e"
                if (control.variant === "danger")
                    return "#5a1818"
                if (control.active)
                    return root.accent
                return control.hovered ? root.accentDim : root.borderBright
            }
            color: {
                if (!control.enabled)
                    return "#0b1623"
                if (control.variant === "primary")
                    return control.down ? "#2b567f" : "#17334a"
                if (control.variant === "danger")
                    return control.down ? "#592125" : "#341117"
                if (control.active)
                    return "#102b3c"
                return control.down ? "#14283d" : root.bgHover
            }
        }

        contentItem: Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: control.text
            color: {
                if (!control.enabled)
                    return root.textDim
                if (control.variant === "primary")
                    return "#7ad4ff"
                if (control.variant === "danger")
                    return "#ff8a8a"
                return control.active ? root.accent : root.textPrimary
            }
            font.family: root.displayFontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }

    component HudTextField: TextField {
        id: field
        implicitHeight: 38
        color: root.textPrimary
        font.family: root.monoFontFamily
        font.pixelSize: 11
        selectedTextColor: root.bgBase
        selectionColor: root.accent
        placeholderTextColor: root.textMuted
        verticalAlignment: Text.AlignVCenter

        background: Rectangle {
            radius: 4
            color: root.bgHover
            border.width: 1
            border.color: field.activeFocus ? root.accentDim : root.borderBright
        }
    }

    component PanelCard: Rectangle {
        id: panel
        property string title: ""
        property string iconText: ""
        default property alias contentData: bodyLayout.data

        implicitHeight: headerColumn.implicitHeight + 24
        radius: 6
        color: root.bgCard
        border.width: 1
        border.color: panelHover.hovered ? root.borderBright : root.borderColor

        HoverHandler { id: panelHover }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 5
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#141f3000" }
                GradientStop { position: 1.0; color: "#04121f55" }
            }
            opacity: 0.7
        }

        ColumnLayout {
            id: headerColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: panel.iconText
                    color: root.accentDim
                    font.family: root.displayFontFamily
                    font.pixelSize: 10
                }

                Text {
                    text: panel.title
                    color: root.accent
                    font.family: root.displayFontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.5
                }
            }

            ColumnLayout {
                id: bodyLayout
                Layout.fillWidth: true
                spacing: 8
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            root.utcClock = root.utcString()
            root.streamTs = root.tsString()
        }
    }

    Timer {
        id: streamMonitor
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!streamBackend.requestedRunning)
                return

            const freshFrame = root.lastFrameTick > 0 && (Date.now() - root.lastFrameTick) < 1800
            streamBackend.reportPlaybackState(
                freshFrame,
                freshFrame ? "Low-latency live stream online" : "Waiting for the live stream..."
            )
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgBase

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: "transparent"

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.headerBgLeft }
                        GradientStop { position: 0.5; color: root.headerBgMid }
                        GradientStop { position: 1.0; color: root.headerBgLeft }
                    }
                    border.color: root.borderBright
                    border.width: 1
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.5; color: root.accent }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                    opacity: 0.5
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 8
                        color: root.bgCard
                        border.color: root.borderBright
                        border.width: 1

                        Image {
                            id: logoImage
                            anchors.fill: parent
                            anchors.margins: 4
                            source: root.asAssetUrl(root.logoSource)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "VD"
                            visible: !logoImage.visible
                            color: root.accent
                            font.family: root.displayFontFamily
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            font.letterSpacing: 2
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: "VIKRA DEEP CAM"
                            color: root.accent
                            font.family: root.displayFontFamily
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            font.letterSpacing: 3
                        }

                        Text {
                            text: "Underwater Inspection System · v3.0"
                            color: root.textMuted
                            font.family: root.monoFontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.utcClock
                    color: root.accent
                    opacity: 0.8
                    font.family: root.monoFontFamily
                    font.pixelSize: 15
                    font.letterSpacing: 2
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 132
                    height: 32
                    radius: 4
                    color: root.bgCard
                    border.color: root.borderBright
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Item {
                            width: 12
                            height: 12

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: streamBackend.online ? root.accent : root.danger
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: "transparent"
                                border.color: streamBackend.online ? root.accent : root.danger
                                border.width: 1

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 2.6; duration: 1500; easing.type: Easing.OutCubic }
                                    PauseAnimation { duration: 1 }
                                }

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.8; to: 0.0; duration: 1500; easing.type: Easing.OutCubic }
                                    PauseAnimation { duration: 1 }
                                }
                            }
                        }

                        Text {
                            text: streamBackend.online ? "ONLINE" : "OFFLINE"
                            color: root.accent
                            font.family: root.monoFontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 2
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignCenter

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignCenter

                        Item {
                            anchors.fill: parent
                            anchors.margins: 16

                            Rectangle {
                                id: cameraFrame
                                anchors.fill: parent
                                radius: 6
                                color: "#000000"
                                border.color: root.borderBright
                                border.width: 1
                                clip: true

                                Item {
                                    id: videoSurface
                                    anchors.fill: parent
                                    clip: true
                                    layer.enabled: root.currentDisplayFocusBlur() > 0.0 || root.currentDisplayFocusContrast() > 0.0
                                    layer.effect: MultiEffect {
                                        blurEnabled: root.currentDisplayFocusBlur() > 0.0
                                        blurMax: 32
                                        blurMultiplier: root.currentDisplayFocusBlur()
                                        contrast: root.currentDisplayFocusContrast()
                                    }

                                    Image {
                                        id: opencvImage
                                        anchors.fill: parent
                                        source: "image://live/image"
                                        cache: false
                                        smooth: true
                                        fillMode: root.videoLayoutModes[root.videoLayoutIndex].fillMode
                                        scale: root.currentDisplayZoomScale()
                                        transformOrigin: Item.Center

                                        function reload() {
                                            source = "image://live/image?" + Math.random()
                                        }
                                    }
                                }

                                ComboBox {
                                    id: videoLayoutCombo
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 16
                                    width: 156
                                    height: 34
                                    model: root.videoLayoutModes
                                    textRole: "label"
                                    z: 4

                                    Component.onCompleted: currentIndex = root.videoLayoutIndex
                                    onCurrentIndexChanged: root.videoLayoutIndex = currentIndex

                                    background: Rectangle {
                                        radius: 4
                                        color: "#a0061320"
                                        border.color: root.borderBright
                                        border.width: 1
                                    }

                                    contentItem: Text {
                                        x: 12
                                        width: videoLayoutCombo.width - 40
                                        height: videoLayoutCombo.height
                                        text: "LAYOUT  " + videoLayoutCombo.displayText.toUpperCase()
                                        color: root.textPrimary
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 10
                                        font.letterSpacing: 1.2
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    indicator: Text {
                                        text: "⌄"
                                        color: root.textPrimary
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 15
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    popup: Popup {
                                        y: videoLayoutCombo.height + 4
                                        width: videoLayoutCombo.width
                                        padding: 0
                                        background: Rectangle {
                                            radius: 4
                                            color: root.bgHover
                                            border.color: root.borderBright
                                            border.width: 1
                                        }

                                        contentItem: ListView {
                                            clip: true
                                            implicitHeight: contentHeight
                                            model: videoLayoutCombo.popup.visible ? videoLayoutCombo.delegateModel : null
                                            currentIndex: videoLayoutCombo.highlightedIndex
                                        }
                                    }

                                    delegate: ItemDelegate {
                                        id: videoLayoutDelegate
                                        required property var modelData
                                        width: videoLayoutCombo.width
                                        height: 48

                                        contentItem: Column {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            anchors.topMargin: 7
                                            spacing: 2

                                            Text {
                                                text: videoLayoutDelegate.modelData.label
                                                color: root.textPrimary
                                                font.family: root.monoFontFamily
                                                font.pixelSize: 11
                                            }

                                            Text {
                                                text: videoLayoutDelegate.modelData.description
                                                color: root.textMuted
                                                font.family: root.displayFontFamily
                                                font.pixelSize: 9
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                                        background: Rectangle {
                                            color: videoLayoutDelegate.highlighted ? "#143246" : root.bgHover
                                        }
                                    }
                                }

                                Item {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    width: 20
                                    height: 20
                                    opacity: 0.7
                                    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 2; height: parent.height; color: root.accent }
                                    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: parent.width; height: 2; color: root.accent }
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 10
                                    width: 20
                                    height: 20
                                    opacity: 0.7
                                    Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 2; height: parent.height; color: root.accent }
                                    Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: parent.width; height: 2; color: root.accent }
                                }

                                Item {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 10
                                    width: 20
                                    height: 20
                                    opacity: 0.7
                                    Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 2; height: parent.height; color: root.accent }
                                    Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: parent.width; height: 2; color: root.accent }
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 10
                                    width: 20
                                    height: 20
                                    opacity: 0.7
                                    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: parent.height; color: root.accent }
                                    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: parent.width; height: 2; color: root.accent }
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 16
                                    width: 92
                                    height: 28
                                    radius: 3
                                    color: "#88000000"
                                    border.color: "#22ffffff"
                                    border.width: 1

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: streamBackend.online ? root.accent : root.danger
                                        }

                                        Text {
                                            text: "LIVE"
                                            color: "#ffffff"
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 11
                                            font.letterSpacing: 2
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 44
                                    color: "transparent"
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#00000000" }
                                        GradientStop { position: 1.0; color: "#b0000000" }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 12
                                    text: root.streamTransportLabel(streamBackend.streamUrl)
                                    color: "#73a0bd"
                                    opacity: 0.62
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 12
                                    text: root.streamTs
                                    color: "#73a0bd"
                                    opacity: 0.62
                                    font.family: root.monoFontFamily
                                    font.pixelSize: 11
                                    font.letterSpacing: 1
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        color: root.bgPanel
                        border.color: root.borderBright
                        border.width: 1

                        Flickable {
                            id: controlFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: controlColumn.height + 28
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            Column {
                                id: controlColumn
                                x: 12
                                y: 14
                                width: controlFlick.width - 24
                                spacing: 12

                                PanelCard {
                                    width: parent.width
                                    title: "CAMERA LINK"
                                    iconText: "◌"

                                    Text {
                                        text: "RTSP URL OR CAMERA INDEX"
                                        color: root.textMuted
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 9
                                        font.letterSpacing: 2
                                    }

                                    HudTextField {
                                        id: streamUrlField
                                        Layout.fillWidth: true
                                        text: streamBackend.streamUrl
                                        placeholderText: "rtsp://user:pass@ip:port/path or 0"
                                        onAccepted: streamBackend.updateStreamUrl(
                                                        text,
                                                        streamBackend.requestedRunning
                                                        || streamBackend.pendingRecordingStart
                                                        || streamBackend.recordingActive)
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Example: rtsp://admin:pass@192.168.56.2:8554/quality_h264"
                                        color: root.textMuted
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 9
                                        wrapMode: Text.Wrap
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        HudButton {
                                            text: "APPLY"
                                            Layout.fillWidth: true
                                            onClicked: streamBackend.updateStreamUrl(
                                                           streamUrlField.text,
                                                           streamBackend.requestedRunning
                                                           || streamBackend.pendingRecordingStart
                                                           || streamBackend.recordingActive)
                                        }

                                        HudButton {
                                            text: "OPEN"
                                            variant: "primary"
                                            Layout.fillWidth: true
                                            onClicked: {
                                                if (streamBackend.updateStreamUrl(streamUrlField.text, false))
                                                    streamBackend.startFeed()
                                            }
                                        }
                                    }
                                }

                                PanelCard {
                                    width: parent.width
                                    title: "RECORDING"
                                    iconText: "⬤"

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        HudButton {
                                            text: "• REC"
                                            variant: "primary"
                                            active: streamBackend.recordingActive || streamBackend.pendingRecordingStart
                                            Layout.fillWidth: true
                                            onClicked: streamBackend.startRecording()
                                        }

                                        HudButton {
                                            text: "■ STOP"
                                            variant: "danger"
                                            active: !streamBackend.requestedRunning || !streamBackend.recordingActive
                                            Layout.fillWidth: true
                                            onClicked: streamBackend.stopRecording()
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: streamBackend.statusText
                                        color: streamBackend.recordingActive ? "#ff8a8a" : root.textMuted
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                    }
                                }

                                PanelCard {
                                    width: parent.width
                                    title: "SNAPSHOT"
                                    iconText: "◈"

                                    Text {
                                        text: "DELAY"
                                        color: root.textMuted
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 9
                                        font.letterSpacing: 2
                                    }

                                    ComboBox {
                                        id: snapshotDelayCombo
                                        Layout.fillWidth: true
                                        model: root.snapshotLabels
                                        font.family: root.monoFontFamily
                                        font.pixelSize: 11

                                        background: Rectangle {
                                            radius: 4
                                            color: root.bgHover
                                            border.color: root.borderBright
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            x: 12
                                            width: snapshotDelayCombo.width - 44
                                            height: snapshotDelayCombo.height
                                            text: snapshotDelayCombo.displayText
                                            color: root.textPrimary
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        indicator: Text {
                                            text: "⌄"
                                            color: root.textPrimary
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 16
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        popup: Popup {
                                            y: snapshotDelayCombo.height + 4
                                            width: snapshotDelayCombo.width
                                            padding: 0
                                            background: Rectangle {
                                                radius: 4
                                                color: root.bgHover
                                                border.color: root.borderBright
                                                border.width: 1
                                            }

                                            contentItem: ListView {
                                                clip: true
                                                implicitHeight: contentHeight
                                                model: snapshotDelayCombo.popup.visible ? snapshotDelayCombo.delegateModel : null
                                                currentIndex: snapshotDelayCombo.highlightedIndex
                                            }
                                        }

                                        delegate: ItemDelegate {
                                            id: snapshotDelayDelegate
                                            required property var modelData
                                            width: snapshotDelayCombo.width

                                            contentItem: Text {
                                                text: snapshotDelayDelegate.modelData
                                                color: root.textPrimary
                                                font.family: root.monoFontFamily
                                                font.pixelSize: 11
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            background: Rectangle {
                                                color: snapshotDelayDelegate.highlighted ? "#143246" : root.bgHover
                                            }
                                        }
                                    }

                                    HudButton {
                                        text: "⊡ CAPTURE"
                                        Layout.fillWidth: true
                                        onClicked: {
                                            snapTimer.interval = root.snapshotDelayValues[snapshotDelayCombo.currentIndex]
                                            snapTimer.restart()
                                        }
                                    }
                                }

                                PanelCard {
                                    width: parent.width
                                    title: "ZOOM"
                                    iconText: "⊕"

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        HudButton {
                                            text: "DIGITAL ON"
                                            active: root.digitalZoomEnabled
                                            Layout.fillWidth: true
                                            onClicked: {
                                                root.digitalZoomEnabled = true
                                                if (zoomSlider.value < Math.round(zoomSlider.to * 0.2))
                                                    zoomSlider.value = Math.round(zoomSlider.to * 0.2)
                                                streamBackend.enableDigitalZoom()
                                            }
                                        }

                                        HudButton {
                                            text: "DIGITAL OFF"
                                            active: !root.digitalZoomEnabled
                                            Layout.fillWidth: true
                                            onClicked: {
                                                root.digitalZoomEnabled = false
                                                streamBackend.disableDigitalZoom()
                                                zoomSlider.value = 0
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "POSITION"
                                            color: root.textMuted
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 9
                                            font.letterSpacing: 2
                                        }

                                        Slider {
                                            id: zoomSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: root.digitalZoomEnabled ? 32256 : 16384
                                            value: 0
                                            enabled: root.digitalZoomEnabled
                                            opacity: enabled ? 1.0 : 0.35
                                            onPressedChanged: {
                                                if (!pressed)
                                                    streamBackend.setZoomPosition(Math.round(value))
                                            }

                                            background: Item {
                                                implicitHeight: 14

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 3
                                                    radius: 2
                                                    color: root.borderBright
                                                }

                                                Rectangle {
                                                    width: zoomSlider.visualPosition * parent.width
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 3
                                                    radius: 2
                                                    color: root.accentDim
                                                }
                                            }

                                            handle: Rectangle {
                                                x: zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                                                y: (zoomSlider.availableHeight - height) / 2
                                                width: 12
                                                height: 12
                                                radius: 7
                                                color: root.accent
                                                border.color: root.bgBase
                                                border.width: 2
                                            }
                                        }

                                        Text {
                                            text: root.percentString(zoomSlider.value, zoomSlider.to)
                                            color: root.accent
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 36
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }

                                PanelCard {
                                    width: parent.width
                                    title: "FOCUS"
                                    iconText: "◎"

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        HudButton {
                                            text: "AUTO"
                                            active: !root.manualFocus
                                            Layout.fillWidth: true
                                            onClicked: {
                                                root.manualFocus = false
                                                focusSlider.value = focusSlider.to
                                                streamBackend.setFocusAuto()
                                            }
                                        }

                                        HudButton {
                                            text: "MANUAL"
                                            active: root.manualFocus
                                            Layout.fillWidth: true
                                            onClicked: {
                                                root.manualFocus = true
                                                if (focusSlider.value === 0)
                                                    focusSlider.value = Math.round(focusSlider.to * 0.75)
                                                streamBackend.setFocusManual()
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: "POSITION"
                                            color: root.textMuted
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 9
                                            font.letterSpacing: 2
                                        }

                                        Slider {
                                            id: focusSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 16384
                                            value: 16384
                                            enabled: root.manualFocus
                                            opacity: enabled ? 1.0 : 0.35
                                            onPressedChanged: {
                                                if (!pressed && enabled)
                                                    streamBackend.setFocusPosition(Math.round(value))
                                            }

                                            background: Item {
                                                implicitHeight: 14

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 3
                                                    radius: 2
                                                    color: root.borderBright
                                                }

                                                Rectangle {
                                                    width: focusSlider.visualPosition * parent.width
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 3
                                                    radius: 2
                                                    color: root.accentDim
                                                }
                                            }

                                            handle: Rectangle {
                                                x: focusSlider.visualPosition * (focusSlider.availableWidth - width)
                                                y: (focusSlider.availableHeight - height) / 2
                                                width: 12
                                                height: 12
                                                radius: 7
                                                color: root.manualFocus ? root.accent : root.textDim
                                                border.color: root.bgBase
                                                border.width: 2
                                            }
                                        }

                                        Text {
                                            text: root.percentString(focusSlider.value, focusSlider.to)
                                            color: root.accent
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 11
                                            Layout.preferredWidth: 36
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }

                            ScrollBar.vertical: ScrollBar {
                                width: 4
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle {
                                    implicitWidth: 4
                                    radius: 2
                                    color: root.borderBright
                                }
                                background: Rectangle { color: "transparent" }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 148
                color: root.bgSurface
                border.color: root.borderBright
                border.width: 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 0.5; color: root.accent }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                    opacity: 0.3
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: root.telemetryGroups

                        delegate: Item {
                            id: telemetrySection
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: telemetrySection.index < root.telemetryGroups.length - 1 ? 1 : 0
                                color: root.borderColor
                                anchors.topMargin: 12
                                anchors.bottomMargin: 12
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 6

                                Row {
                                    spacing: 6

                                    Text {
                                        text: telemetrySection.modelData.icon
                                        color: root.accentDim
                                        font.family: "Segoe UI Symbol"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        text: telemetrySection.modelData.title
                                        color: root.accentDim
                                        font.family: root.displayFontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        font.letterSpacing: 3
                                    }
                                }

                                Repeater {
                                    model: telemetrySection.modelData.items

                                    delegate: Item {
                                        id: telemetryItem
                                        required property var modelData
                                        width: parent.width
                                        height: 20

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: telemetryItem.modelData.label
                                            color: root.textMuted
                                            font.family: root.displayFontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            font.letterSpacing: 1.5
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: telemetryItem.modelData.value
                                            color: root.textPrimary
                                            font.family: root.monoFontFamily
                                            font.pixelSize: 12
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            z: 1000
            enabled: false

            Repeater {
                model: Math.ceil(root.height / 4)

                Rectangle {
                    required property int index
                    x: 0
                    y: index * 4
                    width: root.width
                    height: 2
                    color: "#14000000"
                }
            }
        }
    }

    Timer {
        id: snapTimer
        repeat: false
        onTriggered: {
            if (!streamBackend.requestedRunning && root.lastFrameTick <= 0) {
                streamBackend.reportPlaybackState(false, "No live frame available for snapshot")
                return
            }

            streamBackend.captureSnapshot()
            streamBackend.reportPlaybackState(streamBackend.online, root.snapshotSavedText())
        }
    }

    Connections {
        target: root.liveProvider

        function onImageChanged() {
            root.lastFrameTick = Date.now()
            opencvImage.reload()
            if (streamBackend.pendingRecordingStart && !streamBackend.recordingActive)
                streamBackend.startRecording()
            if (streamBackend.requestedRunning)
                streamBackend.reportPlaybackState(true, "Low-latency live stream online")
        }
    }

    Component.onCompleted: {
        root.streamController = VideoStreamer
        root.liveProvider = liveImageProvider
        root.utcClock = root.utcString()
        root.streamTs = root.tsString()

        if (root.autoStartCamera)
            streamBackend.startFeed()
    }
}
