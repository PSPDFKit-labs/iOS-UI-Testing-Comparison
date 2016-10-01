//
//  XCTestCaseKIFExtensions.swift
//  UITestingKIFTests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import XCTest

extension XCTestCase {

    @nonobjc var tester: KIFUITestActor { return tester() }
    @nonobjc var system: KIFSystemTestActor { return system() }

    @nonobjc func wait(for condition: @autoclosure @escaping (Void) -> Bool, negateCondition: Bool = false) {
        XCTAssertTrue(PSPDFWaitForConditionWithTimeout(30, negateCondition ? { !condition() } : { condition() }))
    }

    func tester(file : String = #file, _ line : Int = #line) -> KIFUITestActor {
        return KIFUITestActor(inFile: file, atLine: line, delegate: self)
    }

    func system(file : String = #file, _ line : Int = #line) -> KIFSystemTestActor {
        return KIFSystemTestActor(inFile: file, atLine: line, delegate: self)
    }
}
