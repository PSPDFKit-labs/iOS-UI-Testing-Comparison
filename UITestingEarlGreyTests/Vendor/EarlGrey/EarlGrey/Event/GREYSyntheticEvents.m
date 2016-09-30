//
// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "Event/GREYSyntheticEvents.h"

#import "Additions/NSString+GREYAdditions.h"
#import "Assertion/GREYAssertionDefines.h"
#import "Common/GREYConstants.h"
#import "Common/GREYExposed.h"
#import "Event/GREYTouchInjector.h"
#import "Synchronization/GREYUIThreadExecutor.h"

#pragma mark - Extern

NSString *const kGREYSyntheticEventInjectionErrorDomain =
    @"com.google.earlgrey.SyntheticEventInjectionErrorDomain";

#pragma mark - Implementation

@implementation GREYSyntheticEvents {
  /**
   *  The touch injector that completes the touch sequence for an event.
   */
  GREYTouchInjector *_touchInjector;
}

+ (BOOL)rotateDeviceToOrientation:(UIDeviceOrientation)deviceOrientation
                       errorOrNil:(__strong NSError **)errorOrNil {
  I_CHECK_MAIN_THREAD();

  NSError *error;
  UIDeviceOrientation initialDeviceOrientation = [[UIDevice currentDevice] orientation];
  BOOL success = [[GREYUIThreadExecutor sharedInstance] executeSyncWithTimeout:10.0 block:^{
    [[UIDevice currentDevice] setOrientation:deviceOrientation animated:YES];
  } error:&error];

  if (!success) {
    if (errorOrNil) {
      *errorOrNil = error;
    } else {
      I_GREYFail(@"Failed to change device orientation due to error: %@", error);
    }
  } else if (deviceOrientation != [[UIDevice currentDevice] orientation]) {
    NSString *errorDescription =
        [NSString stringWithFormat:@"Device orientation could not be set to %@ from %@.",
            NSStringFromUIDeviceOrientation(deviceOrientation),
            NSStringFromUIDeviceOrientation(initialDeviceOrientation)];

    if (errorOrNil) {
      NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : errorDescription };
      *errorOrNil = [NSError errorWithDomain:kGREYSyntheticEventInjectionErrorDomain
                                        code:kGREYOrientationChangeFailedErrorCode
                                    userInfo:userInfo];
      return NO;
    } else {
      I_GREYFail(@"Device orientation could not be set to %@ from %@.",
                 NSStringFromUIDeviceOrientation(deviceOrientation),
                 NSStringFromUIDeviceOrientation(initialDeviceOrientation));
    }
  }

  return success;
}

+ (void)touchAlongPath:(NSArray *)touchPath
      relativeToWindow:(UIWindow *)window
           forDuration:(NSTimeInterval)duration
            expendable:(BOOL)expendable {
  [self touchAlongMultiplePaths:@[touchPath]
               relativeToWindow:window
                    forDuration:duration
                     expendable:expendable];
}

+ (void)touchAlongMultiplePaths:(NSArray *)touchPaths
               relativeToWindow:(UIWindow *)window
                    forDuration:(NSTimeInterval)duration
                     expendable:(BOOL)expendable {
  NSParameterAssert(touchPaths.count >= 1);
  NSParameterAssert(duration >= 0);

  NSUInteger firstTouchPathSize = [touchPaths[0] count];
  GREYSyntheticEvents *eventGenerator = [[GREYSyntheticEvents alloc] init];

  // Inject "begin" event for the first points of each path.
  [eventGenerator grey_beginTouchesAtPoints:[self grey_objectsAtIndex:0 ofArrays:touchPaths]
                           relativeToWindow:window
                          immediateDelivery:NO];

  // If the paths have a single point, then just inject an "end" event with the delay being the
  // provided duration. Otherwise, insert multiple "continue" events with delays being a fraction
  // of the duration, then inject an "end" event with no delay.
  if (firstTouchPathSize == 1) {
    [eventGenerator grey_endTouchesAtPoints:[self grey_objectsAtIndex:firstTouchPathSize - 1
                                                             ofArrays:touchPaths]
          timeElapsedSinceLastTouchDelivery:duration];
  } else {
    // Start injecting "continue touch" events, starting from the second position on the touch
    // path as it was already injected as a "begin touch" event.
    CFTimeInterval delayBetweenEachEvent = duration / (double)(firstTouchPathSize - 1);

    for (NSUInteger i = 1; i < firstTouchPathSize; i++) {
      [eventGenerator grey_continueTouchAtPoints:[self grey_objectsAtIndex:i ofArrays:touchPaths]
          afterTimeElapsedSinceLastTouchDelivery:delayBetweenEachEvent
                               immediateDelivery:NO
                                      expendable:expendable];
    }

    [eventGenerator grey_endTouchesAtPoints:[self grey_objectsAtIndex:firstTouchPathSize - 1
                                                             ofArrays:touchPaths]
          timeElapsedSinceLastTouchDelivery:0];
  }
}

