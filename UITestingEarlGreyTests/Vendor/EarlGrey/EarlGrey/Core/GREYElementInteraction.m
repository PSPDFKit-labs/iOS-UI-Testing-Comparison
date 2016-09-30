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

#import "Core/GREYElementInteraction.h"

#import "Action/GREYAction.h"
#import "Additions/NSError+GREYAdditions.h"
#import "Additions/NSObject+GREYAdditions.h"
#import "Assertion/GREYAssertion.h"
#import "Assertion/GREYAssertionDefines.h"
#import "Assertion/GREYAssertions.h"
#import "Common/GREYConfiguration.h"
#import "Common/GREYDefines.h"
#import "Common/GREYPrivate.h"
#import "Core/GREYElementFinder.h"
#import "Core/GREYInteractionDataSource.h"
#import "Exception/GREYFrameworkException.h"
#import "Matcher/GREYAllOf.h"
#import "Matcher/GREYMatcher.h"
#import "Matcher/GREYMatchers.h"
#import "Provider/GREYElementProvider.h"
#import "Provider/GREYUIWindowProvider.h"
#import "Synchronization/GREYUIThreadExecutor.h"

/**
 *  Extern variable specifying the error domain for GREYElementInteraction.
 */
NSString *const kGREYInteractionErrorDomain = @"com.google.earlgrey.ElementInteractionErrorDomain";
NSString *const kGREYWillPerformActionNotification = @"GREYWillPerformActionNotification";
NSString *const kGREYDidPerformActionNotification = @"GREYDidPerformActionNotification";
NSString *const kGREYWillPerformAssertionNotification = @"GREYWillPerformAssertionNotification";
NSString *const kGREYDidPerformAssertionNotification = @"GREYDidPerformAssertionNotification";

/**
 *  Extern variables specifying the user info keys for any notifications.
 */
NSString *const kGREYActionUserInfoKey = @"kGREYActionUserInfoKey";
NSString *const kGREYActionElementUserInfoKey = @"kGREYActionElementUserInfoKey";
NSString *const kGREYActionErrorUserInfoKey = @"kGREYActionErrorUserInfoKey";
NSString *const kGREYAssertionUserInfoKey = @"kGREYAssertionUserInfoKey";
NSString *const kGREYAssertionElementUserInfoKey = @"kGREYAssertionElementUserInfoKey";
NSString *const kGREYAssertionErrorUserInfoKey = @"kGREYAssertionErrorUserInfoKey";

@interface GREYElementInteraction() <GREYInteractionDataSource>
@end

@implementation GREYElementInteraction {
  id<GREYMatcher> _rootMatcher;
  id<GREYMatcher> _searchActionElementMatcher;
  id<GREYMatcher> _elementMatcher;
  id<GREYAction> _searchAction;
  // If _index is set to NSUIntegerMax, then it is unassigned.
  NSUInteger _index;
}

@synthesize dataSource;

- (instancetype)initWithElementMatcher:(id<GREYMatcher>)elementMatcher {
  NSParameterAssert(elementMatcher);

  self = [super init];
  if (self) {
    _elementMatcher = elementMatcher;
    _index = NSUIntegerMax;
    [self setDataSource:self];
  }
  return self;
}

- (instancetype)inRoot:(id<GREYMatcher>)rootMatcher {
  _rootMatcher = rootMatcher;
  return self;
}

- (instancetype)atIndex:(NSUInteger)index {
  _index = index;
  return self;
}

/**
 *  Searches for UI elements within the root views and returns all matched UI elements. The given
 *  search action is performed until an element is found.
 *
 *  @param timeout The amount of time during which search actions must be performed to find an
 *                 element.
 *  @param error   The error populated on failure. If an element was found and returned when using
 *                 the search actions then any action or timeout errors that happened in the
 *                 previous search are ignored. However, if an element is not found, the error
 *                 will be propagated.
 *
 *  @return An array of matched UI elements in the data source. If no UI element is found in
 *          @c timeout seconds, a timeout error will be produced and no UI element will be returned.
 */
