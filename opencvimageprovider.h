#ifndef OPENCVIMAGEPROVIDER_H
#define OPENCVIMAGEPROVIDER_H

#include <QQuickImageProvider>
#include <QImage>
#include <QObject>

class OpencvImageProvider : public QQuickImageProvider
{
    Q_OBJECT

public:
    OpencvImageProvider();

    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override;

public slots:
    void updateImage(const QImage &image);

signals:
    void imageChanged();

private:
    QImage image;
};

#endif
