// ---------------------------------------------------------------------------
// input_capture_mac.mm — macOS CGEventTap 系统级全局键盘/鼠标监听
// 需要辅助功能权限 (System Preferences → Privacy → Accessibility)
//
// 重要: CGEventTap 的 CFRunLoopSource 必须添加到一个持续运行的 RunLoop 中。
// Qt 的主线程 RunLoop 不能可靠地 pump CGEventTap 事件，因此我们使用专用线程
// 来运行 CFRunLoop，确保回调能正常触发。
// ---------------------------------------------------------------------------
#include "input_capture.h"

#ifdef Q_OS_MACOS

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ApplicationServices/ApplicationServices.h>
#import <IOKit/hidsystem/IOHIDLib.h>

#include <pthread.h>
#include <atomic>

// ---- 获取当前活跃的 InputCapture 实例 ----
extern "C" InputCapture * inputCaptureGetActive();
static InputCapture * getActiveCapture()
{
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
        NSLog(@"[InputCapture] kb callback: type=%d keyCode=%d cdcKey=%d", (int)type, (int)keyCode, (int)cdcKey);
        if (cdcKey != 0)
        {
            uint8_t state = (type == kCGEventKeyDown) ? 1 : 0;
            cap->sendKbKey(cdcKey, state);
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

    switch (type)
    {
    case kCGEventLeftMouseDown:
        cap->sendMsButton(CDCKeyLButton, 1); break;
    case kCGEventLeftMouseUp:
        cap->sendMsButton(CDCKeyLButton, 0); break;
    case kCGEventRightMouseDown:
        cap->sendMsButton(CDCKeyRButton, 1); break;
    case kCGEventRightMouseUp:
        cap->sendMsButton(CDCKeyRButton, 0); break;
    case kCGEventOtherMouseDown:
    {
        int btn = static_cast<int>(CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber));
        uint8_t key = (btn == 2) ? CDCKeyMButton : (btn == 3) ? CDCKeyXButton1 : (btn == 4) ? CDCKeyXButton2 : 0;
        if (key) cap->sendMsButton(key, 1);
        break;
    }
    case kCGEventOtherMouseUp:
    {
        int btn = static_cast<int>(CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber));
        uint8_t key = (btn == 2) ? CDCKeyMButton : (btn == 3) ? CDCKeyXButton1 : (btn == 4) ? CDCKeyXButton2 : 0;
        if (key) cap->sendMsButton(key, 0);
        break;
    }
    case kCGEventMouseMoved:
    case kCGEventLeftMouseDragged:
    case kCGEventRightMouseDragged:
    case kCGEventOtherMouseDragged:
    {
        int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
        int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
        cap->sendMsMove(static_cast<int16_t>(dx), static_cast<int16_t>(dy));
        break;
    }
    case kCGEventScrollWheel:
    {
        int64_t dy = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
        int64_t dx = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
        if (dy != 0) cap->sendMsWheel(static_cast<int16_t>(dy));
        if (dx != 0) cap->sendMsHWheel(static_cast<int16_t>(dx));
        break;
    }
    default:
        break;
    }

    return event;
}

// ===========================================================================
// Accessibility 权限检查 — CGEventTapCreate 返回 NULL 的最常见原因
// ===========================================================================

