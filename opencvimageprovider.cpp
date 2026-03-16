#include "opencvimageprovider.h"

OpencvImageProvider::OpencvImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
    image = QImage(200,200,QImage::Format_RGB32);
    image.fill(Qt::black);
}

QImage OpencvImageProvider::requestImage(const QString &id,
                                         QSize *size,
                                         const QSize &requestedSize)
{
    Q_UNUSED(id);

    if(size)
        *size = image.size();

    if(requestedSize.width() > 0 && requestedSize.height() > 0)
        return image.scaled(requestedSize);

    return image;
}

void OpencvImageProvider::updateImage(const QImage &img)
{
    image = img;
    //qDebug()<<"red";
    emit imageChanged();
}
