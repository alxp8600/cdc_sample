// ---------------------------------------------------------------------------
// input_capture_mac.mm — macOS CGEventTap 系统级全局键盘/鼠标监听
// 需要辅助功能权限 (System Preferences → Privacy → Accessibility)
// ---------------------------------------------------------------------------
#ifdef Q_OS_MACOS

#include "input_capture.h"

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

// ---- 桥接函数声明 (实现在 input_capture.cpp) ----
extern "C" {
void inputCaptureBridgeKbKey(void * cdc, uint8_t key, uint8_t state);
void inputCaptureBridgeMsButton(void * cdc, uint8_t key, uint8_t state);
void inputCaptureBridgeMsMove(void * cdc, int16_t dx, int16_t dy);
void inputCaptureBridgeMsWheel(void * cdc, int16_t delta);
void inputCaptureBridgeMsHWheel(void * cdc, int16_t delta);
}

// ---- 获取当前活跃的 InputCapture 实例 ----
static InputCapture * getActiveCapture()
{
    extern InputCapture * inputCaptureGetActive();
    return inputCaptureGetActive();
}

// ---- 将 CGKeyCode 映射为 CDC 键码 (基于 Windows VK) ----
static uint8_t mapCGKeyToCDC(CGKeyCode keyCode)
{
    // 字母键 A-Z：macOS kVK_ANSI_A (0) ~ kVK_ANSI_Z (25)
    if (keyCode >= 0 && keyCode <= 25)
        return static_cast<uint8_t>(CDCKeyA + keyCode);

    switch (keyCode)
    {
    // ---- 数字行 (ANSI) ----
    case 29: return CDCKey0;
    case 18: return CDCKey1;
    case 19: return CDCKey2;
    case 20: return CDCKey3;
    case 21: return CDCKey4;
    case 23: return CDCKey5;
    case 22: return CDCKey6;
    case 26: return CDCKey7;
    case 28: return CDCKey8;
    case 25: return CDCKey9;

    // ---- 功能键 ----
    case 53:  return CDCKeyEscape;
    case 48:  return CDCKeyTab;
    case 51:  return CDCKeyBack;
    case 36:  return CDCKeyReturn;
    case 49:  return CDCKeySpace;
    case 114: return CDCKeyInsert;
    case 117: return CDCKeyDelete;
    case 115: return CDCKeyHome;
    case 119: return CDCKeyEnd;
    case 116: return CDCKeyPrior;
    case 121: return CDCKeyNext;
    case 123: return CDCKeyLeft;
    case 126: return CDCKeyUp;
    case 124: return CDCKeyRight;
    case 125: return CDCKeyDown;

    // ---- 修饰键 ----
    case 56: return CDCKeyShift;   // Shift (left)
    case 60: return CDCKeyShift;   // Shift (right)
    case 59: return CDCKeyControl; // Control (left)
    case 62: return CDCKeyControl; // Control (right)
    case 55: return CDCKeyMenu;    // Command
    case 54: return CDCKeyMenu;
    case 58: return CDCKeyMenu;    // Option
    case 61: return CDCKeyMenu;
    case 57: return CDCKeyCaptical;

    // ---- F1-F20 ----
    case 122: return CDCKeyF1;  case 120: return CDCKeyF2;
    case 99:  return CDCKeyF3;  case 118: return CDCKeyF4;
    case 96:  return CDCKeyF5;  case 97:  return CDCKeyF6;
    case 98:  return CDCKeyF7;  case 100: return CDCKeyF8;
    case 101: return CDCKeyF9;  case 109: return CDCKeyF10;
    case 103: return CDCKeyF11; case 111: return CDCKeyF12;
    case 105: return CDCKeyF13; case 107: return CDCKeyF14;
    case 113: return CDCKeyF15; case 106: return CDCKeyF16;
    case 64:  return CDCKeyF17; case 79:  return CDCKeyF18;
    case 80:  return CDCKeyF19; case 90:  return CDCKeyF20;

    default: return 0;
    }
}

// ===========================================================================
// EventTap 回调
// ===========================================================================

static CGEventRef kbEventTapCallback(CGEventTapProxy /*proxy*/,
                                     CGEventType type,
                                     CGEventRef event,
                                     void * /*userInfo*/)
{
    InputCapture * cap = getActiveCapture();
    if (!cap || !cap->isKbEnabled())
        return event;

    if (type == kCGEventKeyDown || type == kCGEventKeyUp)
    {
        CGKeyCode keyCode = static_cast<CGKeyCode>(
            CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode));
        uint8_t cdcKey = mapCGKeyToCDC(keyCode);
        if (cdcKey != 0)
        {
            uint8_t state = (type == kCGEventKeyDown) ? 1 : 0;
            inputCaptureBridgeKbKey(cap->cdcHandle(), cdcKey, state);
        }
    }

    return event;
}

