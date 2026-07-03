#ifndef INPUT_CAPTURE_H_
#define INPUT_CAPTURE_H_

#include <QObject>
#include <QPoint>

#include "cdc.h"

#ifdef Q_OS_WIN
#include <windows.h>
#endif
#ifdef Q_OS_MACOS
#ifdef __OBJC__
@class NSEventMonitor;
#else
typedef struct objc_object NSEventMonitor;
#endif
#endif

class QEvent;

// InputCapture 管理键盘/鼠标事件捕获。
// - 在系统层面通过平台低级钩子捕获全局输入（离开窗口也生效）
// - Qt eventFilter 作为补充（捕获 Qt 能收到的窗口内事件）
class InputCapture : public QObject
{
    Q_OBJECT

public:
    explicit InputCapture(QObject * parent, void * cdcHandle);
    ~InputCapture() override;

    bool isKbEnabled() const { return kb_enabled_; }
    bool isMsEnabled() const { return ms_enabled_; }
    bool isGpEnabled() const { return gp_enabled_; }

    void * cdcHandle() const { return cdc_; }

    static InputCapture * activeInstance() { return active_instance_; }

    void setKbEnabled(bool enabled);
    void setMsEnabled(bool enabled);
    void setGpEnabled(bool enabled);

    // reset: 关闭所有捕获
    void reset();

    // send helpers — 调用 CDC API + 日志（macOS CGEventTap 回调也使用）
    void sendKbKey(uint8_t key, uint8_t state);
    void sendMsButton(uint8_t key, uint8_t state);
    void sendMsMove(int16_t dx, int16_t dy);
    void sendMsWheel(int16_t delta);
    void sendMsHWheel(int16_t delta);
    void sendGpState(const CDCGpState & state);
    void sendGpCmd(const CDCGpCmd & cmd);

protected:
    bool eventFilter(QObject * obj, QEvent * event) override;

private:
    void installSystemHooks();
    void removeSystemHooks();

    static uint8_t mapQtKeyToCDC(int qtKey, quint32 nativeVirtualKey);
    static uint8_t mapQtMouseButtonToCDC(Qt::MouseButton button);

    void * cdc_ = nullptr;

    bool kb_enabled_ = false;
    bool ms_enabled_ = false;
    bool gp_enabled_ = false;
    QPoint last_mouse_pos_;

#ifdef Q_OS_WIN
    HHOOK kb_hook_ = nullptr;
    HHOOK ms_hook_ = nullptr;
    static LRESULT CALLBACK kbHookProc(int code, WPARAM wParam, LPARAM lParam);
    static LRESULT CALLBACK msHookProc(int code, WPARAM wParam, LPARAM lParam);
#endif
#ifdef Q_OS_MACOS
    NSEventMonitor * kb_monitor_ = nullptr;
    NSEventMonitor * ms_monitor_ = nullptr;
    NSEventMonitor * gp_monitor_ = nullptr;
#endif
    static InputCapture * active_instance_;
};

#endif // INPUT_CAPTURE_H_
