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

#import "Synchronization/GREYUIThreadExecutor.h"

#import "Additions/NSError+GREYAdditions.h"
#import "Additions/UIApplication+GREYAdditions.h"
#import "Additions/XCTestCase+GREYAdditions.h"
#import "AppSupport/GREYIdlingResource.h"
#import "Assertion/GREYAssertionDefines.h"
#import "Common/GREYConfiguration.h"
#import "Common/GREYConstants.h"
#import "Common/GREYDefines.h"
#import "Common/GREYPrivate.h"
#import "Synchronization/GREYAppStateTracker.h"
#import "Synchronization/GREYDispatchQueueIdlingResource.h"
#import "Synchronization/GREYOperationQueueIdlingResource.h"
#import "Synchronization/GREYRunLoopSpinner.h"

// Extern.
NSString *const kGREYUIThreadExecutorErrorDomain =
    @"com.google.earlgrey.GREYUIThreadExecutorErrorDomain";

/**
 *  The number of times idling resources are queried for idleness to be considered "really" idle.
 *  The value used here has worked in practice and has negligible impact on performance.
 */
static const int kConsecutiveTimesIdlingResourcesMustBeIdle = 3;

/**
 *  The default maximum time that the main thread is allowed to sleep while the thread executor is
 *  attempting to synchronize.
 */
static const CFTimeInterval kMaximumSynchronizationSleepInterval = 0.1;

/**
 *  The maximum amount of time to wait for the UI and idling resources to become idle in
 *  grey_forcedStateTrackerCleanUp before forcefully clearing the state of GREYAppStateTracker.
 */
static const CFTimeInterval kDrainTimeoutSecondsBeforeForcedStateTrackerCleanup = 5;

// Execution states.
typedef NS_ENUM(NSInteger, GREYExecutionState) {
  kGREYExecutionNotStarted = -1,
  kGREYExecutionWaitingForIdle,
  kGREYExecutionCompleted,
  kGREYExecutionTimeoutIdlingResourcesAreBusy,
  kGREYExecutionTimeoutAppIsBusy,
};

@interface GREYUIThreadExecutor ()

/**
 *  Property added for unit tests to keep the main thread awake while synchronizing.
 */
@property(nonatomic, assign) BOOL forceBusyPolling;

@end

@implementation GREYUIThreadExecutor {
  /**
   *  All idling resources that are registered with the framework using registerIdlingResource:.
   *  This list excludes the idling resources that are monitored by default and do not require
   *  registration.
   */
  NSMutableOrderedSet *_registeredIdlingResources;

  /**
   *  Idling resources that are monitored by default and cannot be deregistered.
   */
  NSOrderedSet *_defaultIdlingResources;
}

+ (instancetype)sharedInstance {
  static GREYUIThreadExecutor *instance = nil;
  static dispatch_once_t token = 0;
  dispatch_once(&token, ^{
    instance = [[GREYUIThreadExecutor alloc] initOnce];
  });
  return instance;
}

/**
 *  Initializes the thread executor. Not thread-safe. Must be invoked under a race-free synchronized
 *  environment by the caller.
 *
 *  @return The initialized instance.
 */
- (instancetype)initOnce {
  self = [super init];
  if (self) {
    _registeredIdlingResources = [[NSMutableOrderedSet alloc] init];

    // Create the default idling resources.
    id<GREYIdlingResource> defaultMainNSOperationQIdlingResource =
        [GREYOperationQueueIdlingResource resourceWithNSOperationQueue:[NSOperationQueue mainQueue]
                                                                  name:@"Main NSOperation Queue"];
    id<GREYIdlingResource> defaultMainDispatchQIdlingResource =
        [GREYDispatchQueueIdlingResource resourceWithDispatchQueue:dispatch_get_main_queue()
                                                              name:@"Main Dispatch Queue"];
    id<GREYIdlingResource> appStateTrackerIdlingResource = [GREYAppStateTracker sharedInstance];

    // The default resources' order is important as it affects the order in which the resources
    // will be checked.
    _defaultIdlingResources =
        [[NSOrderedSet alloc] initWithObjects:appStateTrackerIdlingResource,
                                              defaultMainDispatchQIdlingResource,
                                              defaultMainNSOperationQIdlingResource, nil];
    // Forcefully clear GREYAppStateTracker state during test case teardown if it is not idle.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(grey_forcedStateTrackerCleanUp)
                                                 name:kGREYXCTestCaseInstanceDidTearDown
                                               object:nil];
  }
  return self;
}

- (void)drainOnce {
  // Drain the active run loop once. Do not allow the run loop to sleep.
  GREYRunLoopSpinner *runLoopSpinner = [[GREYRunLoopSpinner alloc] init];

  // Spin the run loop with an always true stop condition. The spinner will only drain the run loop
  // for its minimum number of drains before checking this condition and returning.
  [runLoopSpinner spinWithStopConditionBlock:^BOOL {
    return YES;
  }];
}

