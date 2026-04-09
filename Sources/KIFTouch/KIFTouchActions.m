// High-level touch synthesis — consolidated from KIF's UIView-KIFAdditions
// and UIApplication-KIFAdditions.

#import "KIFTouchActions.h"
#import "UITouch-KIFAdditions.h"
#import "UIEvent+KIFAdditions.h"
#import <objc/message.h>

#define DRAG_TOUCH_DELAY 0.01

@interface UIApplication (KIFTouchPrivate)
- (UIEvent *)_touchesEvent;
@end

@implementation KIFTouchActions

#pragma mark - Event Construction

+ (UIEvent *)eventWithTouches:(NSArray<UITouch *> *)touches
{
    UIEvent *event = [[UIApplication sharedApplication] _touchesEvent];
    [event _clearTouches];
    [event kif_setEventWithTouches:touches];
    for (UITouch *aTouch in touches) {
        [event _addTouch:aTouch forDelayedDelivery:NO];
    }
    return event;
}

+ (UIEvent *)eventWithTouch:(UITouch *)touch
{
    return [self eventWithTouches:touch ? @[touch] : @[]];
}

+ (void)sendEvent:(UIEvent *)event
{
    [[UIApplication sharedApplication] sendEvent:event];
}

#pragma mark - Tap

+ (void)tapAtPoint:(CGPoint)point inWindow:(UIWindow *)window
{
    NSLog(@"[KIFTouch] tapAtPoint: (%.1f, %.1f)", point.x, point.y);

    // Find the deepest interactive subview at this point using recursive hit testing.
    // Standard [window hitTest:] may return a scroll view container rather than its content.
    UIView *deepView = [self deepestInteractiveViewAtPoint:point inView:window];
    NSLog(@"[KIFTouch] deepestView = %@ (%@)", deepView, NSStringFromClass([deepView class]));

    // Create touch on the deepest view
    CGPoint viewPoint = [deepView convertPoint:point fromView:window];
    UITouch *touch = [[UITouch alloc] initAtPoint:viewPoint inView:deepView];
    NSLog(@"[KIFTouch] touch.view = %@ (%@)", touch.view, NSStringFromClass([touch.view class]));

    [touch setPhaseAndUpdateTimestamp:UITouchPhaseBegan];
    UIEvent *event = [self eventWithTouch:touch];
    [self sendEvent:event];

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, DRAG_TOUCH_DELAY, false);

    [touch setPhaseAndUpdateTimestamp:UITouchPhaseEnded];
    UIEvent *endedEvent = [self eventWithTouch:touch];
    [self sendEvent:endedEvent];

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, DRAG_TOUCH_DELAY, false);
}

/// Recursively find the deepest subview containing the point that either:
/// - has gesture recognizers, or
/// - is the leaf view
/// This bypasses UIScrollView's hitTest which returns self instead of cell content.
+ (UIView *)deepestInteractiveViewAtPoint:(CGPoint)windowPoint inView:(UIView *)view
{
    CGPoint localPoint = [view convertPoint:windowPoint fromView:view.window ?: view];
    if (![view pointInside:localPoint withEvent:nil]) {
        return nil;
    }

    // Search subviews in reverse (front to back)
    for (UIView *subview in [view.subviews reverseObjectEnumerator]) {
        if (subview.hidden || subview.alpha < 0.01 || !subview.userInteractionEnabled) {
            continue;
        }
        UIView *found = [self deepestInteractiveViewAtPoint:windowPoint inView:subview];
        if (found) {
            return found;
        }
    }

    return view;
}

#pragma mark - Long Press

+ (void)longPressAtPoint:(CGPoint)point duration:(NSTimeInterval)duration inWindow:(UIWindow *)window
{
    UITouch *touch = [[UITouch alloc] initAtPoint:point inWindow:window];
    [touch setPhaseAndUpdateTimestamp:UITouchPhaseBegan];

    UIEvent *eventDown = [self eventWithTouch:touch];
    [self sendEvent:eventDown];

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, DRAG_TOUCH_DELAY, false);

    for (NSTimeInterval timeSpent = DRAG_TOUCH_DELAY; timeSpent < duration; timeSpent += DRAG_TOUCH_DELAY) {
        [touch setPhaseAndUpdateTimestamp:UITouchPhaseStationary];
        UIEvent *eventStillDown = [self eventWithTouch:touch];
        [self sendEvent:eventStillDown];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, DRAG_TOUCH_DELAY, false);
    }

    [touch setPhaseAndUpdateTimestamp:UITouchPhaseEnded];
    UIEvent *eventUp = [self eventWithTouch:touch];
    [self sendEvent:eventUp];
}

#pragma mark - Swipe / Drag

+ (void)swipeFromPoint:(CGPoint)start toPoint:(CGPoint)end duration:(NSTimeInterval)duration inWindow:(UIWindow *)window
{
    NSUInteger stepCount = MAX((NSUInteger)(duration / DRAG_TOUCH_DELAY), 3);

    // Build path in window coordinates
    NSMutableArray<NSValue *> *path = [NSMutableArray arrayWithCapacity:stepCount];
    for (NSUInteger i = 0; i < stepCount; i++) {
        CGFloat progress = (CGFloat)i / (stepCount - 1);
        CGPoint p = CGPointMake(start.x + progress * (end.x - start.x),
                                start.y + progress * (end.y - start.y));
        [path addObject:[NSValue valueWithCGPoint:p]];
    }

    // First point — touch began
    CGPoint firstPoint = [path[0] CGPointValue];
    UITouch *touch = [[UITouch alloc] initAtPoint:firstPoint inWindow:window];
    [touch setPhaseAndUpdateTimestamp:UITouchPhaseBegan];

    UIEvent *eventDown = [self eventWithTouch:touch];
    [self sendEvent:eventDown];
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, DRAG_TOUCH_DELAY, false);

    // Intermediate points — touch moved
    for (NSUInteger i = 1; i < stepCount; i++) {
        CGPoint windowPoint = [path[i] CGPointValue];
        [touch setLocationInWindow:windowPoint];
        [touch setPhaseAndUpdateTimestamp:UITouchPhaseMoved];

        UIEvent *event = [self eventWithTouch:touch];
        [self sendEvent:event];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, DRAG_TOUCH_DELAY, false);
    }

    // Touch ended
    [touch setPhaseAndUpdateTimestamp:UITouchPhaseEnded];
    UIEvent *eventUp = [self eventWithTouch:touch];
    [self sendEvent:eventUp];
}

@end
