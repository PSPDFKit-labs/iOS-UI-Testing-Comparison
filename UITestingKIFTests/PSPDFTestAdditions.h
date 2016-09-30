//
//  PSPDFTestAdditions.h
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

typedef BOOL(^PSPDFTestCondition)(void);

// More convenient for Swift to have a trailing block
FOUNDATION_EXTERN BOOL PSPDFWaitForConditionWithTimeout(NSTimeInterval timeout, PSPDFTestCondition condition);

#define PSPDF_DEPRECATED_NOWARN(expression) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
expression \
_Pragma("clang diagnostic pop")

#define PSPDF_WAIT(factor) do { \
[tester waitForAnimationsToFinish]; \
[tester waitForTimeInterval: factor]; \
[tester waitForAnimationsToFinish]; } while(0)