static CGEventRef msEventTapCallback(CGEventTapProxy /*proxy*/,
                                     CGEventType type,
                                     CGEventRef event,
                                     void * /*userInfo*/)
{
    InputCapture * cap = getActiveCapture();
    if (!cap || !cap->isMsEnabled())
        return event;

    void * cdc = cap->cdcHandle();

    switch (type)
    {
    case kCGEventLeftMouseDown:
        inputCaptureBridgeMsButton(cdc, CDCKeyLButton, 1); break;
    case kCGEventLeftMouseUp:
        inputCaptureBridgeMsButton(cdc, CDCKeyLButton, 0); break;
    case kCGEventRightMouseDown:
        inputCaptureBridgeMsButton(cdc, CDCKeyRButton, 1); break;
    case kCGEventRightMouseUp:
        inputCaptureBridgeMsButton(cdc, CDCKeyRButton, 0); break;
    case kCGEventOtherMouseDown:
    {
        int btn = static_cast<int>(CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber));
        uint8_t key = (btn == 2) ? CDCKeyMButton : (btn == 3) ? CDCKeyXButton1 : (btn == 4) ? CDCKeyXButton2 : 0;
        if (key) inputCaptureBridgeMsButton(cdc, key, 1);
        break;
    }
    case kCGEventOtherMouseUp:
    {
        int btn = static_cast<int>(CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber));
        uint8_t key = (btn == 2) ? CDCKeyMButton : (btn == 3) ? CDCKeyXButton1 : (btn == 4) ? CDCKeyXButton2 : 0;
        if (key) inputCaptureBridgeMsButton(cdc, key, 0);
        break;
    }
    case kCGEventMouseMoved:
    case kCGEventLeftMouseDragged:
    case kCGEventRightMouseDragged:
    case kCGEventOtherMouseDragged:
    {
        int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
        int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
        inputCaptureBridgeMsMove(cdc, static_cast<int16_t>(dx), static_cast<int16_t>(dy));
        break;
    }
    case kCGEventScrollWheel:
    {
        int64_t dy = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
        int64_t dx = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
        if (dy != 0) inputCaptureBridgeMsWheel(cdc, static_cast<int16_t>(dy));
        if (dx != 0) inputCaptureBridgeMsHWheel(cdc, static_cast<int16_t>(dx));
        break;
    }
    default:
        break;
    }

    return event;
}

// ===========================================================================
// install / remove — 由 input_capture.cpp 调用
// ===========================================================================

static CFMachPortRef g_kbTap = nullptr;
static CFRunLoopSourceRef g_kbRunLoopSource = nullptr;
static CFMachPortRef g_msTap = nullptr;
static CFRunLoopSourceRef g_msRunLoopSource = nullptr;

void inputCaptureInstallKbMonitor(InputCapture * /*self*/)
{
    if (g_kbTap) return;

    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
    g_kbTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionListenOnly, mask,
                                kbEventTapCallback, nullptr);
    if (!g_kbTap)
    {
        NSLog(@"[InputCapture] keyboard event tap failed — check Accessibility permissions.");
        return;
    }
    g_kbRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, g_kbTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), g_kbRunLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(g_kbTap, true);
}

void inputCaptureRemoveKbMonitor(InputCapture * /*self*/)
{
    if (!g_kbTap) return;
    CGEventTapEnable(g_kbTap, false);
    if (g_kbRunLoopSource)
    {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), g_kbRunLoopSource, kCFRunLoopCommonModes);
        CFRelease(g_kbRunLoopSource);
        g_kbRunLoopSource = nullptr;
    }
    CFRelease(g_kbTap);
    g_kbTap = nullptr;
}

void inputCaptureInstallMsMonitor(InputCapture * /*self*/)
{
    if (g_msTap) return;

    CGEventMask mask =
        CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp) |
        CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp) |
        CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp) |
        CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) |
        CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventOtherMouseDragged) |
        CGEventMaskBit(kCGEventScrollWheel);

    g_msTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionListenOnly, mask,
                                msEventTapCallback, nullptr);
    if (!g_msTap)
    {
        NSLog(@"[InputCapture] mouse event tap failed — check Accessibility permissions.");
        return;
    }
    g_msRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, g_msTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), g_msRunLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(g_msTap, true);
}

void inputCaptureRemoveMsMonitor(InputCapture * /*self*/)
{
    if (!g_msTap) return;
    CGEventTapEnable(g_msTap, false);
    if (g_msRunLoopSource)
    {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), g_msRunLoopSource, kCFRunLoopCommonModes);
        CFRelease(g_msRunLoopSource);
        g_msRunLoopSource = nullptr;
    }
    CFRelease(g_msTap);
    g_msTap = nullptr;
}

#endif // Q_OS_MACOS