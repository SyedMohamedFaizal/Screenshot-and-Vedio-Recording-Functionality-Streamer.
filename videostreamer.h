#ifndef VIDEOSTREAMER_H
#define VIDEOSTREAMER_H

#include <QObject>
#include <QTimer>
#include <QImage>
#include <QThread>
#include <QFile>
#include <QString>
#include <opencv2/opencv.hpp>

static cv::VideoCapture cap;

class VideoStreamer : public QObject
{
    Q_OBJECT

public:
    VideoStreamer();
    ~VideoStreamer();

public:
    void streamVideo();
    void catchFrame(cv::Mat emittedFrame);

public slots:
    void openVideoCamera(QString path);
    void stopVideoCamera();
    void streamerThreadSlot();
    void takeScreenshot();
    void toggleRecording();

signals:
    void newImage(const QImage &image);
    void emitThreadImage(cv::Mat frameThread);

private:
    QString telemetryOverlayText() const;
    cv::Mat frameWithTelemetry(const cv::Mat &sourceFrame) const;
    void drawOutlinedText(cv::Mat &targetFrame,
                          const std::string &text,
                          const cv::Point &origin,
                          double fontScale,
                          int thickness) const;

    QThread* threadStreamer;
    QTimer tUpdate;

    bool recording = false;

    cv::VideoWriter videoWriter;
    cv::Mat currentFrame;

    QFile subtitleFile;
    int frameIndex = 0;
    double fps = 25.0;
};

#endif
