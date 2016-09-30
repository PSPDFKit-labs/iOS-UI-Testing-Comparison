//
//  XCTestCaseKIFExtensions.swift
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//


import XCTest

extension XCTestCase {

    @nonobjc var tester: KIFUITestActor { return tester() }
    @nonobjc var system: KIFSystemTestActor { return system() }

    @nonobjc func waitForCondition(condition: @autoclosure @escaping () -> Bool, negateCondition: Bool = false) {
            XCTAssertTrue(PSPDFWaitForConditionWithTimeout(30, negateCondition ? { !condition() } : { condition() }))
    }
    
    func tester(file : String = #file, _ line : Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }

    func system(file : String = #file, _ line : Int = #line) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self)
    }
}