- (void)beginTouchAtPoint:(CGPoint)point
         relativeToWindow:(UIWindow *)window
        immediateDelivery:(BOOL)immediate {
  [self grey_beginTouchesAtPoints:@[[NSValue valueWithCGPoint:point]]
                 relativeToWindow:window
                immediateDelivery:immediate];
}

- (void)continueTouchAtPoint:(CGPoint)point
           immediateDelivery:(BOOL)immediate
                  expendable:(BOOL)expendable {
  [self grey_continueTouchAtPoints:@[[NSValue valueWithCGPoint:point]]
      afterTimeElapsedSinceLastTouchDelivery:0
                           immediateDelivery:immediate
                                  expendable:expendable];
}

- (void)endTouch {
  [self grey_endTouchesAtPoints:@[[NSValue valueWithCGPoint:CGPointZero]]
      timeElapsedSinceLastTouchDelivery:0];
}

#pragma mark - Private

// Given an array containing multiple arrays, returns an array with the index'th element of each
// array.
+ (NSArray *)grey_objectsAtIndex:(NSUInteger)index ofArrays:(NSArray *)arrayOfArrays {
  NSAssert([arrayOfArrays count] > 0, @"arrayOfArrays must contain at least one element.");

  GREY_UNUSED_VARIABLE NSUInteger firstArraySize = [arrayOfArrays[0] count];

  NSAssert(index < firstArraySize, @"index must be smaller than the size of the arrays.");

  NSMutableArray *output = [[NSMutableArray alloc] initWithCapacity:[arrayOfArrays count]];
  for (NSArray *array in arrayOfArrays) {
    NSAssert([array count] == firstArraySize, @"All arrays must be of the same size.");
    [output addObject:array[index]];
  }

  return output;
}

/**
 *  Begins interaction with new touches starting at multiple @c points. Touch will be delivered to
 *  the hit test view in @c window under point and will not end until @c endTouch is called.
 *
 *  @param points    Multiple points where touches should start.
 *  @param window    The window that contains the coordinates of the touch points.
 *  @param immediate If @c YES, this method blocks until touch is delivered, otherwise the touch is
 *                   enqueued for delivery the next time runloop drains.
 */
- (void)grey_beginTouchesAtPoints:(NSArray *)points
                 relativeToWindow:(UIWindow *)window
                immediateDelivery:(BOOL)immediate {
  NSAssert(!_touchInjector, @"Cannot call this method more than once until endTouch is called.");
  _touchInjector = [[GREYTouchInjector alloc] initWithWindow:window];
  GREYTouchInfo *touchInfo = [[GREYTouchInfo alloc] initWithPoints:points
                                                         lastTouch:NO
                                   deliveryTimeDeltaSinceLastTouch:0
                                                        expendable:NO];
  [_touchInjector enqueueTouchInfoForDelivery:touchInfo];
  if (immediate) {
    [_touchInjector waitUntilAllTouchesAreDeliveredUsingInjector];
  }
}

/**
 *  Enqueues the next touch to be delivered.
 *
 *  @param points     Multiple points at which the touches are to be made.
 *  @param seconds    An interval to wait after the every last touch event.
 *  @param immediate  if @c YES, this method blocks until touches are delivered, otherwise it is
 *                    enqueued for delivery the next time runloop drains.
 *  @param expendable Indicates that this touch point is intended to be delivered in a timely
 *                    manner rather than reliably.
 */
- (void)grey_continueTouchAtPoints:(NSArray *)points
    afterTimeElapsedSinceLastTouchDelivery:(NSTimeInterval)seconds
                         immediateDelivery:(BOOL)immediate
                                expendable:(BOOL)expendable {
  GREYTouchInfo *touchInfo = [[GREYTouchInfo alloc] initWithPoints:points
                                                         lastTouch:NO
                                   deliveryTimeDeltaSinceLastTouch:seconds
                                                        expendable:expendable];
  [_touchInjector enqueueTouchInfoForDelivery:touchInfo];

  if (immediate) {
    [_touchInjector waitUntilAllTouchesAreDeliveredUsingInjector];
  }
}

- (void)grey_endTouchesAtPoints:(NSArray *)points
    timeElapsedSinceLastTouchDelivery:(NSTimeInterval)seconds {
  GREYTouchInfo *touchInfo = [[GREYTouchInfo alloc] initWithPoints:points
                                                         lastTouch:YES
                                   deliveryTimeDeltaSinceLastTouch:seconds
                                                        expendable:NO];

  [_touchInjector enqueueTouchInfoForDelivery:touchInfo];
  [_touchInjector waitUntilAllTouchesAreDeliveredUsingInjector];

  _touchInjector = nil;
}

@end
