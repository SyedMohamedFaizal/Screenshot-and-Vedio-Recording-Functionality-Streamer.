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
    Q_UNUSED(requestedSize);

    if(size)
        *size = image.size();

    return image;
}

void OpencvImageProvider::updateImage(const QImage &img)
{
    image = img.copy();
    emit imageChanged();
}
