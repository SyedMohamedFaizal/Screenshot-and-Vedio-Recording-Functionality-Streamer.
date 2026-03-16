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
    if(cap.isOpened())
        cap.release();

    /*
        Webcam usage
        0
        1
    */

    if(path == "0" || path == "1")
    {
        qDebug() << "Opening webcam:" << path;

        cap.open(path.toInt(), cv::CAP_ANY);
    }
    else
    {
        QString username = "admin";
        QString password = "Vikra%40123";

        QString rtspUrl;

        if(path.startsWith("rtsp://"))
        {
            QString stripped = path.mid(7);
            rtspUrl = "rtsp://" + username + ":" + password + "@" + stripped;
        }
        else
        {
            rtspUrl = "rtsp://" + username + ":" + password + "@" + path +
                      ":554/video/live?channel=1&subtype=0";
        }

        qDebug() << "Opening RTSP stream:";
        qDebug() << rtspUrl;

        cap.open(rtspUrl.toStdString(), cv::CAP_FFMPEG);

        // reduce buffering for IP camera
        cap.set(cv::CAP_PROP_BUFFERSIZE, 1);
    }

    if(!cap.isOpened())
    {
        qDebug() << "Camera/IP Stream not opened";
        return;
    }

    VideoStreamer* worker = new VideoStreamer();
    worker->moveToThread(threadStreamer);

    connect(threadStreamer,SIGNAL(started()),
            worker,SLOT(streamerThreadSlot()));

    connect(worker,&VideoStreamer::emitThreadImage,
            this,&VideoStreamer::catchFrame);

    threadStreamer->start();

    double fps = cap.get(cv::CAP_PROP_FPS);

    if(fps <= 0)
        fps = 25;

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
            fps = 30;

        videoWriter.open(
            fullPath.toStdString(),
            cv::VideoWriter::fourcc('H','2','6','4'),
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