- (NSArray *)matchedElementsWithTimeout:(CFTimeInterval)timeout error:(__strong NSError **)error {
  NSParameterAssert(error);

  id<GREYInteractionDataSource> strongDataSource = [self dataSource];
  NSAssert(strongDataSource, @"strongDataSource must be set before fetching UI elements");

  GREYElementProvider *entireRootHierarchyProvider =
      [GREYElementProvider providerWithRootProvider:[strongDataSource rootElementProvider]];
  id<GREYMatcher> elementMatcher = _elementMatcher;
  if (_rootMatcher) {
    elementMatcher = grey_allOf(elementMatcher, grey_ancestor(_rootMatcher), nil);
  }
  GREYElementFinder *elementFinder = [[GREYElementFinder alloc] initWithMatcher:elementMatcher];
  NSError *searchActionError = nil;
  CFTimeInterval timeoutTime = CACurrentMediaTime() + timeout;
  BOOL timedOut = NO;
  while (YES) {
    @autoreleasepool {
      // Find the element in the current UI hierarchy.
      NSArray *elements = [elementFinder elementsMatchedInProvider:entireRootHierarchyProvider];
      if (elements.count > 0) {
        return elements;
      } else if (!_searchAction) {
        if (error) {
          NSString *desc =
              @"Interaction cannot continue because the desired element was not found.";
          *error = [NSError errorWithDomain:kGREYInteractionErrorDomain
                                       code:kGREYInteractionElementNotFoundErrorCode
                                   userInfo:@{ NSLocalizedDescriptionKey : desc }];
        }
        return nil;
      } else if (searchActionError) {
        break;
      }

      CFTimeInterval currentTime = CACurrentMediaTime();
      if (currentTime >= timeoutTime) {
        timedOut = YES;
        break;
      }
      // Keep applying search action.
      id<GREYInteraction> interaction =
          [[GREYElementInteraction alloc] initWithElementMatcher:_searchActionElementMatcher];
      // Don't fail if this interaction error's out. It might still have revealed the element
      // we're looking for.
      [interaction performAction:_searchAction error:&searchActionError];
      // Drain here so that search at the beginning of the loop looks at stable UI.
      [[GREYUIThreadExecutor sharedInstance] drainUntilIdle];
    }
  }

  NSDictionary *userInfo = nil;
  if (searchActionError) {
    userInfo = @{ NSUnderlyingErrorKey : searchActionError };
  } else if (timedOut) {
    CFTimeInterval interactionTimeout =
        GREY_CONFIG_DOUBLE(kGREYConfigKeyInteractionTimeoutDuration);
    NSString *desc = [NSString stringWithFormat:@"Interaction timed out after %g seconds while "
                                                @"searching for element.", interactionTimeout];
    NSError *timeoutError = [NSError errorWithDomain:kGREYInteractionErrorDomain
                                                code:kGREYInteractionTimeoutErrorCode
                                            userInfo:@{ NSLocalizedDescriptionKey : desc }];
    userInfo = @{ NSUnderlyingErrorKey : timeoutError };
  }
  *error = [NSError errorWithDomain:kGREYInteractionErrorDomain
                               code:kGREYInteractionElementNotFoundErrorCode
                           userInfo:userInfo];
  return nil;
}

#pragma mark - GREYInteractionDataSource

/**
 *  Default data source for this interaction if no datasource is set explicitly.
 */
- (id<GREYProvider>)rootElementProvider {
  return [GREYUIWindowProvider providerWithAllWindows];
}

#pragma mark - GREYInteraction

- (instancetype)performAction:(id<GREYAction>)action {
  return [self performAction:action error:nil];
}

