#include "input_capture.h"
#include "mainwindow.h"

#include <QApplication>
#include <QEvent>
#include <QKeyEvent>
#include <QMetaObject>
#include <QMouseEvent>
#include <QWheelEvent>
#include <QScreen>
#include <QWindow>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

// ---------------------------------------------------------------------------
// static 单例指针，供静态钩子回调访问
// ---------------------------------------------------------------------------
InputCapture * InputCapture::active_instance_ = nullptr;

InputCapture::InputCapture(QObject * parent, void * cdcHandle)
    : QObject(parent)
    , cdc_(cdcHandle)
{
    active_instance_ = this;
}

InputCapture::~InputCapture()
{
    reset();
    if (active_instance_ == this)
        active_instance_ = nullptr;
}

void InputCapture::reset()
{
    removeSystemHooks();
    kb_enabled_ = false;
    ms_enabled_ = false;
    last_mouse_pos_ = QPoint();
}

// ---------------------------------------------------------------------------
// enable / disable
// ---------------------------------------------------------------------------
void InputCapture::setKbEnabled(bool enabled)
{
    if (kb_enabled_ == enabled)
        return;
    kb_enabled_ = enabled;
    if (enabled)
        installSystemHooks();
    else if (!ms_enabled_)
        removeSystemHooks();
}

void InputCapture::setMsEnabled(bool enabled)
{
    if (ms_enabled_ == enabled)
        return;
    ms_enabled_ = enabled;
    last_mouse_pos_ = QPoint();
    if (enabled)
        installSystemHooks();
    else if (!kb_enabled_)
        removeSystemHooks();
}

// ---------------------------------------------------------------------------
// system hooks — platform-specific
// ---------------------------------------------------------------------------

void InputCapture::installSystemHooks()
{
#ifdef Q_OS_WIN
    HINSTANCE hInst = GetModuleHandleW(nullptr);

    if (kb_enabled_ && !kb_hook_)
    {
        kb_hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, kbHookProc, hInst, 0);
    }
    if (ms_enabled_ && !ms_hook_)
    {
        ms_hook_ = SetWindowsHookExW(WH_MOUSE_LL, msHookProc, hInst, 0);
    }
#endif

#ifdef Q_OS_MACOS
    extern void inputCaptureInstallKbMonitor(InputCapture * self);
    extern void inputCaptureInstallMsMonitor(InputCapture * self);
    extern void inputCaptureRemoveKbMonitor(InputCapture * self);
    extern void inputCaptureRemoveMsMonitor(InputCapture * self);

    if (kb_enabled_ && !kb_monitor_)
        inputCaptureInstallKbMonitor(this);
    if (ms_enabled_ && !ms_monitor_)
        inputCaptureInstallMsMonitor(this);
#endif
}

void InputCapture::removeSystemHooks()
{
#ifdef Q_OS_WIN
    if (kb_hook_)
    {
        UnhookWindowsHookEx(kb_hook_);
        kb_hook_ = nullptr;
    }
    if (ms_hook_)
    {
        UnhookWindowsHookEx(ms_hook_);
        ms_hook_ = nullptr;
    }
#endif

#ifdef Q_OS_MACOS
    extern void inputCaptureRemoveKbMonitor(InputCapture * self);
    extern void inputCaptureRemoveMsMonitor(InputCapture * self);

    if (kb_monitor_)
    {
        inputCaptureRemoveKbMonitor(this);
        kb_monitor_ = nullptr;
    }
    if (ms_monitor_)
    {
        inputCaptureRemoveMsMonitor(this);
        ms_monitor_ = nullptr;
    }
#endif
}

// ---------------------------------------------------------------------------
// send helpers — 调用 CDC API + 日志
// ---------------------------------------------------------------------------
void InputCapture::sendKbKey(uint8_t key, uint8_t state)
{
    if (!cdc_)
        return;
    CDCKbKey kb;
    kb.key   = key;
    kb.state = state;
    CDCSetKbKey(cdc_, &kb);
    QMetaObject::invokeMethod(MainWindow::instance(), "appendLog", Qt::QueuedConnection,
                              Q_ARG(QString, QString("kb key=0x%1 state=%2").arg(kb.key, 2, 16, QChar('0')).arg(kb.state)));
}

void InputCapture::sendMsButton(uint8_t key, uint8_t state)
{
    if (!cdc_)
        return;
    CDCMsKey ms;
    ms.key   = key;
    ms.state = state;
    CDCSetMsKey(cdc_, &ms);
    QMetaObject::invokeMethod(MainWindow::instance(), "appendLog", Qt::QueuedConnection,
                              Q_ARG(QString, QString("ms key=0x%1 state=%2").arg(ms.key, 2, 16, QChar('0')).arg(ms.state)));
}