static bool checkAccessibilityPermission()
{
    // AXIsProcessTrustedWithOptions 在 macOS 10.9+ 可用
    // 传入 kAXTrustedCheckOptionPrompt => true 会在未授权时弹出系统授权对话框
    NSDictionary * options = @{
        (__bridge NSString *)kAXTrustedCheckOptionPrompt : @YES
    };
    Boolean trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    NSLog(@"[InputCapture] AXIsProcessTrustedWithOptions returned: %d", (int)trusted);
    if (!trusted)
    {
        NSLog(@"[InputCapture] Accessibility permission NOT granted. "
              @"Opening System Settings → Privacy & Security → Accessibility...");

        // 直接打开系统设置的辅助功能页面，方便用户添加授权
        NSString * settingsURL = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:settingsURL]];

        // 弹出 NSAlert 提示用户需要手动授权
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert * alert = [[NSAlert alloc] init];
            alert.messageText = @"需要辅助功能权限";
            alert.informativeText = @"CDC Sample 需要辅助功能权限才能捕获全局键盘和鼠标事件。\n\n"
                                     @"请在「系统设置 → 隐私与安全性 → 辅助功能」中添加并勾选 CDC Sample，"
                                     @"然后重新启动输入捕获。";
            alert.alertStyle = NSAlertStyleWarning;
            [alert addButtonWithTitle:@"确定"];
            [alert runModal];
        });
    }
    return trusted == YES;
}

// ===========================================================================
// Input Monitoring 权限检查 (macOS 10.15+)
//
// 关键: macOS 将权限拆分为两个独立的 TCC 权限：
//   - Accessibility（辅助功能）→ 控制鼠标事件监听、UI 控制
//   - Input Monitoring（输入监控）→ 控制键盘事件监听 (kCGEventKeyDown/Up)
//
// 鼠标 EventTap 只需要 Accessibility 权限，但键盘 EventTap 还需要
// Input Monitoring 权限。这就是"鼠标可以、键盘不行"的根因。
// ===========================================================================

static bool checkInputMonitoringPermission()
{
    // IOHIDCheckAccess 在 macOS 10.15 (Catalina) 引入
    // kIOHIDRequestTypeListenEvent 对应"输入监控"权限
    // 返回值: kIOHIDAccessTypeGranted=0, kIOHIDAccessTypeDenied=1,
    //         kIOHIDAccessTypeUnknown=2
    IOHIDAccessType accessType = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent);
    NSLog(@"[InputCapture] IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) returned: %d", (int)accessType);

    if (accessType != kIOHIDAccessTypeGranted)
    {
        NSLog(@"[InputCapture] Input Monitoring permission NOT granted. "
              @"Opening System Settings → Privacy & Security → Input Monitoring...");

        // 请求权限 — IOHIDRequestAccess 会弹出系统授权对话框
        // 注意: 此函数只能调用一次，重复调用不会再次弹窗
        bool granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent);
        NSLog(@"[InputCapture] IOHIDRequestAccess returned: %d", (int)granted);

        if (!granted)
        {
            // 直接打开系统设置的"输入监控"页面
            // Privacy_ListenEvent 对应"输入监控"（键盘监听）
            NSString * settingsURL = @"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent";
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:settingsURL]];

            // 弹出 NSAlert 提示用户需要手动授权
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert * alert = [[NSAlert alloc] init];
                alert.messageText = @"需要输入监控权限";
                alert.informativeText = @"CDC Sample 需要输入监控权限才能捕获全局键盘事件。\n\n"
                                         @"请在「系统设置 → 隐私与安全性 → 输入监控」中添加并勾选 CDC Sample，"
                                         @"然后重新启动输入捕获。\n\n"
                                         @"注意：这与「辅助功能」是两个独立的权限，鼠标只需要辅助功能权限，"
                                         @"但键盘还需要输入监控权限。";
                alert.alertStyle = NSAlertStyleWarning;
                [alert addButtonWithTitle:@"确定"];
                [alert runModal];
            });
        }
        return granted;
    }
    return true;
}

// ===========================================================================
// 专用线程 EventTap 管理
//
// CGEventTap 的 CFRunLoopSource 必须添加到一个持续运行的 RunLoop 中。
// Qt 主线程的 RunLoop 不能可靠地 pump CGEventTap 事件，因此我们为 kb 和 ms
// 各创建一个专用 pthread，在线程内创建 EventTap + RunLoopSource 并 CFRunLoopRun()。
// remove 时通过 CFRunLoopStop() 停止对应线程的 RunLoop。
// ===========================================================================