- (instancetype)performAction:(id<GREYAction>)action error:(__strong NSError **)errorOrNil {
  NSParameterAssert(action);
  I_CHECK_MAIN_THREAD();

  @autoreleasepool {
    NSError *executorError;
    __block NSError *actionError = nil;
    __weak __typeof__(self) weakSelf = self;

    // Create the user info dictionary for any notificatons and set it up with the action.
    NSMutableDictionary *actionUserInfo = [[NSMutableDictionary alloc] init];
    [actionUserInfo setObject:action forKey:kGREYActionUserInfoKey];
    NSNotificationCenter *defaultNotificationCenter = [NSNotificationCenter defaultCenter];

    CFTimeInterval interactionTimeout =
        GREY_CONFIG_DOUBLE(kGREYConfigKeyInteractionTimeoutDuration);

    // Assign a flag that provides info if the interaction being performed failed.
    __block BOOL interactionFailed = NO;
    BOOL executionSucceeded =
        [[GREYUIThreadExecutor sharedInstance] executeSyncWithTimeout:interactionTimeout
                                                                block:^{
      __typeof__(self) strongSelf = weakSelf;
      NSAssert(strongSelf, @"Must not be nil");

      // Obtain all elements from the hierarchy and populate the passed error in case of
      // an element not being found.
      NSError *elementNotFoundError = nil;
      NSArray *elements = [strongSelf matchedElementsWithTimeout:interactionTimeout
                                                           error:&elementNotFoundError];
      id element = nil;
      if (elements) {
        // Get the uniquely matched element. If this is nil, then it means that there has been
        // an error in finding a unique element, such as multiple matcher error.
        element = [strongSelf grey_uniqueElementInMatchedElements:elements
                                                         andError:&actionError];
        if (element) {
          [actionUserInfo setObject:element forKey:kGREYActionElementUserInfoKey];
        } else {
          interactionFailed = YES;
          [actionUserInfo setObject:actionError forKey:kGREYActionErrorUserInfoKey];
        }
      } else {
        interactionFailed = YES;
        actionError = elementNotFoundError;
        [actionUserInfo setObject:elementNotFoundError forKey:kGREYActionErrorUserInfoKey];
      }
      // Post notification that the action is to be performed on the found element.
      [defaultNotificationCenter postNotificationName:kGREYWillPerformActionNotification
                                               object:nil
                                             userInfo:actionUserInfo];

      if (element && ![action perform:element error:&actionError]) {
        interactionFailed = YES;
        // Action didn't succeed yet no error was set.
        if (!actionError) {
          NSDictionary *userInfo =
              @{ NSLocalizedDescriptionKey : @"Reason for action failure was not provided." };
          actionError = [NSError errorWithDomain:kGREYInteractionErrorDomain
                                            code:kGREYInteractionActionFailedErrorCode
                                        userInfo:userInfo];
        }
        // Add the error obtained from the action to the user info notification dictionary.
        [actionUserInfo setObject:actionError forKey:kGREYActionErrorUserInfoKey];
      }
      // Post notification for the process of an action's execution being completed. This
      // notification does not mean that the action was performed successfully.
      [defaultNotificationCenter postNotificationName:kGREYDidPerformActionNotification
                                               object:nil
                                             userInfo:actionUserInfo];
      // If we encounter a failure and going to raise an exception, raise it right away before
      // the main runloop drains any further.
      if (interactionFailed && !errorOrNil) {
        [strongSelf grey_handleFailureOfAction:action
                                   actionError:actionError
                          userProvidedOutError:nil];
      }
    } error:&executorError];

    // Failure to execute due to timeout should be represented as interaction timeout.
    if (!executionSucceeded) {
      if ([executorError.domain isEqualToString:kGREYUIThreadExecutorErrorDomain] &&
          executorError.code == kGREYUIThreadExecutorTimeoutErrorCode) {
        NSString *actionTimeoutDesc =
            [NSString stringWithFormat:@"Failed to perform action within %g seconds.",
             interactionTimeout];
        NSDictionary *userInfo = @{
                                   NSUnderlyingErrorKey : executorError,
                                   NSLocalizedDescriptionKey : actionTimeoutDesc,
                                   };
        actionError = [NSError errorWithDomain:kGREYInteractionErrorDomain
                                          code:kGREYInteractionTimeoutErrorCode
                                      userInfo:userInfo];
      }
    }

    // Since we assign all errors found to the @c actionError, if either of these failed then
    // we provide it for error handling.
    if (!executionSucceeded || interactionFailed) {
      [self grey_handleFailureOfAction:action
                           actionError:actionError
                  userProvidedOutError:errorOrNil];
    }
    // Drain once to update idling resources and redraw the screen.
    [[GREYUIThreadExecutor sharedInstance] drainOnce];
  }
  return self;
}

