//
//  UITestingXCUITests.swift
//  UITestingXCUITests
//
//  Copyright © 2016 PSPDFKit GmbH. All rights reserved.
//

import PSPDFKit

class UITestingXCUITests: PSPDFTestCase {
        
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
        //speed = .normal
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

    func testaddAndDeleteBookmark() {
        let fileURL = Bundle.main.bundleURL.appendingPathComponent("PSPDFKit 6 QuickStart Guide.pdf")
        let document = PSPDFDocument(url: fileURL)
        document.uid = NSUUID().uuidString
        if let bookmarkManager = document.bookmarkManager {
            for bookmark in bookmarkManager.bookmarks {
                bookmarkManager.removeBookmark(bookmark)
            }
        }

        let configuration = PSPDFConfiguration() { builder in
            builder.shouldAskForAnnotationUsername = false
        }

        let controller = PSPDFViewController(document:document, configuration:configuration)

        controller.navigationItem.rightBarButtonItems = [controller.bookmarkButtonItem, controller.outlineButtonItem]

        test(with: controller) {
            let app = XCUIApplication()
            let outlineButton = app.navigationBars["PSPDFKit 6 QuickStart Guide"].buttons["Outline"]
            outlineButton.tap()
            app.navigationBars["Outline"].buttons["Bookmarks"].tap()
        
            let tablesQuery = app.tables
            let worldMapStaticText = tablesQuery.staticTexts["Page 1"].swipeLeft()
        }

    }
    
}
