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

#import "GREYBaseTest.h"

#import <EarlGrey/GREYUIWindowProvider.h>

@interface GREYTestHelperTest : GREYBaseTest

@end

@implementation GREYTestHelperTest

- (void)testAnimationSpeed {
  [GREYTestHelper enableFastAnimation];
  for (UIWindow *window in [GREYUIWindowProvider allWindows]) {
    XCTAssertGreaterThan([[window layer] speed], 1, @"Animation speed not > 1");
  }

  [GREYTestHelper disableFastAnimation];
  for (UIWindow *window in [GREYUIWindowProvider allWindows]) {
    XCTAssertEqual([[window layer] speed], 1, @"Animation speed not == 1");
  }
}

@end
