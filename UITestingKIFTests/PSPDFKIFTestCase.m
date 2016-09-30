//
//  PSPDFKIFTestCase.m
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

#import "PSPDFKIFTestCase.h"

@implementation PSPDFTestCase

- (void)setUp {
    [super setUp];
    
    self.speed = self.class.defaultSpeed;
}

+ (PSPDFKIFTestCaseSpeed)defaultSpeed {
    return PSPDFKIFTestCaseSpeedLudicrous;
}

- (void)setSpeed:(PSPDFKIFTestCaseSpeed)speed {
    _speed = speed;
    UIApplication.sharedApplication.keyWindow.layer.speed = speed;
}

- (void)testWithViewController:(UIViewController *)viewController testBlock:(nullable dispatch_block_t)testBlock {
    UIViewController *container = [self presentViewController:viewController];

    // Wait until animations are done. (e.g. HUD)
    PSPDF_WAIT(0.05f);

    @try {
        if (testBlock) testBlock();
    }
    @finally {
        // We wait again, to ensure any presenting actions are properly committed.
        PSPDF_WAIT(0.05f);

        // Dismiss on parent to ensure any other presented controllers are dismissed as well.
        UIViewController *presentingViewController = container.presentingViewController;
        [self dismissViewController:(presentingViewController ?: container)];
    }
}

- (UINavigationController *)presentViewController:(UIViewController *)viewController {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    XCTestExpectation *presentExpectation = [self expectationWithDescription:@"The view controller should be presented"];
    UINavigationController *navigationController;
    if ([viewController isKindOfClass:UINavigationController.class]) {
        navigationController = (UINavigationController *)viewController;
    } else {
        navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    }
    [rootViewController presentViewController:navigationController animated:NO completion:^{
        // Ensure things are not called too early.
        dispatch_async(dispatch_get_main_queue(), ^{
            [presentExpectation fulfill];
        });
    }];
    [self waitForExpectationsWithTimeout:20.0 handler:nil];
    return navigationController;
}

- (void)dismissViewController:(UIViewController *)viewController {
    XCTestExpectation *dismissExpectation = [self expectationWithDescription:@"The view controller should be dismissed"];
    [self dismissViewController:viewController dismissExpectation:dismissExpectation];
    [self waitForExpectationsWithTimeout:60.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Failed to dismiss %@. Error: %@", viewController, error);
        }
    }];
}

// Version that doesn't wait for an expectation.
- (void)dismissViewController:(UIViewController *)viewController dismissExpectation:(XCTestExpectation *)dismissExpectation {
    [viewController dismissViewControllerAnimated:NO completion:^{
        [dismissExpectation fulfill];
    }];
}

@end
