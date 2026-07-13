#ifndef CAM_PREVIEW_WIDGET_H_
#define CAM_PREVIEW_WIDGET_H_

#include <QWidget>

#ifdef __OBJC__
@class CAMetalLayer;
#else
typedef void CAMetalLayer;
#endif

/*
 * CamPreviewWidget
 * macOS 专用: 内嵌 CAMetalLayer 的 Qt Widget, 供 CDC SDK 摄像头预览渲染
 * 在 Mac 上通过嵌入原生的 NSView + CAMetalLayer 实现 Metal 渲染
 */
class CamPreviewWidget : public QWidget
{
    Q_OBJECT

public:
    explicit CamPreviewWidget(QWidget * parent = nullptr);
    ~CamPreviewWidget() override;

    /*
     * metalLayer
     * 返回内部的 CAMetalLayer 指针, 用于传递给 CDC SDK 的 cam_wnd
     * @return CAMetalLayer* 指针, 生命周期由本 Widget 管理
     */
    void * metalLayer() const;

protected:
    void resizeEvent(QResizeEvent * event) override;

private:
    void * view_ = nullptr;   // 原生 NSView* 指针
};

#endif // CAM_PREVIEW_WIDGET_H_