- (instancetype)assert:(id<GREYAssertion>)assertion {
  return [self assert:assertion error:nil];
}

- (instancetype)assert:(id<GREYAssertion>)assertion error:(__strong NSError **)errorOrNil {
  NSParameterAssert(assertion);
  I_CHECK_MAIN_THREAD();

  @autoreleasepool {
    NSError *executorError;
    __block NSError *assertionError = nil;
    __weak __typeof__(self) weakSelf = self;

    NSNotificationCenter *defaultNotificationCenter = [NSNotificationCenter defaultCenter];

    CGFloat interactionTimeout =
        (CGFloat)GREY_CONFIG_DOUBLE(kGREYConfigKeyInteractionTimeoutDuration);
    // Assign a flag that provides info if the interaction being performed failed.
    __block BOOL interactionFailed = NO;
    BOOL executionSucceeded =
        [[GREYUIThreadExecutor sharedInstance] executeSyncWithTimeout:interactionTimeout block:^{
      __typeof__(self) strongSelf = weakSelf;
      NSAssert(strongSelf, @"strongSelf must not be nil");

      // An error object that holds error due to element not found (if any). It is used only when
      // an assertion fails because element was nil. That's when we surface this error.
      NSError *elementNotFoundError = nil;
      // Obtain all elements from the hierarchy and populate the passed error in case of
      // an element not being found.
      NSArray *elements = [strongSelf matchedElementsWithTimeout:interactionTimeout
                                                           error:&elementNotFoundError];
      id element = (elements.count != 0) ?
          [strongSelf grey_uniqueElementInMatchedElements:elements andError:&assertionError] : nil;

      // Create the user info dictionary for any notificatons and set it up with the assertion.
      NSMutableDictionary *assertionUserInfo = [[NSMutableDictionary alloc] init];
      [assertionUserInfo setObject:assertion forKey:kGREYAssertionUserInfoKey];

      // Post notification for the assertion to be checked on the found element.
      // We send the notification for an assert even if no element was found.
      BOOL multipleMatchesPresent = NO;
      if (element) {
        [assertionUserInfo setObject:element forKey:kGREYAssertionElementUserInfoKey];
      } else if (assertionError) {
        // Check for multiple matchers since we don't want the assertion to be checked when this
        // error surfaces.
        multipleMatchesPresent =
            (assertionError.code == kGREYInteractionMultipleElementsMatchedErrorCode ||
            assertionError.code == kGREYInteractionMatchedElementIndexOutOfBoundsErrorCode);
        [assertionUserInfo setObject:assertionError forKey:kGREYAssertionErrorUserInfoKey];
      }
      [defaultNotificationCenter postNotificationName:kGREYWillPerformAssertionNotification
                                               object:nil
                                             userInfo:assertionUserInfo];

      // In the case of an assertion, we can have a nil element present as well. For this purpose,
      // we check the assertion directly and see if there was any issue. The only case where we
      // are completely sure we do not need to perform the action is in the case of a multiple
      // matcher.
      if (multipleMatchesPresent) {
        interactionFailed = YES;
      } else if (![assertion assert:element error:&assertionError]) {
        interactionFailed = YES;
        // Set the elementNotFoundError to the assertionError since the error has been utilized
        // already.
        if ([assertionError.domain isEqualToString:kGREYInteractionErrorDomain] &&
            (assertionError.code == kGREYInteractionElementNotFoundErrorCode)) {
          assertionError = elementNotFoundError;
        }
        // Assertion didn't succeed yet no error was set.
        if (!assertionError) {
          NSDictionary *userInfo =
              @{ NSLocalizedDescriptionKey : @"Reason for assertion failure was not provided." };
          assertionError = [NSError errorWithDomain:kGREYInteractionErrorDomain
                                               code:kGREYInteractionAssertionFailedErrorCode
                                           userInfo:userInfo];
        }
        // Add the error obtained from the action to the user info notification dictionary.
        [assertionUserInfo setObject:assertionError forKey:kGREYAssertionErrorUserInfoKey];
      }

      // Post notification for the process of an assertion's execution on the specified element
      // being completed. This notification does not mean that the assertion was performed
      // successfully.
      [defaultNotificationCenter postNotificationName:kGREYDidPerformAssertionNotification
                                               object:nil
                                             userInfo:assertionUserInfo];
      // If we encounter a failure and going to raise an exception, raise it right away before
      // the main runloop drains any further.
      if (interactionFailed && !errorOrNil) {
        [strongSelf grey_handleFailureOfAssertion:assertion
                                   assertionError:assertionError
                             userProvidedOutError:nil];
      }
    } error:&executorError];

    // Failure to execute due to timeout should be represented as interaction timeout.
    if (!executionSucceeded) {
      if ([executorError.domain isEqualToString:kGREYUIThreadExecutorErrorDomain] &&
          executorError.code == kGREYUIThreadExecutorTimeoutErrorCode) {
        NSString *assertionTimeoutDesc =
            [NSString stringWithFormat:@"Failed to execute assertion within %g seconds.",
             interactionTimeout];
        NSDictionary *userInfo = @{
                                   NSUnderlyingErrorKey : executorError,
                                   NSLocalizedDescriptionKey : assertionTimeoutDesc,
                                   };
        assertionError = [NSError errorWithDomain:kGREYInteractionErrorDomain
                                             code:kGREYInteractionTimeoutErrorCode
                                         userInfo:userInfo];
      }
    }

    if (!executionSucceeded || interactionFailed) {
      [self grey_handleFailureOfAssertion:assertion
                           assertionError:assertionError
                     userProvidedOutError:errorOrNil];
    }
  }
  return self;
}