struct EventTapContext
{
    CGEventMask        mask;
    CGEventTapCallBack callback;
    CFMachPortRef      tap            = nullptr;
    CFRunLoopSourceRef runLoopSource  = nullptr;
    CFRunLoopRef       runLoop        = nullptr;
    pthread_t          thread         = 0;
    std::atomic<bool>  running{false};
};

static EventTapContext g_kbCtx;
static EventTapContext g_msCtx;

static void * eventTapThreadFunc(void * arg)
{
    @autoreleasepool
    {
        auto * ctx = static_cast<EventTapContext *>(arg);

        // 获取当前线程的 RunLoop
        ctx->runLoop = CFRunLoopGetCurrent();

        // 在此线程内创建 CGEventTap
        ctx->tap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap,
                                     kCGEventTapOptionListenOnly, ctx->mask,
                                     ctx->callback, nullptr);
        if (!ctx->tap)
        {
            NSLog(@"[InputCapture] CGEventTapCreate returned NULL on background thread.");
            ctx->running = false;
            return nullptr;
        }

        ctx->runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, ctx->tap, 0);
        CFRunLoopAddSource(ctx->runLoop, ctx->runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(ctx->tap, true);

        NSLog(@"[InputCapture] event tap installed on background thread, entering CFRunLoopRun");

        // 进入 RunLoop — 会一直阻塞直到 CFRunLoopStop() 被调用
        CFRunLoopRun();

        NSLog(@"[InputCapture] CFRunLoopRun exited, cleaning up event tap");

        // 清理
        CGEventTapEnable(ctx->tap, false);
        CFRunLoopRemoveSource(ctx->runLoop, ctx->runLoopSource, kCFRunLoopCommonModes);
        CFRelease(ctx->runLoopSource);
        ctx->runLoopSource = nullptr;
        CFRelease(ctx->tap);
        ctx->tap = nullptr;
        ctx->runLoop = nullptr;
        ctx->running = false;

        return nullptr;
    }
}

// ===========================================================================
// install / remove — 由 input_capture.cpp 调用
// ===========================================================================

void inputCaptureInstallKbMonitor(InputCapture * /*self*/)
{
    if (g_kbCtx.running.load())
        return;

    // 先检查 Accessibility 权限，未授权则 CGEventTapCreate 必定返回 NULL
    if (!checkAccessibilityPermission())
        return;

    // 准备 context
    g_kbCtx.mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
    g_kbCtx.callback = kbEventTapCallback;
    g_kbCtx.running = true;

    // 创建专用线程运行 CGEventTap
    int ret = pthread_create(&g_kbCtx.thread, nullptr, eventTapThreadFunc, &g_kbCtx);
    if (ret != 0)
    {
        NSLog(@"[InputCapture] pthread_create for keyboard failed: %d", ret);
        g_kbCtx.running = false;
        return;
    }

    NSLog(@"[InputCapture] keyboard monitor thread started");
}

void inputCaptureRemoveKbMonitor(InputCapture * /*self*/)
{
    if (!g_kbCtx.running.load() && !g_kbCtx.tap)
        return;

    // 在主线程停止后台线程的 RunLoop
    if (g_kbCtx.runLoop)
    {
        CFRunLoopStop(g_kbCtx.runLoop);
    }

    // 等待线程退出
    if (g_kbCtx.thread)
    {
        pthread_join(g_kbCtx.thread, nullptr);
        g_kbCtx.thread = 0;
    }

    NSLog(@"[InputCapture] keyboard monitor thread stopped");
}

void inputCaptureInstallMsMonitor(InputCapture * /*self*/)
{
    if (g_msCtx.running.load())
        return;

    // 先检查 Accessibility 权限，未授权则 CGEventTapCreate 必定返回 NULL
    if (!checkAccessibilityPermission())
        return;

    // 准备 context
    g_msCtx.mask =
        CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp) |
        CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp) |
        CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp) |
        CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) |
        CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventOtherMouseDragged) |
        CGEventMaskBit(kCGEventScrollWheel);
    g_msCtx.callback = msEventTapCallback;
    g_msCtx.running = true;

    // 创建专用线程运行 CGEventTap
    int ret = pthread_create(&g_msCtx.thread, nullptr, eventTapThreadFunc, &g_msCtx);
    if (ret != 0)
    {
        NSLog(@"[InputCapture] pthread_create for mouse failed: %d", ret);
        g_msCtx.running = false;
        return;
    }

    NSLog(@"[InputCapture] mouse monitor thread started");
}