void InputCapture::sendMsMove(int16_t dx, int16_t dy)
{
    if (!cdc_)
        return;
    CDCMsMove move;
    move.x = dx;
    move.y = dy;
    CDCSetMsMove(cdc_, &move);
    QMetaObject::invokeMethod(MainWindow::instance(), "appendLog", Qt::QueuedConnection,
                              Q_ARG(QString, QString("ms move dx=%1 dy=%2").arg(move.x).arg(move.y)));
}

void InputCapture::sendMsWheel(int16_t delta)
{
    if (!cdc_)
        return;
    CDCMsWheel wheel;
    wheel.direction = 0;  // 纵向滚轮
    wheel.delta     = delta;
    CDCSetMsWheel(cdc_, &wheel);
    QMetaObject::invokeMethod(MainWindow::instance(), "appendLog", Qt::QueuedConnection,
                              Q_ARG(QString, QString("ms wheel dir=0 delta=%1").arg(wheel.delta)));
}

void InputCapture::sendMsHWheel(int16_t delta)
{
    if (!cdc_)
        return;
    CDCMsWheel wheel;
    wheel.direction = 1;  // 横向滚轮
    wheel.delta     = delta;
    CDCSetMsWheel(cdc_, &wheel);
    QMetaObject::invokeMethod(MainWindow::instance(), "appendLog", Qt::QueuedConnection,
                              Q_ARG(QString, QString("ms wheel dir=1 delta=%1").arg(wheel.delta)));
}

// ===========================================================================
// Windows 低级钩子 (WH_KEYBOARD_LL / WH_MOUSE_LL)
// ===========================================================================
#ifdef Q_OS_WIN

// ---- 键盘 ----
LRESULT CALLBACK InputCapture::kbHookProc(int code, WPARAM wParam, LPARAM lParam)
{
    if (code == HC_ACTION && active_instance_ && active_instance_->cdc_)
    {
        auto * ks = reinterpret_cast<KBDLLHOOKSTRUCT *>(lParam);
        uint8_t state = 0;
        if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN)
            state = 1;
        else if (wParam == WM_KEYUP || wParam == WM_SYSKEYUP)
            state = 0;
        else
            goto next;

        active_instance_->sendKbKey(static_cast<uint8_t>(ks->vkCode), state);
    }
next:
    return CallNextHookEx(nullptr, code, wParam, lParam);
}

// ---- 鼠标 ----
LRESULT CALLBACK InputCapture::msHookProc(int code, WPARAM wParam, LPARAM lParam)
{
    if (code == HC_ACTION && active_instance_ && active_instance_->cdc_)
    {
        auto * ms = reinterpret_cast<MSLLHOOKSTRUCT *>(lParam);

        switch (wParam)
        {
        case WM_LBUTTONDOWN:
            active_instance_->sendMsButton(CDCKeyLButton, 1);
            break;
        case WM_LBUTTONUP:
            active_instance_->sendMsButton(CDCKeyLButton, 0);
            break;
        case WM_RBUTTONDOWN:
            active_instance_->sendMsButton(CDCKeyRButton, 1);
            break;
        case WM_RBUTTONUP:
            active_instance_->sendMsButton(CDCKeyRButton, 0);
            break;
        case WM_MBUTTONDOWN:
            active_instance_->sendMsButton(CDCKeyMButton, 1);
            break;
        case WM_MBUTTONUP:
            active_instance_->sendMsButton(CDCKeyMButton, 0);
            break;
        case WM_XBUTTONDOWN:
        {
            int xbtn = GET_XBUTTON_WPARAM(ms->mouseData);
            active_instance_->sendMsButton(
                (xbtn == 1) ? CDCKeyXButton1 : CDCKeyXButton2, 1);
            break;
        }
        case WM_XBUTTONUP:
        {
            int xbtn = GET_XBUTTON_WPARAM(ms->mouseData);
            active_instance_->sendMsButton(
                (xbtn == 1) ? CDCKeyXButton1 : CDCKeyXButton2, 0);
            break;
        }
        case WM_MOUSEMOVE:
        {
            if (!active_instance_->last_mouse_pos_.isNull())
            {
                QPoint cur(ms->pt.x, ms->pt.y);
                QPoint prev = active_instance_->last_mouse_pos_;
                active_instance_->sendMsMove(
                    static_cast<int16_t>(cur.x() - prev.x()),
                    static_cast<int16_t>(cur.y() - prev.y()));
            }
            active_instance_->last_mouse_pos_ = QPoint(ms->pt.x, ms->pt.y);
            break;
        }
        case WM_MOUSEWHEEL:
        {
            int16_t delta = static_cast<int16_t>(GET_WHEEL_DELTA_WPARAM(ms->mouseData));
            active_instance_->sendMsWheel(delta);
            break;
        }
        case WM_MOUSEHWHEEL:
        {
            int16_t delta = static_cast<int16_t>(GET_WHEEL_DELTA_WPARAM(ms->mouseData));
            active_instance_->sendMsHWheel(delta);
            break;
        }
        default:
            break;
        }
    }
    return CallNextHookEx(nullptr, code, wParam, lParam);
}