- (instancetype)assertWithMatcher:(id<GREYMatcher>)matcher {
  return [self assertWithMatcher:matcher error:nil];
}

- (instancetype)assertWithMatcher:(id<GREYMatcher>)matcher error:(__strong NSError **)errorOrNil {
  return [self assert:[GREYAssertions grey_createAssertionWithMatcher:matcher] error:errorOrNil];
}

- (instancetype)usingSearchAction:(id<GREYAction>)action
             onElementWithMatcher:(id<GREYMatcher>)matcher {
  NSParameterAssert(action);
  NSParameterAssert(matcher);

  _searchActionElementMatcher = matcher;
  _searchAction = action;
  return self;
}

# pragma mark - Private

/**
 *  From the set of matched elements, obtain one unique element for the provided matcher. In case
 *  there are multiple elements matched, then the one selected by the _@c index provided is chosen
 *  else the provided @c interactionError is populated.
 *
 *  @param[out] interactionError A passed error for populating if multiple elements are found.
 *                               If this is nil then cases like multiple matchers cannot be checked
 *                               for.
 *
 *  @return A uniquely matched element, if any.
 */
- (id)grey_uniqueElementInMatchedElements:(NSArray *)elements
                                 andError:(__strong NSError **)interactionError {
  // If we find that multiple matched elements are present, we narrow them down based on
  // any index passed or populate the passed error if the multiple matches are present and
  // an incorrect index was passed.
  if (elements.count > 1) {
    // If the number of matched elements are greater than 1 then we have to use the index for
    // matching. We perform a bounds check on the index provided here and throw an exception if
    // it fails.
    if (_index == NSUIntegerMax) {
      *interactionError = [self grey_errorForMultipleMatchingElements:elements
                                  withMatchedElementsIndexOutOfBounds:NO];
      return nil;
    } else if (_index >= elements.count) {
      *interactionError = [self grey_errorForMultipleMatchingElements:elements
                                  withMatchedElementsIndexOutOfBounds:YES];
      return nil;
    } else {
      return [elements objectAtIndex:_index];
    }
  }
  // If you haven't got a multiple / element not found error then you have one single matched
  // element and can select it directly.
  return [elements firstObject];
}

