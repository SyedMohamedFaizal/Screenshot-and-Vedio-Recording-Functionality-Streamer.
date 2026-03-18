#include "videostreamer.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <algorithm>
#include <string>

VideoStreamer::VideoStreamer()
{
    threadStreamer = new QThread(this);
}

VideoStreamer::~VideoStreamer()
{
    cap.release();
    tUpdate.stop();

    if(videoWriter.isOpened())
        videoWriter.release();

    if(subtitleFile.isOpen())
        subtitleFile.close();

    threadStreamer->requestInterruption();
    threadStreamer->quit();
    threadStreamer->wait();

    delete threadStreamer;
}

void VideoStreamer::streamVideo()
{
    if(currentFrame.empty())
        return;

    cv::Mat outputFrame = frameWithTelemetry(currentFrame);

    QImage img(currentFrame.data,
               currentFrame.cols,
               currentFrame.rows,
               currentFrame.step,
               QImage::Format_BGR888);

    emit newImage(img.copy());

    if(recording && videoWriter.isOpened())
    {
        videoWriter.write(outputFrame);
        frameIndex++;
    }
}

void VideoStreamer::catchFrame(cv::Mat emittedFrame)
{
    if(emittedFrame.empty())
        return;

    currentFrame = emittedFrame.clone();
    streamVideo();
}

void VideoStreamer::openVideoCamera(QString path)
{
    stopVideoCamera();

    const QString inputPath = path.trimmed();

    if(inputPath == "0" || inputPath == "1")
    {
        qDebug() << "Opening webcam:" << inputPath;
        cap.open(inputPath.toInt(), cv::CAP_DSHOW);
    }
    else
    {
        const QString streamUrl = inputPath.isEmpty()
                ? "rtsp://192.168.56.2:8554/quality_h264"
                : inputPath;
        const QString pipeline =
                QString("rtspsrc location=%1 protocols=tcp latency=0 drop-on-latency=true ! "
                        "rtph264depay ! h264parse ! decodebin ! queue max-size-buffers=1 leaky=downstream ! "
                        "videoconvert ! appsink sync=false max-buffers=1 drop=true")
                .arg(streamUrl);

        qDebug() << "Opening RTSP stream:" << streamUrl;
        cap.open(pipeline.toStdString(), cv::CAP_GSTREAMER);
    }

    if(!cap.isOpened())
    {
        qDebug() << "Camera/IP Stream not opened";
        return;
    }

    fps = cap.get(cv::CAP_PROP_FPS);
    if(fps <= 0)
        fps = 40;

    cap.set(cv::CAP_PROP_BUFFERSIZE, 1);

    qDebug()<<fps;
    VideoStreamer* worker = new VideoStreamer();

    worker->moveToThread(threadStreamer);

    connect(threadStreamer, SIGNAL(started()),
            worker, SLOT(streamerThreadSlot()));

    connect(worker, &VideoStreamer::emitThreadImage,
            this, &VideoStreamer::catchFrame,
            Qt::BlockingQueuedConnection);

    connect(threadStreamer, &QThread::finished,
            worker, &QObject::deleteLater);

    threadStreamer->start();
}

void VideoStreamer::stopVideoCamera()
{
    tUpdate.stop();

    if(videoWriter.isOpened())
        videoWriter.release();

    if(subtitleFile.isOpen())
        subtitleFile.close();

    recording = false;
    frameIndex = 0;
    currentFrame.release();

    if(threadStreamer->isRunning())
    {
        threadStreamer->requestInterruption();
        threadStreamer->quit();
        threadStreamer->wait();
    }

    if(cap.isOpened())
        cap.release();
}

void VideoStreamer::streamerThreadSlot()
{
    cv::Mat tempFrame;

    while(!QThread::currentThread()->isInterruptionRequested())
    {
        if(cap.read(tempFrame) && !tempFrame.empty())
            emit emitThreadImage(tempFrame.clone());
        else
            QThread::msleep(2);

        if(QThread::currentThread()->isInterruptionRequested())
        {
            cap.release();
            return;
        }
    }
}

