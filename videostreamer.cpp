#include "videostreamer.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <QTextStream>

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

    if(subtitleFile.isOpen())
        subtitleFile.close();

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

            if(subtitleFile.isOpen())
            {
                QTextStream out(&subtitleFile);

                double start = frameIndex / fps;
                double end = (frameIndex + 1) / fps;

                QString startTime =
                    QTime(0,0).addMSecs(start*1000)
                        .toString("H:mm:ss.zzz");

                QString endTime =
                    QTime(0,0).addMSecs(end*1000)
                        .toString("H:mm:ss.zzz");

                QString telemetry =
                    QDateTime::currentDateTime()
                        .toString("yyyy-MM-dd HH:mm:ss")
                    + " | CPU:90% | Pressure:10 bar | Depth:20 m";

                out << "Dialogue: 0," << startTime << "," << endTime
                    << ",Default,,0,0,0,," << telemetry << "\n";

                frameIndex++;
            }
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

    if(path == "0" || path == "1")
    {
        cap.open(path.toInt(), cv::CAP_ANY);
    }
    else
    {
        QString username = "admin";
        QString password = "Vikra%40123";

        QString rtspUrl =
            "rtsp://" + username + ":" + password + "@"
            + path + ":554/video/live?channel=1&subtype=0";

        qDebug()<<"Opening RTSP:"<<rtspUrl;

        cap.open(rtspUrl.toStdString(), cv::CAP_FFMPEG);
        cap.set(cv::CAP_PROP_BUFFERSIZE,1);
    }

    if(!cap.isOpened())
    {
        qDebug()<<"Camera/IP Stream not opened";
        return;
    }

    fps = cap.get(cv::CAP_PROP_FPS);

    if(fps <= 0)
        fps = 25;

    VideoStreamer* worker = new VideoStreamer();

    worker->moveToThread(threadStreamer);

    connect(threadStreamer,SIGNAL(started()),
            worker,SLOT(streamerThreadSlot()));

    connect(worker,&VideoStreamer::emitThreadImage,
            this,&VideoStreamer::catchFrame);

    threadStreamer->start();

    tUpdate.start(1000/fps);
}

void VideoStreamer::streamerThreadSlot()
{
    cv::Mat tempFrame;

    while(!QThread::currentThread()->isInterruptionRequested())
    {
        cap>>tempFrame;

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

    img.save(savePath + "/" + fileName,"JPG");
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
        QString baseName =
            "video_" +
            QDateTime::currentDateTime()
                .toString("yyyy.MM.dd-hh.mm.ss");

        QString videoPath = savePath + "/" + baseName + ".mp4";
        QString subtitlePath = savePath + "/" + baseName + ".ass";

        videoWriter.open(
            videoPath.toStdString(),
            cv::VideoWriter::fourcc('H','2','6','4'),
            fps,
            cv::Size(frame.cols,frame.rows)
            );

        if(!videoWriter.isOpened())
        {
            qDebug()<<"Recording failed";
            return;
        }

        subtitleFile.setFileName(subtitlePath);
        subtitleFile.open(QIODevice::WriteOnly | QIODevice::Text);

        QTextStream out(&subtitleFile);

        out << "[Script Info]\n";
        out << "ScriptType: v4.00+\n\n";

        out << "[V4+ Styles]\n";
        out << "Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,"
               "Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,"
               "Alignment,MarginL,MarginR,MarginV,Encoding\n";

        out << "Style: Default,Consolas,20,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,"
               "-1,0,0,0,100,100,0,0,1,2,0,7,10,10,10,1\n\n";

        out << "[Events]\n";
        out << "Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text\n";

        frameIndex = 0;
        recording = true;

        qDebug()<<"Recording started:"<<videoPath;
    }
    else
    {
        recording=false;

        if(videoWriter.isOpened())
            videoWriter.release();

        if(subtitleFile.isOpen())
            subtitleFile.close();

        qDebug()<<"Recording stopped";
    }
}