/**
 *  Handles failure of an @c action.
 *
 *  @param action                 The action that failed.
 *  @param actionError            Contains the reason for failure.
 *  @param[out] userProvidedError The out error (or nil) provided by the user.
 *  @throws NSException to denote the failure of an action, thrown if the @c userProvidedError
 *          is nil on test failure.
 *
 *  @return Junk boolean value to suppress xcode warning to have "a non-void return
 *          value to indicate an error occurred"
 */
- (BOOL)grey_handleFailureOfAction:(id<GREYAction>)action
                       actionError:(NSError *)actionError
              userProvidedOutError:(__strong NSError **)userProvidedError {
  NSParameterAssert(actionError);

  // Throw an exception if userProvidedError isn't provided and the action failed.
  if (!userProvidedError) {
    if ([actionError.domain isEqualToString:kGREYInteractionErrorDomain]) {
      NSString *searchAPIInfo = [self grey_searchActionDescription];

      // Customize exception based on the error.
      switch (actionError.code) {
        case kGREYInteractionElementNotFoundErrorCode: {
          NSString *reason =
              [NSString stringWithFormat:@"Action '%@' was not performed because no UI element "
                                         @"matching %@ was found.", action.name, _elementMatcher];
          I_GREYElementNotFound(reason, @"%@Complete Error: %@", searchAPIInfo, actionError);
          return NO;
        }
        case kGREYInteractionMultipleElementsMatchedErrorCode: {
          NSString *reason =
             [NSString stringWithFormat:@"Action '%@' was not performed because multiple UI "
                                        @"elements matching %@ were found. Use grey_allOf(...) to "
                                        @"create a more specific matcher.",
                                        action.name, _elementMatcher];
          // We print the localized description here to prevent the multiple matchers info from
          // being displayed twice - once in the error and once in the userInfo dict.
          I_GREYMultipleElementsFound(reason,
                                      @"%@Complete Error: %@",
                                      searchAPIInfo,
                                      actionError.localizedDescription);
          return NO;
        }
      }
    }

    // TODO: Add unique failure messages for timeout and other well-known reasons.
    NSString *reason = [NSString stringWithFormat:@"Action '%@' failed.", action.name];
    I_GREYActionFail(reason,
                     @"Element matcher: %@\nComplete Error: %@", _elementMatcher, actionError);
  } else {
    *userProvidedError = actionError;
  }

  return NO;
}

/**
 *  Handles failure of an @c assertion.
 *
 *  @param assertion              The asserion that failed.
 *  @param assertionError         Contains the reason for the failure.
 *  @param[out] userProvidedError Error (or @c nil) provided by the user. When @c nil, an exception
 *                                is thrown to halt further execution of the test case.
 *  @throws NSException to denote an assertion failure, thrown if the @c userProvidedError
 *          is @c nil on test failure.
 *
 *  @return Junk boolean value to suppress xcode warning to have "a non-void return
 *          value to indicate an error occurred"
 */
