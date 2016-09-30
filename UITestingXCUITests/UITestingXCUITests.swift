//
//  UITestingXCUITests.swift
//  UITestingXCUITests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

import XCTest

class UITestingXCUITests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    func testSearch() {
        let app = XCUIApplication()
        XCUIDevice.shared().orientation = .portrait

        app.navigationBars["UITestingComparison.PDFView"].buttons["Search"].tap()
        
        let searchDocumentSearchField = app.searchFields["Search Document"]
        searchDocumentSearchField.typeText("PSPDF")

      //  app.tables["Search Results"].cells[0].tap()

    }

    func testAddPage() {
        XCUIDevice.shared().orientation = .portrait
        
        let app = XCUIApplication()
        let uitestingcomparisonPdfviewNavigationBar = app.navigationBars["UITestingComparison.PDFView"]
        uitestingcomparisonPdfviewNavigationBar.buttons["Thumbnails"].tap()
        uitestingcomparisonPdfviewNavigationBar.buttons["Document Editor"].tap()
        app.buttons["Add Page"].tap()
        
        let patternCell = app.tables.cells["Pattern"]
        patternCell.tap()
        patternCell.tap()
        
        let app2 = app
        app2.tables.staticTexts["Commit"].tap()
        app.buttons["Done"].tap()

        app.sheets.buttons["Save As…"].tap()
        app.navigationBars["Save As…"].buttons["Save"].tap()
        app.collectionViews["Thumbnail Collection"].cells["Page 1"].tap()
    }
    
}