#endif // Q_OS_WIN

// ===========================================================================
// Qt eventFilter — 作为补充保留（非 Windows 平台的主要路径）
// ===========================================================================

bool InputCapture::eventFilter(QObject * obj, QEvent * event)
{
    if (event->type() == QEvent::KeyPress || event->type() == QEvent::KeyRelease)
    {
#ifndef Q_OS_WIN
        if (kb_enabled_ && cdc_)
#endif
#if defined(Q_OS_WIN)
        // Windows 上系统钩子已处理，eventFilter 不再重复发送
#elif defined(Q_OS_MACOS)
        // macOS 上监听从系统钩子回调发出，eventFilter 也参与
        if (kb_enabled_ && cdc_)
#endif
        {
            auto * ke = static_cast<QKeyEvent *>(event);
            if (ke->isAutoRepeat())
                return false;

            sendKbKey(mapQtKeyToCDC(ke->key(), ke->nativeVirtualKey()),
                      (event->type() == QEvent::KeyPress) ? 1 : 0);
        }
    }
    else if (event->type() == QEvent::MouseButtonPress ||
             event->type() == QEvent::MouseButtonRelease)
    {
#ifndef Q_OS_WIN
        if (ms_enabled_ && cdc_)
#endif
#if defined(Q_OS_WIN)
        // Windows 上跳过
#elif defined(Q_OS_MACOS)
        if (ms_enabled_ && cdc_)
#endif
        {
            auto * me = static_cast<QMouseEvent *>(event);
            sendMsButton(mapQtMouseButtonToCDC(me->button()),
                         (event->type() == QEvent::MouseButtonPress) ? 1 : 0);
        }
    }
    else if (event->type() == QEvent::MouseMove)
    {
#ifndef Q_OS_WIN
        if (ms_enabled_ && cdc_)
#endif
#if defined(Q_OS_WIN)
        // Windows 上跳过
#elif defined(Q_OS_MACOS)
        if (ms_enabled_ && cdc_)
#endif
        {
            auto * me = static_cast<QMouseEvent *>(event);
            const QPoint pos = me->globalPos();

            if (!last_mouse_pos_.isNull())
            {
                sendMsMove(static_cast<int16_t>(pos.x() - last_mouse_pos_.x()),
                           static_cast<int16_t>(pos.y() - last_mouse_pos_.y()));
            }
            last_mouse_pos_ = pos;
        }
    }
    else if (event->type() == QEvent::Wheel)
    {
#ifndef Q_OS_WIN
        if (ms_enabled_ && cdc_)
#endif
#if defined(Q_OS_WIN)
        // Windows 上跳过
#elif defined(Q_OS_MACOS)
        if (ms_enabled_ && cdc_)
#endif
        {
            auto * we = static_cast<QWheelEvent *>(event);
            const QPoint angle = we->angleDelta();

            if (!angle.isNull())
            {
                if (angle.y() != 0)
                    sendMsWheel(static_cast<int16_t>(angle.y()));
                if (angle.x() != 0)
                    sendMsHWheel(static_cast<int16_t>(angle.x()));
            }
        }
    }

    return QObject::eventFilter(obj, event);
}

