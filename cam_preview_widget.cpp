// cam_preview_widget.cpp
// Stub implementation for non-Apple platforms (Windows, Linux)
// On these platforms, previewLayer() returns nullptr — no native rendering window

#include "cam_preview_widget.h"

CamPreviewWidget::CamPreviewWidget(QWidget * parent)
    : QWidget(parent)
{
}

CamPreviewWidget::~CamPreviewWidget() = default;

void * CamPreviewWidget::metalLayer() const
{
    return nullptr;
}

void CamPreviewWidget::resizeEvent(QResizeEvent * event)
{
    QWidget::resizeEvent(event);
}