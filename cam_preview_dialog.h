#ifndef CAM_PREVIEW_DIALOG_H_
#define CAM_PREVIEW_DIALOG_H_

#include <QDialog>
#include <QPushButton>

class QLabel;

class CamPreviewWidget;

/*
 * CamPreviewDialog
 * 摄像头本地预览对话框, 内部使用 CAMetalLayer (macOS) 渲染摄像头原始帧
 * 通过 CDCSetCamPreviewWindow 将 Metal layer 句柄传递给 CDC SDK 的 Cam 模块
 */
class CamPreviewDialog : public QDialog
{
    Q_OBJECT

public:
    explicit CamPreviewDialog(QWidget * parent = nullptr);
    ~CamPreviewDialog() override;

    /*
     * previewLayer
     * 返回内部的 CAMetalLayer 指针, 用于传递给 CDC SDK 的 cam_wnd.wnd
     * @return CAMetalLayer* 指针, 生命周期由本 Dialog 管理
     */
    void * previewLayer() const;

protected:
    void closeEvent(QCloseEvent * event) override;
    void showEvent(QShowEvent * event) override;

private:
    CamPreviewWidget * preview_widget_ = nullptr;
};

#endif // CAM_PREVIEW_DIALOG_H_