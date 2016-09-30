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

#import "Synchronization/GREYDispatchQueueTracker.h"

#include <dlfcn.h>
#include <fishhook.h>
#include <libkern/OSAtomic.h>

#import "Common/GREYConfiguration.h"

/**
 *  A pointer to the original implementation of @c dispatch_after.
 */
static void (*grey_original_dispatch_after)(dispatch_time_t when,
                                            dispatch_queue_t queue,
                                            dispatch_block_t block);
/**
 *  A pointer to the original implementation of @c dispatch_async.
 */
static void (*grey_original_dispatch_async)(dispatch_queue_t queue, dispatch_block_t block);
/**
 *  A pointer to the original implementation of @c dispatch_sync.
 */
static void (*grey_original_dispatch_sync)(dispatch_queue_t queue, dispatch_block_t block);

/**
 *  A pointer to the original implementation of @c dispatch_after_f.
 */
static void (*grey_original_dispatch_after_f)(dispatch_time_t when,
                                              dispatch_queue_t queue,
                                              void *context,
                                              dispatch_function_t work);
/**
 *  A pointer to the original implementation of @c dispatch_async_f.
 */
static void (*grey_original_dispatch_async_f)(dispatch_queue_t queue,
                                              void *context,
                                              dispatch_function_t work);
/**
 *  A pointer to the original implementation of @c dispatch_sync_f.
 */
static void (*grey_original_dispatch_sync_f)(dispatch_queue_t queue,
                                             void *context,
                                             dispatch_function_t work);

/**
 *  Used to find the @c GREYDispatchQueueTracker instance corresponding to a dispatch queue, if
 *  one exists.
 */
static NSMapTable *gDispatchQueueToTracker;

@interface GREYDispatchQueueTracker ()

- (void)grey_dispatchAfterCallWithTime:(dispatch_time_t)when block:(dispatch_block_t)block;
- (void)grey_dispatchAsyncCallWithBlock:(dispatch_block_t)block;
- (void)grey_dispatchSyncCallWithBlock:(dispatch_block_t)block;

- (void)grey_dispatchAfterCallWithTime:(dispatch_time_t)when
                               context:(void *)context
                                  work:(dispatch_function_t)work;
- (void)grey_dispatchAsyncCallWithContext:(void *)context work:(dispatch_function_t)work;
- (void)grey_dispatchSyncCallWithContext:(void *)context work:(dispatch_function_t)work;

@end

/**
 * @return The @c GREYDispatchQueueTracker associated with @c queue or @c nil if there is none.
 */
static GREYDispatchQueueTracker *grey_getTrackerForQueue(dispatch_queue_t queue) {
  GREYDispatchQueueTracker *tracker = nil;
  @synchronized(gDispatchQueueToTracker) {
    tracker = [gDispatchQueueToTracker objectForKey:queue];
  }
  return tracker;
}

/**
 *  Overriden implementation of @c dispatch_after that calls into the tracker, if one is found for
 *  the dispatch queue passed in.
 *
 *  @param when  Same as @c dispatch_after @c when.
 *  @param queue Same as @c dispatch_after @c queue.
 *  @param block Same as @c dispatch_after @c block.
 */
static void grey_dispatch_after(dispatch_time_t when,
                                dispatch_queue_t queue,
                                dispatch_block_t block) {
  GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
  if (tracker) {
    [tracker grey_dispatchAfterCallWithTime:when block:block];
  } else {
    grey_original_dispatch_after(when, queue, block);
  }
}

/**
 *  Overriden implementation of @c dispatch_async that calls into the tracker, if one is found for
 *  the dispatch queue passed in.
 *
 *  @param queue Same as @c dispatch_async @c queue.
 *  @param block Same as @c dispatch_async @c block.
 */
static void grey_dispatch_async(dispatch_queue_t queue, dispatch_block_t block) {
  GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
  if (tracker) {
    [tracker grey_dispatchAsyncCallWithBlock:block];
  } else {
    grey_original_dispatch_async(queue, block);
  }
}

/**
 *  Overriden implementation of @c dispatch_sync that calls into the tracker, if one is found for
 *  the dispatch queue passed in.
 *
 *  @param queue Same as @c dispatch_sync @c queue.
 *  @param block Same as @c dispatch_sync @c block.
 */