void inputCaptureRemoveMsMonitor(InputCapture * /*self*/)
{
    if (!g_msCtx.running.load() && !g_msCtx.tap)
        return;

    // 在主线程停止后台线程的 RunLoop
    if (g_msCtx.runLoop)
    {
        CFRunLoopStop(g_msCtx.runLoop);
    }

    // 等待线程退出
    if (g_msCtx.thread)
    {
        pthread_join(g_msCtx.thread, nullptr);
        g_msCtx.thread = 0;
    }

    NSLog(@"[InputCapture] mouse monitor thread stopped");
}

// ===========================================================================
// Gamepad — Apple Game Controller framework
// 监听 GCController 连接/断开通知，轮询 extendedGamepad 状态并通过
// CDCGpState / CDCGpCmd 上报
// ===========================================================================

#import <GameController/GameController.h>

static void (^g_gpConnectHandler)(NSNotification *) = nil;
static void (^g_gpDisconnectHandler)(NSNotification *) = nil;
static id g_gpConnectObserver = nil;
static id g_gpDisconnectObserver = nil;
static GCController * g_gpController = nil;
static bool g_gpRunning = false;

// 将 GCController 的物理按钮映射到 CDCGamepadButtonType
static int32_t mapGCExtendedGamepadButtons(GCExtendedGamepad * gp)
{
    int32_t buttons = 0;

    if (gp.dpad.up.isPressed)    buttons |= CDCGamepadButtonDpadUp;
    if (gp.dpad.down.isPressed)  buttons |= CDCGamepadButtonDpadDown;
    if (gp.dpad.left.isPressed)  buttons |= CDCGamepadButtonDpadLeft;
    if (gp.dpad.right.isPressed) buttons |= CDCGamepadButtonDpadRight;

    if (gp.buttonA.isPressed)     buttons |= CDCGamepadButtonA;
    if (gp.buttonB.isPressed)     buttons |= CDCGamepadButtonB;
    if (gp.buttonX.isPressed)     buttons |= CDCGamepadButtonX;
    if (gp.buttonY.isPressed)     buttons |= CDCGamepadButtonY;

    if (gp.leftShoulder.isPressed)  buttons |= CDCGamepadButtonLeftShoulder;
    if (gp.rightShoulder.isPressed) buttons |= CDCGamepadButtonRightShoulder;

    if (gp.leftThumbstickButton != nil && gp.leftThumbstickButton.isPressed)
        buttons |= CDCGamepadButtonLeftThumb;
    if (gp.rightThumbstickButton != nil && gp.rightThumbstickButton.isPressed)
        buttons |= CDCGamepadButtonRightThumb;

    if (gp.buttonMenu != nil && gp.buttonMenu.isPressed)
        buttons |= CDCGamepadButtonStart;

    if (gp.buttonOptions != nil && gp.buttonOptions.isPressed)
        buttons |= CDCGamepadButtonBack;

    return buttons;
}

