#include "videostreamer.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <QTextStream>
#include <QPainter>
#include <QTime>

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

            int currentSecond = frameIndex / fps;
            static int lastSubtitleSecond = -1;

            if(currentSecond != lastSubtitleSecond && subtitleFile.isOpen())
            {
                lastSubtitleSecond = currentSecond;

                QTextStream out(&subtitleFile);

                int startSec = currentSecond;
                int endSec = currentSecond + 1;

                QTime startTime(0,0);
                startTime = startTime.addSecs(startSec);

                QTime endTime(0,0);
                endTime = endTime.addSecs(endSec);

                QString startStr =
                    QString("%1:%2:%3.00")
                        .arg(startTime.hour())
                        .arg(startTime.minute(),2,10,QChar('0'))
                        .arg(startTime.second(),2,10,QChar('0'));

                QString endStr =
                    QString("%1:%2:%3.00")
                        .arg(endTime.hour())
                        .arg(endTime.minute(),2,10,QChar('0'))
                        .arg(endTime.second(),2,10,QChar('0'));

                QString telemetry =
                    QDateTime::currentDateTime()
                        .toString("yyyy-MM-dd HH:mm:ss")
                    + " | CPU: 90 % | Pressure: 10 bar | Depth: 20 m";

                out << "Dialogue: 0," << startStr << "," << endStr
                    << ",Default,,0,0,0,," << telemetry << "\n";
            }

            frameIndex++;
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

        QString rtspUrl;

        if(path.startsWith("rtsp://"))
        {
            QString stripped = path.mid(7);
            rtspUrl = "rtsp://" + username + ":" + password + "@" + stripped;
        }
        else
        {
            rtspUrl =
                "rtsp://" + username + ":" + password + "@"
                + path + ":554/video/live?channel=1&subtype=0";
        }

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

    QString telemetry =
        QDateTime::currentDateTime()
            .toString("yyyy-MM-dd HH:mm:ss")
        + " | CPU: 90 % | Pressure: 10 bar | Depth: 20 m";

    QPainter painter(&img);

    painter.setPen(Qt::white);
    painter.setFont(QFont("Consolas",20,QFont::Bold));

    painter.drawText(img.rect(),
                     Qt::AlignBottom | Qt::AlignHCenter,
                     telemetry);

    painter.end();

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

        out << "Style: Default,Consolas,24,&H00FFFFFF,&H000000FF,&H00000000,&H64000000,"
               "-1,0,0,0,100,100,0,0,1,2,0,2,10,10,30,1\n\n";

        out << "[Events]\n";
        out << "Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text\n";

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
