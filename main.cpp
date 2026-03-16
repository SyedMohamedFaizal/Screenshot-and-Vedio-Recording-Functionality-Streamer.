#include <QQmlContext>
#include <QWindow>
#include <QApplication>
#include <opencv2/opencv.hpp>
#include <opencv2/core.hpp>
#include <QQmlApplicationEngine>
#include "opencvimageprovider.h"
#include "videostreamer.h"
#include <QSplashScreen>

using namespace cv;
/**
 * @brief
 *
 * @param argc
 * @param argv[]
 * @return int
 */
int main(int argc, char *argv[])
{
    //std::cout << cv::getBuildInformation() << std::endl;
    QApplication a(argc, argv);
    qRegisterMetaType<cv::Mat>("cv::Mat");
    //std::cout << cv::getBuildInformation() << std::endl;
    VideoStreamer videoStreamer;

    OpencvImageProvider *liveImageProvider(new OpencvImageProvider);

    QQmlApplicationEngine engine;

    engine.rootContext()->setContextProperty("VideoStreamer", &videoStreamer);

    engine.rootContext()->setContextProperty("liveImageProvider", liveImageProvider);

    engine.addImageProvider("live", liveImageProvider);

    const QUrl url(QStringLiteral("qrc:/Main.qml"));

    QObject::connect(&videoStreamer,
                     &VideoStreamer::newImage,
                     liveImageProvider,
                     &OpencvImageProvider::updateImage);

    engine.loadFromModule("stream", "Main");
    // Tell Qt to look for modules in the local 'qml' folder we just copied
    //engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    if (engine.rootObjects().isEmpty())
        return -1;

    return a.exec();
}