static void sendGpStateFromController(GCController * controller)
{
    InputCapture * cap = getActiveCapture();
    if (!cap || !cap->isGpEnabled())
        return;

    GCExtendedGamepad * gp = controller.extendedGamepad;
    if (!gp)
        return;

    CDCGpState state;
    state.index   = static_cast<uint8_t>(controller.playerIndex);
    state.buttons = mapGCExtendedGamepadButtons(gp);

    // 扳机: 0.0 ~ 1.0 → 0 ~ 255
    state.lt = static_cast<uint8_t>(gp.leftTrigger.value * 255.0f);
    state.rt = static_cast<uint8_t>(gp.rightTrigger.value * 255.0f);

    // 摇杆: -1.0 ~ 1.0 → INT16_MIN ~ INT16_MAX
    auto mapAxis = [](float v) -> int16_t {
        if (v < -1.0f) v = -1.0f;
        if (v >  1.0f) v =  1.0f;
        return static_cast<int16_t>(v * 32767.0f);
    };

    state.lx = mapAxis(gp.leftThumbstick.xAxis.value);
    state.ly = mapAxis(gp.leftThumbstick.yAxis.value);
    state.rx = mapAxis(gp.rightThumbstick.xAxis.value);
    state.ry = mapAxis(gp.rightThumbstick.yAxis.value);

    cap->sendGpState(state);
}

void inputCaptureInstallGpMonitor(InputCapture * /*self*/)
{
    if (g_gpRunning)
        return;

    // 注册连接通知
    g_gpConnectHandler = ^(NSNotification * note) {
        GCController * controller = note.object;
        if (!controller || controller.extendedGamepad == nil)
            return;

        g_gpController = controller;

        // 发送插入命令
        CDCGpCmd cmd;
        cmd.index = static_cast<uint8_t>(controller.playerIndex);
        cmd.state = 0; // 插入
        InputCapture * cap = getActiveCapture();
        if (cap && cap->isGpEnabled())
            cap->sendGpCmd(cmd);

        NSLog(@"[InputCapture] gamepad connected: %@ playerIndex=%ld",
              controller.vendorName, (long)controller.playerIndex);

        // 设置值变化回调 — 每次手柄状态变化时上报
        controller.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad * /*gp*/,
                                                            GCControllerElement * /*element*/) {
            sendGpStateFromController(controller);
        };
    };

    g_gpDisconnectHandler = ^(NSNotification * note) {
        GCController * controller = note.object;
        if (!controller)
            return;

        // 发送拔出命令
        CDCGpCmd cmd;
        cmd.index = static_cast<uint8_t>(controller.playerIndex);
        cmd.state = 1; // 拔出
        InputCapture * cap = getActiveCapture();
        if (cap && cap->isGpEnabled())
            cap->sendGpCmd(cmd);

        NSLog(@"[InputCapture] gamepad disconnected: %@ playerIndex=%ld",
              controller.vendorName, (long)controller.playerIndex);

        if (g_gpController == controller)
            g_gpController = nil;
    };

    g_gpConnectObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GCControllerDidConnectNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:g_gpConnectHandler];

    g_gpDisconnectObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:GCControllerDidDisconnectNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:g_gpDisconnectHandler];

    g_gpRunning = true;

    // 启动手柄发现 — GCController 默认会检测已连接的手柄
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
        NSLog(@"[InputCapture] wireless controller discovery completed");
    }];

    // 检查当前是否已有连接的手柄
    NSArray<GCController *> * controllers = [GCController controllers];
    if (controllers.count > 0)
    {
        for (GCController * c in controllers)
        {
            if (c.extendedGamepad != nil)
            {
                g_gpController = c;
                g_gpConnectHandler([NSNotification notificationWithName:GCControllerDidConnectNotification
                                                                  object:c]);
                break;
            }
        }
    }

    NSLog(@"[InputCapture] gamepad monitor installed");
}

void inputCaptureRemoveGpMonitor(InputCapture * /*self*/)
{
    if (!g_gpRunning)
        return;

    if (g_gpDisconnectObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:g_gpDisconnectObserver];
        g_gpDisconnectObserver = nil;
    }
    if (g_gpConnectObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:g_gpConnectObserver];
        g_gpConnectObserver = nil;
    }

    g_gpConnectHandler = nil;
    g_gpDisconnectHandler = nil;
    g_gpController = nil;
    g_gpRunning = false;

    NSLog(@"[InputCapture] gamepad monitor removed");
}

#endif // Q_OS_MACOS