- (void)drainForTime:(CFTimeInterval)seconds {
  NSParameterAssert(seconds >= 0);

  // Drain the active run loop for @c seconds. Allow the run loop to sleep.
  GREYRunLoopSpinner *runLoopSpinner = [[GREYRunLoopSpinner alloc] init];

  runLoopSpinner.timeout = seconds;
  runLoopSpinner.maxSleepInterval = DBL_MAX;
  runLoopSpinner.minRunLoopDrains = 0;

  // Spin the run loop with an always NO stop condition. The run loop spinner will only return after
  // it times out.
  [runLoopSpinner spinWithStopConditionBlock:^BOOL{
    return NO;
  }];
}

- (void)drainUntilIdle {
  [self executeSyncWithTimeout:kGREYInfiniteTimeout block:nil error:nil];
}

- (BOOL)drainUntilIdleWithTimeout:(CFTimeInterval)seconds {
  NSError *ignoreError;
  return [self executeSyncWithTimeout:seconds block:nil error:&ignoreError];
}

- (BOOL)executeSync:(GREYExecBlock)execBlock error:(__strong NSError **)error {
  return [self executeSyncWithTimeout:kGREYInfiniteTimeout block:execBlock error:error];
}

- (BOOL)executeSyncWithTimeout:(CFTimeInterval)seconds
                         block:(GREYExecBlock)execBlock
                         error:(__strong NSError **)error {
  I_CHECK_MAIN_THREAD();
  NSParameterAssert(seconds >= 0);

  BOOL isSynchronizationEnabled = GREY_CONFIG_BOOL(kGREYConfigKeySynchronizationEnabled);
  GREYRunLoopSpinner *runLoopSpinner = [[GREYRunLoopSpinner alloc] init];
  // It is important that we execute @c execBlock in the active run loop mode, which is guaranteed
  // by the run loop spinner's condition met handler. We want actions and other events to execute
  // in the mode that they would without EarlGrey's run loop control.
  runLoopSpinner.conditionMetHandler = ^{
    @autoreleasepool {
      if (execBlock) {
        execBlock();
      }
    }
  };

  if (isSynchronizationEnabled) {
    runLoopSpinner.timeout = seconds;
    if (self.forceBusyPolling) {
      runLoopSpinner.maxSleepInterval = kMaximumSynchronizationSleepInterval;
    }

    // Spin the run loop until the all of the resources are idle or until @c seconds.
    BOOL syncSuccess = [runLoopSpinner spinWithStopConditionBlock:^BOOL {
      return [self grey_areAllResourcesIdle];
    }];

    if (!syncSuccess) {
      NSOrderedSet *busyResources = [self grey_busyResources];
      NSString *errorDescription;
      if ([busyResources count] > 0) {
        errorDescription = [self grey_errorDescriptionForBusyResources:busyResources];
      } else {
        errorDescription = @"Failed to synchronize, but all resources are idle after timeout.";
      }

      [NSError grey_logOrSetOutReferenceIfNonNil:error
                                      withDomain:kGREYUIThreadExecutorErrorDomain
                                            code:kGREYUIThreadExecutorTimeoutErrorCode
                                  andDescription:errorDescription];
    }
    return syncSuccess;
  } else {
    // Spin the run loop with an always true stop condition. The spinner will only drain the run
    // loop for its minimum number of drains before executing the conditionMetHandler in the active
    // mode and returning.
    [runLoopSpinner spinWithStopConditionBlock:^BOOL{
      return YES;
    }];

    return YES;
  }
}

/**
 *  Register the specified @c resource to be checked for idling before executing test actions.
 *  A strong reference is held to @c resource until it is deregistered using
 *  @c deregisterIdlingResource. It is safe to call this from any thread.
 *
 *  @param resource The idling resource to register.
 */
- (void)registerIdlingResource:(id<GREYIdlingResource>)resource {
  NSParameterAssert(resource);
  @synchronized(_registeredIdlingResources) {
    // Add the object at the beginning of the ordered set. Resource checking order is important for
    // stability and the default resources should be checked last.
    [_registeredIdlingResources insertObject:resource atIndex:0];
  }
}

/**
 *  Unregisters a previously registered @c resource. It is safe to call this from any thread.
 *
 *  @param resource The resource to unregistered.
 */
- (void)deregisterIdlingResource:(id<GREYIdlingResource>)resource {
  NSParameterAssert(resource);
  @synchronized(_registeredIdlingResources) {
    [_registeredIdlingResources removeObject:resource];
  }
}

#pragma mark - Internal Methods Exposed For Testing