- (BOOL)grey_handleFailureOfAssertion:(id<GREYAssertion>)assertion
                       assertionError:(NSError *)assertionError
                 userProvidedOutError:(__strong NSError **)userProvidedError {
  NSParameterAssert(assertionError);
  // Throw an exception if userProvidedError isn't provided and the assertion failed.
  if (!userProvidedError) {
    if ([assertionError.domain isEqualToString:kGREYInteractionErrorDomain]) {
      NSString *searchAPIInfo = [self grey_searchActionDescription];

      // Customize exception based on the error.
      switch (assertionError.code) {
        case kGREYInteractionElementNotFoundErrorCode: {
          NSString *reason =
              [NSString stringWithFormat:@"Assertion '%@' was not performed because no UI element "
                                         @"matching %@ was found.",
                                         [assertion name], _elementMatcher];
          I_GREYElementNotFound(reason, @"%@Complete Error: %@", searchAPIInfo, assertionError);
          return NO;
        }
        case kGREYInteractionMultipleElementsMatchedErrorCode: {
          NSString *reason =
              [NSString stringWithFormat:@"Assertion '%@' was not performed because multiple UI "
                                         @"elements matching %@ were found. Use grey_allOf(...) to "
                                         @"create a more specific matcher.",
                                         [assertion name], _elementMatcher];
          I_GREYMultipleElementsFound(reason, @"%@Complete Error: %@",
                                      searchAPIInfo,
                                      assertionError);
          return NO;
        }
      }
    }

    // TODO: Add unique failure messages for timeout and other well-known reason for failure.
    NSString *reason = [NSString stringWithFormat:@"Assertion '%@' failed.", assertion.name];
    I_GREYAssertionFail(reason, @"Element matcher: %@\nComplete Error: %@",
                        _elementMatcher, assertionError);
  } else {
    *userProvidedError = assertionError;
  }

  return NO;
}

/**
 *  Provides an error with @c kGREYInteractionMultipleElementsMatchedErrorCode for multiple
 *  elements matching the specified matcher. In case we have multiple matchers and the Index
 *  provided for not matching with it is out of bounds, then we set the error code to
 *  @c kGREYInteractionMatchedElementIndexOutOfBoundsErrorCode.
 *
 *  @param matchingElements A set of matching elements.
 *  @param outOfBounds      A boolean that flags if the index for finding a matching element
 *                          is out of bounds.
 *
 *  @return Error for matching multiple elements.
 */
- (NSError *)grey_errorForMultipleMatchingElements:(NSArray *)matchingElements
               withMatchedElementsIndexOutOfBounds:(BOOL)outOfBounds {

  // Populate an array with the matching elements that are causing the exception.
  NSMutableArray *elementDescriptions =
      [[NSMutableArray alloc] initWithCapacity:matchingElements.count];

  [matchingElements enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    [elementDescriptions addObject:[obj grey_description]];
  }];

  // Populate the multiple matching elements error.
  NSString *errorDescription;
  NSInteger errorCode;
  if (outOfBounds) {
    // Populate with an error specifying that the index provided for matching the multiple elements
    // was out of bounds.
    errorDescription = [NSString stringWithFormat:@"Multiple elements were matched: %@ with an "
                                                  @"index that is out of bounds of the number of "
                                                  @"matched elements. Please use an element "
                                                  @"index from 0 to %tu",
                                                  elementDescriptions,
                                                  ([elementDescriptions count] - 1)];
    errorCode = kGREYInteractionMatchedElementIndexOutOfBoundsErrorCode;
  } else {
    // Populate with an error specifying that multiple elements were matched without providing
    // an index.
    errorDescription = [NSString stringWithFormat:@"Multiple elements were matched: %@. Please "
                                                  @"use selection matchers to narrow the "
                                                  @"selection down to single element.",
                                                  elementDescriptions];
    errorCode = kGREYInteractionMultipleElementsMatchedErrorCode;
  }

  // Populate the user info for the multiple matching elements error.
  NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : errorDescription };
  return [NSError errorWithDomain:kGREYInteractionErrorDomain
                             code:errorCode
                         userInfo:userInfo];
}

/**
 *  @return A String description of the current search action.
 */
- (NSString *)grey_searchActionDescription {
  if (_searchAction) {
    return [NSString stringWithFormat:@"Search action: %@. \nSearch action element matcher: %@.\n",
            _searchAction, _searchActionElementMatcher];
  } else {
    return @"";
  }
}

@end