static void grey_dispatch_sync(dispatch_queue_t queue, dispatch_block_t block) {
  GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
  if (tracker) {
    [tracker grey_dispatchSyncCallWithBlock:block];
  } else {
    grey_original_dispatch_sync(queue, block);
  }
}

/**
 *  Overriden implementation of @c dispatch_after_f that calls into the tracker, if one is found
 *  for the dispatch queue passed in.
 *
 *  @param when    Same as @c dispatch_after_f @c when.
 *  @param queue   Same as @c dispatch_after_f @c queue.
 *  @param context Same as @c dispatch_after_f @c context.
 *  @param work    Same as @c dispatch_after_f @c work.
 */
static void grey_dispatch_after_f(dispatch_time_t when,
                                  dispatch_queue_t queue,
                                  void *context,
                                  dispatch_function_t work) {
  GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
  if (tracker) {
    [tracker grey_dispatchAfterCallWithTime:when context:context work:work];
  } else {
    grey_original_dispatch_after_f(when, queue, context, work);
  }
}

/**
 *  Overriden implementation of @c dispatch_async_f that calls into the tracker, if one is found
 *  for the dispatch queue passed in.
 *
 *  @param queue   Same as @c dispatch_async_f @c queue.
 *  @param context Same as @c dispatch_async_f @c context.
 *  @param work    Same as @c dispatch_async_f @c work.
 */
static void grey_dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t work) {
  GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
  if (tracker) {
    [tracker grey_dispatchAsyncCallWithContext:context work:work];
  } else {
    grey_original_dispatch_async_f(queue, context, work);
  }
}

/**
 *  Overriden implementation of @c dispatch_sync_f that calls into the tracker, if one is found
 *  for the dispatch queue passed in.
 *
 *  @param queue   Same as @c dispatch_sync_f @c queue.
 *  @param context Same as @c dispatch_sync_f @c context.
 *  @param work    Same as @c dispatch_sync_f @c work.
 */
static void grey_dispatch_sync_f(dispatch_queue_t queue, void *context, dispatch_function_t work) {
  GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
  if (tracker) {
    [tracker grey_dispatchSyncCallWithContext:context work:work];
  } else {
    grey_original_dispatch_sync_f(queue, context, work);
  }
}

@implementation GREYDispatchQueueTracker {
  __weak dispatch_queue_t _dispatchQueue;
  __block int32_t _pendingBlocks;
}

+ (void)load {
  @autoreleasepool {
    gDispatchQueueToTracker = [NSMapTable weakToWeakObjectsMapTable];

    GREY_UNUSED_VARIABLE dispatch_queue_t dummyQueue =
        dispatch_queue_create("GREYDummyQueue", DISPATCH_QUEUE_SERIAL);
    NSAssert(dummyQueue, @"dummmyQueue must not be nil");

    // Use dlsym to get the original pointer because of
    // https://github.com/facebook/fishhook/issues/21
    grey_original_dispatch_after = dlsym(RTLD_DEFAULT, "dispatch_after");
    grey_original_dispatch_async = dlsym(RTLD_DEFAULT, "dispatch_async");
    grey_original_dispatch_sync = dlsym(RTLD_DEFAULT, "dispatch_sync");
    grey_original_dispatch_after_f = dlsym(RTLD_DEFAULT, "dispatch_after_f");
    grey_original_dispatch_async_f = dlsym(RTLD_DEFAULT, "dispatch_async_f");
    grey_original_dispatch_sync_f = dlsym(RTLD_DEFAULT, "dispatch_sync_f");
    NSAssert(grey_original_dispatch_after, @"Pointer to dispatch_after must not be NULL");
    NSAssert(grey_original_dispatch_async, @"Pointer to dispatch_async must not be NULL");
    NSAssert(grey_original_dispatch_sync, @"Pointer to dispatch_sync must not be NULL");
    NSAssert(grey_original_dispatch_after_f, @"Pointer to dispatch_after_f must not be NULL");
    NSAssert(grey_original_dispatch_async_f, @"Pointer to dispatch_async_f must not be NULL");
    NSAssert(grey_original_dispatch_sync_f, @"Pointer to dispatch_sync_f must not be NULL");

    // Rebind symbols dispatch_* to point to our own implementation.
    struct rebinding rebindings[] = {
      {"dispatch_after", grey_dispatch_after, NULL},
      {"dispatch_async", grey_dispatch_async, NULL},
      {"dispatch_sync", grey_dispatch_sync, NULL},
      {"dispatch_after_f", grey_dispatch_after_f, NULL},
      {"dispatch_async_f", grey_dispatch_async_f, NULL},
      {"dispatch_sync_f", grey_dispatch_sync_f, NULL},
    };
    GREY_UNUSED_VARIABLE int failure =
        rebind_symbols(rebindings, sizeof(rebindings) / sizeof(rebindings[0]));
    NSAssert(!failure, @"rebinding symbols failed");
  }
}

