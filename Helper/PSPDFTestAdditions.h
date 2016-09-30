//
//  PSPDFTestAdditions.h
//  UITestingComparison
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

typedef BOOL(^PSPDFTestCondition)(void);

// More convenient for Swift to have a trailing block
FOUNDATION_EXTERN BOOL PSPDFWaitForConditionWithTimeout(NSTimeInterval timeout, PSPDFTestCondition condition);

#define PSPDF_DEPRECATED_NOWARN(expression) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
expression \
_Pragma("clang diagnostic pop")