// ---------------------------------------------------------------------------
// key / button mapping (unchanged)
// ---------------------------------------------------------------------------
uint8_t InputCapture::mapQtKeyToCDC(int qtKey, quint32 nativeVirtualKey)
{
    if (nativeVirtualKey > 0 && nativeVirtualKey <= 0xFF)
        return static_cast<uint8_t>(nativeVirtualKey);

    switch (qtKey)
    {
    case Qt::Key_Escape:    return CDCKeyEscape;
    case Qt::Key_Tab:       return CDCKeyTab;
    case Qt::Key_Backspace: return CDCKeyBack;
    case Qt::Key_Return:
    case Qt::Key_Enter:     return CDCKeyReturn;
    case Qt::Key_Insert:    return CDCKeyInsert;
    case Qt::Key_Delete:    return CDCKeyDelete;
    case Qt::Key_Pause:     return CDCKeyPause;
    case Qt::Key_Print:     return CDCKeyPrint;
    case Qt::Key_Home:      return CDCKeyHome;
    case Qt::Key_End:       return CDCKeyEnd;
    case Qt::Key_Left:      return CDCKeyLeft;
    case Qt::Key_Up:        return CDCKeyUp;
    case Qt::Key_Right:     return CDCKeyRight;
    case Qt::Key_Down:      return CDCKeyDown;
    case Qt::Key_PageUp:    return CDCKeyPrior;
    case Qt::Key_PageDown:  return CDCKeyNext;
    case Qt::Key_Shift:     return CDCKeyShift;
    case Qt::Key_Control:   return CDCKeyControl;
    case Qt::Key_Alt:       return CDCKeyMenu;
    case Qt::Key_CapsLock:  return CDCKeyCaptical;
    case Qt::Key_NumLock:   return CDCKeyNumlock;
    case Qt::Key_ScrollLock:return CDCKeyScroll;
    case Qt::Key_F1:  return CDCKeyF1;  case Qt::Key_F2:  return CDCKeyF2;
    case Qt::Key_F3:  return CDCKeyF3;  case Qt::Key_F4:  return CDCKeyF4;
    case Qt::Key_F5:  return CDCKeyF5;  case Qt::Key_F6:  return CDCKeyF6;
    case Qt::Key_F7:  return CDCKeyF7;  case Qt::Key_F8:  return CDCKeyF8;
    case Qt::Key_F9:  return CDCKeyF9;  case Qt::Key_F10: return CDCKeyF10;
    case Qt::Key_F11: return CDCKeyF11; case Qt::Key_F12: return CDCKeyF12;
    case Qt::Key_F13: return CDCKeyF13; case Qt::Key_F14: return CDCKeyF14;
    case Qt::Key_F15: return CDCKeyF15; case Qt::Key_F16: return CDCKeyF16;
    case Qt::Key_F17: return CDCKeyF17; case Qt::Key_F18: return CDCKeyF18;
    case Qt::Key_F19: return CDCKeyF19; case Qt::Key_F20: return CDCKeyF20;
    case Qt::Key_F21: return CDCKeyF21; case Qt::Key_F22: return CDCKeyF22;
    case Qt::Key_F23: return CDCKeyF23; case Qt::Key_F24: return CDCKeyF24;
    case Qt::Key_Space:  return CDCKeySpace;
    case Qt::Key_Menu:   return CDCKeyMenu;
    case Qt::Key_Meta:   return CDCKeyLWin;
    default:
        if (qtKey >= Qt::Key_A && qtKey <= Qt::Key_Z)
            return static_cast<uint8_t>(CDCKeyA + (qtKey - Qt::Key_A));
        if (qtKey >= Qt::Key_0 && qtKey <= Qt::Key_9)
            return static_cast<uint8_t>(CDCKey0 + (qtKey - Qt::Key_0));
        break;
    }
    return 0;
}

uint8_t InputCapture::mapQtMouseButtonToCDC(Qt::MouseButton button)
{
    switch (button)
    {
    case Qt::LeftButton:  return CDCKeyLButton;
    case Qt::RightButton: return CDCKeyRButton;
    case Qt::MiddleButton:return CDCKeyMButton;
    case Qt::XButton1:    return CDCKeyXButton1;
    case Qt::XButton2:    return CDCKeyXButton2;
    default:              return 0;
    }
}

// ===========================================================================
// macOS 桥接 — 供 input_capture_mac.mm 的 C 回调使用
// ===========================================================================
#ifdef Q_OS_MACOS
extern "C" {

InputCapture * inputCaptureGetActive()
{
    return InputCapture::active_instance_;
}

void inputCaptureBridgeKbKey(void * cdc, uint8_t key, uint8_t state)
{
    if (!cdc) return;
    CDCKbKey kb;
    kb.key   = key;
    kb.state = state;
    CDCSetKbKey(cdc, &kb);
}

void inputCaptureBridgeMsButton(void * cdc, uint8_t key, uint8_t state)
{
    if (!cdc) return;
    CDCMsKey ms;
    ms.key   = key;
    ms.state = state;
    CDCSetMsKey(cdc, &ms);
}

void inputCaptureBridgeMsMove(void * cdc, int16_t dx, int16_t dy)
{
    if (!cdc) return;
    CDCMsMove move;
    move.x = dx;
    move.y = dy;
    CDCSetMsMove(cdc, &move);
}

void inputCaptureBridgeMsWheel(void * cdc, int16_t delta)
{
    if (!cdc) return;
    CDCMsWheel wheel;
    wheel.direction = 0;
    wheel.delta     = delta;
    CDCSetMsWheel(cdc, &wheel);
}

void inputCaptureBridgeMsHWheel(void * cdc, int16_t delta)
{
    if (!cdc) return;
    CDCMsWheel wheel;
    wheel.direction = 1;
    wheel.delta     = delta;
    CDCSetMsWheel(cdc, &wheel);
}

} // extern "C"
#endif
