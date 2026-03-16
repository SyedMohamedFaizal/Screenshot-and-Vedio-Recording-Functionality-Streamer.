#include "videostreamer.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>

cv::Mat frame;

VideoStreamer::VideoStreamer()
{
    threadStreamer = new QThread(this);

    connect(&tUpdate, &QTimer::timeout,
            this, &VideoStreamer::streamVideo);
}

VideoStreamer::~VideoStreamer()
{
    cap.release();
    tUpdate.stop();

    if(videoWriter.isOpened())
        videoWriter.release();

    threadStreamer->requestInterruption();
    threadStreamer->quit();
    threadStreamer->wait();

    delete threadStreamer;
}

void VideoStreamer::streamVideo()
{
    if(frame.data)
    {
        QImage img(frame.data,
                   frame.cols,
                   frame.rows,
                   QImage::Format_RGB888);

        img = img.rgbSwapped();

        emit newImage(img);

        if(recording && videoWriter.isOpened())
        {
            videoWriter.write(frame);
        }
    }
}

void VideoStreamer::catchFrame(cv::Mat emittedFrame)
{
    frame = emittedFrame;
}

void VideoStreamer::openVideoCamera(QString path)
{
    if(path.length() == 1)
        cap.open(path.toInt());
    else
        cap.open(path.toStdString());

    if(!cap.isOpened())
        qDebug()<<"Camera not opened";

    VideoStreamer* worker = new VideoStreamer();

    worker->moveToThread(threadStreamer);

    connect(threadStreamer,SIGNAL(started()),
            worker, SLOT(streamerThreadSlot()));

    connect(worker, &VideoStreamer::emitThreadImage,
            this, &VideoStreamer::catchFrame);

    threadStreamer->start();

    double fps = cap.get(cv::CAP_PROP_FPS);

    if(fps <= 0)
        fps = 30;

    tUpdate.start(1000 / fps);
}

void VideoStreamer::streamerThreadSlot()
{
    cv::Mat tempFrame;

    while(!QThread::currentThread()->isInterruptionRequested())
    {
        cap >> tempFrame;

        if(tempFrame.data)
            emit emitThreadImage(tempFrame);

        if(QThread::currentThread()->isInterruptionRequested())
        {
            cap.release();
            return;
        }
    }
}

void VideoStreamer::takeScreenshot()
{
    if(!frame.data)
        return;

    QImage img(frame.data,
               frame.cols,
               frame.rows,
               QImage::Format_RGB888);

    img = img.rgbSwapped();

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

    QString fullPath = savePath + "/" + fileName;

    img.save(fullPath,"JPG");
}

void VideoStreamer::toggleRecording()
{
    QString videoRoot =
        QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);

    QString savePath = videoRoot + "/test_streamer";

    QDir dir(savePath);

    if(!dir.exists())
        dir.mkpath(".");

    if(!recording)
    {
        QString fileName =
            "video_" +
            QDateTime::currentDateTime()
                .toString("yyyy.MM.dd-hh.mm.ss") + ".mp4";

        QString fullPath = savePath + "/" + fileName;

        int fps = cap.get(cv::CAP_PROP_FPS);

        if(fps <= 0)
            fps = 25;

        videoWriter.open(
            fullPath.toStdString(),
            cv::VideoWriter::fourcc('a','v','c','1'),
            fps,
            cv::Size(frame.cols, frame.rows)
            );

        if(!videoWriter.isOpened())
        {
            qDebug()<<"Recording failed";
            return;
        }

        recording = true;

        qDebug()<<"Recording started:"<<fullPath;
    }
    else
    {
        recording = false;

        if(videoWriter.isOpened())
            videoWriter.release();

        qDebug()<<"Recording stopped";
    }
}
