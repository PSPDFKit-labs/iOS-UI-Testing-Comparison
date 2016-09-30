//
//  PSPDFKIFTestCase.h
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

#import <KIF/KIF.h>
#import "PSPDFTestAdditions.h"

typedef NS_ENUM(NSUInteger, PSPDFKIFTestCaseSpeed) {
    PSPDFKIFTestCaseSpeedNormal = 1,
    PSPDFKIFTestCaseSpeedCI = 10,
    PSPDFKIFTestCaseSpeedLudicrous = 100
};

NS_ASSUME_NONNULL_BEGIN

@interface PSPDFTestCase : XCTestCase

/// Test running speed. Sets CALayer.speed property on keyWindow's layer.
@property (nonatomic) PSPDFKIFTestCaseSpeed speed;

/// Default test running speed. Depends on whether runing on CI or not.
@property (nonatomic, class, readonly) PSPDFKIFTestCaseSpeed defaultSpeed;

/// Pushes and pops a view controller.
- (void)testWithViewController:(UIViewController *)viewController testBlock:(nullable NS_NOESCAPE dispatch_block_t)testBlock;

/// Pushes a new controller packed in a navigation controller on the root view controller.
- (UINavigationController *)presentViewController:(UIViewController *)viewController;

/// Dismisses a view controller and waits until it's gone.
- (void)dismissViewController:(UIViewController *)viewController;

/// Dismisses a view controller and waits until it's gone with a predefined expectation.
- (void)dismissViewController:(UIViewController *)viewController dismissExpectation:(XCTestExpectation *)dismissExpectation;

@end

NS_ASSUME_NONNULL_END
