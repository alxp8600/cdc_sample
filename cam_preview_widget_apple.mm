// cam_preview_widget_apple.mm
// Apple (macOS / iOS) 专用: 内嵌 CAMetalLayer 的 Qt Widget
// macOS: 通过原生 NSView + CAMetalLayer 实现
// iOS: 通过原生 UIView + CAMetalLayer 实现
// 供 CDC SDK MetalVideoRender 输出摄像头预览

#include "cam_preview_widget.h"

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

// =============================================================================
// 平台原生 View（CAMetalLayer-backed）
// =============================================================================

#if TARGET_OS_IOS

@interface CamPreviewView : UIView
@end

@implementation CamPreviewView
+ (Class)layerClass
{
    return [CAMetalLayer class];
}
@end

#else

@interface CamPreviewNSView : NSView
@end

@implementation CamPreviewNSView
- (CALayer *)makeBackingLayer
{
    return [CAMetalLayer layer];
}
@end

#endif

// =============================================================================
// CamPreviewWidget 实现
// =============================================================================

CamPreviewWidget::CamPreviewWidget(QWidget * parent)
    : QWidget(parent)
{
    setAttribute(Qt::WA_NativeWindow, true);
    setAttribute(Qt::WA_DontCreateNativeAncestors, true);

#if TARGET_OS_IOS
    UIView * hostView = reinterpret_cast<UIView *>(winId());
    CamPreviewView * camView = [[CamPreviewView alloc] initWithFrame:CGRectZero];
    camView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [hostView addSubview:camView];
    view_ = (__bridge_retained void *)camView;
#else
    NSView * hostView = reinterpret_cast<NSView *>(winId());
    CamPreviewNSView * camView = [[CamPreviewNSView alloc] initWithFrame:NSZeroRect];
    camView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    camView.wantsLayer = YES;
    [hostView addSubview:camView];
    view_ = (__bridge_retained void *)camView;
#endif
}

CamPreviewWidget::~CamPreviewWidget()
{
    if (view_) {
#if TARGET_OS_IOS
        UIView * v = (__bridge_transfer UIView *)view_;
#else
        NSView * v = (__bridge_transfer NSView *)view_;
#endif
        [v removeFromSuperview];
        view_ = nullptr;
    }
}

void * CamPreviewWidget::metalLayer() const
{
    if (!view_) return nullptr;

#if TARGET_OS_IOS
    UIView * v = (__bridge UIView *)view_;
#else
    NSView * v = (__bridge NSView *)view_;
#endif
    return (__bridge void *)v.layer;
}

void CamPreviewWidget::resizeEvent(QResizeEvent * event)
{
    QWidget::resizeEvent(event);
    if (view_) {
#if TARGET_OS_IOS
        UIView * v = (__bridge UIView *)view_;
        v.frame = CGRectMake(0, 0, width(), height());
#else
        NSView * v = (__bridge NSView *)view_;
        v.frame = NSMakeRect(0, 0, width(), height());
#endif
    }
}