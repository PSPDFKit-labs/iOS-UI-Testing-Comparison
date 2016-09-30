//
//  PSPDFTestAdditions.m
//  UITestingComparison
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

#import <Foundation/Foundation.h>
#import "PSPDFTestAdditions.h"

BOOL PSPDFWaitForConditionWithTimeout(NSTimeInterval timeout, PSPDFTestCondition condition) {
    // Based on http://bou.io/CTTRunLoopRunUntil.html
    __block Boolean fulfilled = NO;
    const auto beforeWaiting = ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        // The run loop should be stopped after the condition is fulfilled (CFRunLoopStop below)
        NSCParameterAssert(!fulfilled);
        // Check the condition
        fulfilled = condition();
        // Condition fulfilled: stop RunLoop now
        if (fulfilled) CFRunLoopStop(CFRunLoopGetCurrent());
    };

    // We add a timer dispatch source here to make sure that we wake up at least every 0.x seconds
    // in case we're waiting for a condition that does not necessarily wake up the run loop.
    const dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, PSPDF_DEPRECATED_NOWARN(dispatch_get_current_queue()));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, (uint64_t)(0.05 * NSEC_PER_SEC), (uint64_t)(0.05 * NSEC_PER_SEC));
    dispatch_source_set_event_handler(timer, ^{
        // NOOP
    });
    dispatch_resume(timer);

    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, 0, beforeWaiting);
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, false);
    CFRunLoopRemoveObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    CFRelease(observer);

    dispatch_source_cancel(timer);

    // If we haven't fulfilled the condition yet, test one more time before returning. This avoids
    // that we fail the test just because we somehow failed to properly poll the condition, e.g. if
    // the run loop didn't wake up.
    if (!fulfilled) {
        fulfilled = condition();
    }

    return fulfilled;
}
