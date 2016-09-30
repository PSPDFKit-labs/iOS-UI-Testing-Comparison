//
//  UITestingXCUITests.swift
//  UITestingXCUITests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

class UITestingXCUITests: PSPDFTestCase {
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
        //speed = .normal
    }
    
    func testSearch() {
        XCUIDevice.shared().orientation = .portrait
        let app = XCUIApplication()

        app.navigationBars["UITestingComparison.PDFView"].buttons["Search"].tap()
        
        let searchDocumentSearchField = app.searchFields["Search Document"]
        searchDocumentSearchField.typeText("PSPDF")

        app.tables["Search Results"].cells.element(boundBy: 0).tap()
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

        app.sheets.buttons["Save"].tap()
        app.collectionViews["Thumbnail Collection"].cells["Page 1"].tap()
    }

    func testAddAndDeleteBookmark() {
        let app = XCUIApplication()
        let outlineButton = app.navigationBars["PSPDFKit 6 QuickStart Guide"].buttons["Outline"]
        outlineButton.tap()
        app.navigationBars["Outline"].buttons["Bookmarks"].tap()
        
        let tablesQuery = app.tables
        let worldMapStaticText = tablesQuery.staticTexts["World Map"].swipeLeft()
    }
    
}