#pragma mark -

+ (instancetype)trackerForDispatchQueue:(dispatch_queue_t)queue {
  NSParameterAssert(queue);

  @synchronized(gDispatchQueueToTracker) {
    GREYDispatchQueueTracker *tracker = grey_getTrackerForQueue(queue);
    if (!tracker) {
      tracker = [[GREYDispatchQueueTracker alloc] initWithDispatchQueue:queue];
      // Register this tracker with dispatch queue to tracker map.
      [gDispatchQueueToTracker setObject:tracker forKey:queue];
    }
    return tracker;
  }
}

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)queue {
  NSParameterAssert(queue);

  self = [super init];
  if (self) {
    _dispatchQueue = queue;
  }
  return self;
}

- (BOOL)isIdleNow {
  NSAssert(_pendingBlocks >= 0, @"_pendingBlocks must not be negative");
  BOOL isIdle = OSAtomicCompareAndSwap32Barrier(0, 0, &_pendingBlocks);
  return isIdle;
}

- (BOOL)isTrackingALiveQueue {
  return _dispatchQueue != nil;
}

#pragma mark - Private

- (void)grey_dispatchAfterCallWithTime:(dispatch_time_t)when block:(dispatch_block_t)block {
  CFTimeInterval maxDelay = GREY_CONFIG_DOUBLE(kGREYConfigKeyDispatchAfterMaxTrackableDelay);
  dispatch_time_t trackDelay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(maxDelay * NSEC_PER_SEC));

  if (trackDelay >= when) {
    OSAtomicIncrement32Barrier(&_pendingBlocks);
    grey_original_dispatch_after(when, _dispatchQueue, ^{
      block();
      OSAtomicDecrement32Barrier(&_pendingBlocks);
    });
  } else {
    grey_original_dispatch_after(when, _dispatchQueue, block);
  }
}

- (void)grey_dispatchAsyncCallWithBlock:(dispatch_block_t)block {
  OSAtomicIncrement32Barrier(&_pendingBlocks);
  grey_original_dispatch_async(_dispatchQueue, ^{
    block();
    OSAtomicDecrement32Barrier(&_pendingBlocks);
  });
}

- (void)grey_dispatchSyncCallWithBlock:(dispatch_block_t)block {
  OSAtomicIncrement32Barrier(&_pendingBlocks);
  grey_original_dispatch_sync(_dispatchQueue, ^{
    block();
    OSAtomicDecrement32Barrier(&_pendingBlocks);
  });
}

- (void)grey_dispatchAfterCallWithTime:(dispatch_time_t)when
                               context:(void *)context
                                  work:(dispatch_function_t)work {
  CFTimeInterval maxDelay = GREY_CONFIG_DOUBLE(kGREYConfigKeyDispatchAfterMaxTrackableDelay);
  dispatch_time_t trackDelay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(maxDelay * NSEC_PER_SEC));
  if (trackDelay >= when) {
    OSAtomicIncrement32Barrier(&_pendingBlocks);
    grey_original_dispatch_after(when, _dispatchQueue, ^{
      work(context);
      OSAtomicDecrement32Barrier(&_pendingBlocks);
    });
  } else {
    grey_original_dispatch_after_f(when, _dispatchQueue, context, work);
  }
}

- (void)grey_dispatchAsyncCallWithContext:(void *)context work:(dispatch_function_t)work {
  OSAtomicIncrement32Barrier(&_pendingBlocks);
  grey_original_dispatch_async(_dispatchQueue, ^{
    work(context);
    OSAtomicDecrement32Barrier(&_pendingBlocks);
  });
}

- (void)grey_dispatchSyncCallWithContext:(void *)context work:(dispatch_function_t)work {
  OSAtomicIncrement32Barrier(&_pendingBlocks);
  grey_original_dispatch_sync(_dispatchQueue, ^{
    work(context);
    OSAtomicDecrement32Barrier(&_pendingBlocks);
  });
}

@end
