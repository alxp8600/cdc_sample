// cam_preview_dialog.cpp
// 摄像头预览对话框, 内嵌 CamPreviewWidget 供 CDC SDK 渲染摄像头原始帧

#include "cam_preview_dialog.h"
#include "cam_preview_widget.h"

#include <QVBoxLayout>
#include <QCloseEvent>
#include <QShowEvent>

CamPreviewDialog::CamPreviewDialog(QWidget * parent)
    : QDialog(parent)
{
    setWindowTitle("Camera Preview");
    setFixedSize(1280, 720);

    auto * layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);

    preview_widget_ = new CamPreviewWidget(this);
    layout->addWidget(preview_widget_);
}

CamPreviewDialog::~CamPreviewDialog() = default;

void CamPreviewDialog::closeEvent(QCloseEvent * event)
{
    event->ignore();
    hide();
}

void CamPreviewDialog::showEvent(QShowEvent * event)
{
    QDialog::showEvent(event);
}

void * CamPreviewDialog::previewLayer() const
{
    return preview_widget_ ? preview_widget_->metalLayer() : nullptr;
}