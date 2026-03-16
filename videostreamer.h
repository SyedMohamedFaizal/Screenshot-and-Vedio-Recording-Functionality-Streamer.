#ifndef VIDEOSTREAMER_H
#define VIDEOSTREAMER_H

#include <QObject>
#include <QTimer>
#include <QImage>
#include <QThread>
#include <QFile>
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
    void streamerThreadSlot();
    void takeScreenshot();
    void toggleRecording();

signals:
    void newImage(QImage &);
    void emitThreadImage(cv::Mat frameThread);

private:
    QThread* threadStreamer;
    QTimer tUpdate;

    bool recording = false;

    cv::VideoWriter videoWriter;

    QFile subtitleFile;
    int frameIndex = 0;
    double fps = 25.0;
};

#endif