/**
 *  @return @c YES when all idling resources are idle, @c NO otherwise.
 *
 *  @remark More efficient than calling grey_busyResources.
 */
- (BOOL)grey_areAllResourcesIdle {
  return [[self grey_busyResourcesReturnEarly:YES] count] == 0;
}

#pragma mark - Methods Only For Testing

/**
 *  Deregisters all non-default idling resources from the thread executor.
 */
- (void)grey_resetIdlingResources {
  @synchronized(_registeredIdlingResources) {
    _registeredIdlingResources = [[NSMutableOrderedSet alloc] init];
  }
}

/**
 *  @return @c YES if the thread executor is currently tracking @c idlingResource, @c NO otherwise.
 */
- (BOOL)grey_isTrackingIdlingResource:(id<GREYIdlingResource>)idlingResource {
  @synchronized (_registeredIdlingResources) {
    return [_registeredIdlingResources containsObject:idlingResource] ||
        [_defaultIdlingResources containsObject:idlingResource];
  }
}

#pragma mark - Private

/**
 *  @return An ordered set the registered and default idling resources that are currently busy.
 */
- (NSOrderedSet *)grey_busyResources {
  return [self grey_busyResourcesReturnEarly:NO];
}

/**
 *  @param returnEarly A boolean flag to determine if this method should return
 *                     immediately after finding one busy resource.
 *
 *  @return An ordered set the registered and default idling resources that are currently busy.
 */
- (NSOrderedSet *)grey_busyResourcesReturnEarly:(BOOL)returnEarly {
  @synchronized(_registeredIdlingResources) {
    NSMutableOrderedSet *busyResources = [[NSMutableOrderedSet alloc] init];
    // Loop over all of the idling resources three times. isIdleNow calls may trigger the state
    // of other idling resources.
    for (int i = 0; i < kConsecutiveTimesIdlingResourcesMustBeIdle; ++i) {
      // Registered resources are free to remove themselves or each-other when isIdleNow is
      // invoked. For that reason, iterate over a copy.
      for (id<GREYIdlingResource> resource in [_registeredIdlingResources copy]) {
        if (![resource isIdleNow]) {
          [busyResources addObject:resource];
          if (returnEarly) {
            return busyResources;
          }
        }
      }
      for (id<GREYIdlingResource> resource in _defaultIdlingResources) {
        if (![resource isIdleNow]) {
          [busyResources addObject:resource];
          if (returnEarly) {
            return busyResources;
          }
        }
      }
    }
    return busyResources;
  }
}

/**
 *  @return An error description string for all of the resources in @c busyResources.
 */
- (NSString *)grey_errorDescriptionForBusyResources:(NSOrderedSet *)busyResources {
  NSMutableArray *busyResourcesNames = [[NSMutableArray alloc] init];
  NSMutableArray *busyResourcesDescription = [[NSMutableArray alloc] init];

  for (id<GREYIdlingResource> resource in busyResources) {
    NSString *formattedResourceName =
        [NSString stringWithFormat:@"\'%@\'", [resource idlingResourceName]];
    [busyResourcesNames addObject:formattedResourceName];

    NSString *busyResourceDescription =
        [NSString stringWithFormat:@"  %@ : %@",
                                   [resource idlingResourceName],
                                   [resource idlingResourceDescription]];
    [busyResourcesDescription addObject:busyResourceDescription];
  }

  NSString *reason =
      [NSString stringWithFormat:@"Failed to execute block because the following "
                                 @"IdlingResources are busy: [%@]",
                                 [busyResourcesNames componentsJoinedByString:@", "]];
  NSString *details =
      [NSString stringWithFormat:@"Busy resource description:\n%@",
                                 [busyResourcesDescription componentsJoinedByString:@",\n"]];

  return [NSString stringWithFormat:@"%@\n%@", reason, details];
}

/**
 *  Drains the UI thread and waits for both the UI and idling resources to idle, for up to
 *  @c kDrainTimeoutSecondsBeforeForcedStateTrackerCleanup seconds, before forcefully clearing
 *  the state of GREYAppStateTracker.
 */
- (void)grey_forcedStateTrackerCleanUp {
  BOOL idled = [self drainUntilIdleWithTimeout:kDrainTimeoutSecondsBeforeForcedStateTrackerCleanup];
  if (!idled) {
    NSLog(@"EarlGrey tried waiting for %.1f seconds for the application to reach an idle state. It"
          @" is now forced to clear the state of GREYAppStateTracker, because the test might have"
          @" caused the application to remain in non-idle state indefinitely."
          @"\nFull state tracker description: %@",
          kDrainTimeoutSecondsBeforeForcedStateTrackerCleanup,
          [GREYAppStateTracker sharedInstance]);
    [[GREYAppStateTracker sharedInstance] grey_clearState];
  }
}

@end