void VideoStreamer::takeScreenshot()
{
    if(currentFrame.empty())
        return;

    const cv::Mat outputFrame = frameWithTelemetry(currentFrame);
    QImage img(outputFrame.data,
               outputFrame.cols,
               outputFrame.rows,
               outputFrame.step,
               QImage::Format_BGR888);

    QString picturesPath =
        QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);

    QString savePath = picturesPath + "/test_streamer";

    QDir dir(savePath);

    if(!dir.exists())
        dir.mkpath(".");

    QString fileName =
        "screenshot_" +
        QDateTime::currentDateTime()
            .toString("yyyy.MM.dd-hh.mm.ss") + ".jpg";

    img.copy().save(savePath + "/" + fileName,"JPG");
}

void VideoStreamer::toggleRecording()
{
    if(currentFrame.empty())
    {
        qDebug() << "Recording unavailable: no current frame";
        return;
    }

    QString videoRoot =
        QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);

    QString savePath = videoRoot + "/test_streamer";

    QDir dir(savePath);

    if(!dir.exists())
        dir.mkpath(".");

    if(!recording)
    {
        QString baseName =
            "video_" +
            QDateTime::currentDateTime()
                .toString("yyyy.MM.dd-hh.mm.ss");

        QString videoPath = savePath + "/" + baseName + ".mp4";

        videoWriter.open(
            videoPath.toStdString(),
            cv::VideoWriter::fourcc('H','2','6','4'),
            fps,
            cv::Size(currentFrame.cols,currentFrame.rows)
            );

        if(!videoWriter.isOpened())
        {
            qDebug()<<"Recording failed";
            return;
        }

        frameIndex = 0;
        recording = true;

        qDebug()<<"Recording started:"<<videoPath;
    }
    else
    {
        recording = false;

        if(videoWriter.isOpened())
            videoWriter.release();

        if(subtitleFile.isOpen())
            subtitleFile.close();

        qDebug()<<"Recording stopped";
    }
}

QString VideoStreamer::telemetryOverlayText() const
{
    return QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss")
            + " | CPU: 90 % | Pressure: 10 bar | Depth: 20 m";
}

cv::Mat VideoStreamer::frameWithTelemetry(const cv::Mat &sourceFrame) const
{
    if(sourceFrame.empty())
        return cv::Mat();

    cv::Mat outputFrame = sourceFrame.clone();
    const std::string overlayText = telemetryOverlayText().toStdString();
    const double fontScale = std::clamp(outputFrame.cols / 1400.0, 0.8, 1.5);
    const int thickness = std::max(2, static_cast<int>(fontScale * 2.4));
    int baseline = 0;
    const cv::Size textSize = cv::getTextSize(overlayText,
                                              cv::FONT_HERSHEY_DUPLEX,
                                              fontScale,
                                              thickness,
                                              &baseline);
    const int margin = std::max(18, outputFrame.cols / 50);
    const cv::Point origin(margin,
                           std::max(textSize.height + margin,
                                    outputFrame.rows - margin));

    drawOutlinedText(outputFrame,
                     overlayText,
                     origin,
                     fontScale,
                     thickness);

    return outputFrame;
}

void VideoStreamer::drawOutlinedText(cv::Mat &targetFrame,
                                     const std::string &text,
                                     const cv::Point &origin,
                                     double fontScale,
                                     int thickness) const
{
    const int outlineThickness = thickness + 3;

    cv::putText(targetFrame,
                text,
                origin,
                cv::FONT_HERSHEY_DUPLEX,
                fontScale,
                cv::Scalar(0, 0, 0),
                outlineThickness,
                cv::LINE_AA);

    cv::putText(targetFrame,
                text,
                origin,
                cv::FONT_HERSHEY_DUPLEX,
                fontScale,
                cv::Scalar(255, 255, 255),
                thickness,
                cv::LINE_AA);
}
