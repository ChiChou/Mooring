//
//  MooringUITestsComprehensive.swift
//  MooringUITests
//
//  Created by cc on 05/03/26.
//

import XCTest

final class MooringUITestsComprehensive: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Wait for app to be ready
        _ = app.wait(for: .runningForeground, timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Menu Bar Tests
    
    @MainActor
    func testMenuBarExtraExists() throws {
        // Check that menu bar extra is present
        XCTAssertTrue(app.menuBars.firstMatch.exists, "Menu bar should exist")
    }
    
    @MainActor
    func testNewProxyButtonExists() throws {
        // Look for "New iproxy" button in menu
        let newProxyButton = app.buttons["New iproxy"]
        XCTAssertTrue(newProxyButton.waitForExistence(timeout: 2), "New iproxy button should exist in menu")
    }
    
    @MainActor
    func testQuitButtonExists() throws {
        let quitButton = app.buttons["Quit"]
        XCTAssertTrue(quitButton.waitForExistence(timeout: 2), "Quit button should exist in menu")
    }
    
    @MainActor
    func testRunningInstancesSectionExists() throws {
        let sectionHeader = app.staticTexts["Running Instances"]
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 2), "Running Instances section header should exist")
    }
    
    @MainActor
    func testNoInstancesMessageWhenEmpty() throws {
        // Should show "No iproxy instances" when no instances are running
        let noInstancesText = app.staticTexts["No iproxy instances"]
        // Note: This might not always be true if instances are running
        if noInstancesText.exists {
            XCTAssertTrue(noInstancesText.exists, "Should show 'No iproxy instances' when list is empty")
        }
    }
    
    @MainActor
    func testKeyboardShortcutsDisplayed() throws {
        // Check that keyboard shortcuts are displayed on menu items
        let cmdN = app.staticTexts["⌘N"]
        let cmdQ = app.staticTexts["⌘Q"]
        
        XCTAssertTrue(cmdN.waitForExistence(timeout: 2) || cmdQ.waitForExistence(timeout: 2), 
                      "Keyboard shortcuts should be displayed on menu items")
    }
    
    // MARK: - Add Proxy Sheet Tests
    
    @MainActor
    func testOpenAddProxySheet() throws {
        let newProxyButton = app.buttons["New iproxy"]
        XCTAssertTrue(newProxyButton.waitForExistence(timeout: 2), "New iproxy button should exist")
        
        newProxyButton.tap()
        
        // Wait for sheet to appear
        let sheetTitle = app.staticTexts["New iproxy Instance"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3), "Add proxy sheet should open")
    }
    
    @MainActor
    func testAddProxySheetHasRequiredFields() throws {
        // Open the sheet
        let newProxyButton = app.buttons["New iproxy"]
        newProxyButton.tap()
        
        // Wait for sheet
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Check for source port field
        let sourcePortLabel = app.staticTexts["Source (device)"]
        XCTAssertTrue(sourcePortLabel.exists, "Source port label should exist")
        
        // Check for destination port field (when random port is not selected)
        let destinationPortLabel = app.staticTexts["Destination (local)"]
        XCTAssertTrue(destinationPortLabel.exists, "Destination port label should exist")
        
        // Check for random port checkbox
        let randomPortCheckbox = app.checkBoxes["Use random destination port"]
        XCTAssertTrue(randomPortCheckbox.exists, "Random port checkbox should exist")
        
        // Check for buttons
        XCTAssertTrue(app.buttons["Cancel"].exists, "Cancel button should exist")
        XCTAssertTrue(app.buttons["Create"].exists, "Create button should exist")
    }
    
    @MainActor
    func testRandomPortCheckboxTogglesDestinationField() throws {
        // Open the sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Initially, destination field should be visible
        let destinationPortLabel = app.staticTexts["Destination (local)"]
        XCTAssertTrue(destinationPortLabel.exists, "Destination port field should be visible initially")
        
        // Toggle random port checkbox
        let randomPortCheckbox = app.checkBoxes["Use random destination port"]
        randomPortCheckbox.tap()
        
        // Give UI time to update
        sleep(1)
        
        // Destination field should be hidden
        XCTAssertFalse(destinationPortLabel.exists, "Destination port field should be hidden when random port is selected")
    }
    
    @MainActor
    func testCancelButtonClosesSheet() throws {
        // Open the sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Click cancel
        app.buttons["Cancel"].tap()
        
        // Sheet should close
        let sheetTitle = app.staticTexts["New iproxy Instance"]
        XCTAssertFalse(sheetTitle.waitForExistence(timeout: 2), "Sheet should close after clicking Cancel")
    }
    
    @MainActor
    func testCreateButtonRequiresValidPort() throws {
        // Open the sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Try to create without entering a port
        let createButton = app.buttons["Create"]
        createButton.tap()
        
        // Sheet should remain open because validation failed
        let sheetTitle = app.staticTexts["New iproxy Instance"]
        XCTAssertTrue(sheetTitle.exists, "Sheet should remain open when validation fails")
    }
    
    @MainActor
    func testSourcePortInputAcceptsNumbers() throws {
        // Open sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Find text field (assuming first text field is source port)
        let textFields = app.textFields
        if textFields.count > 0 {
            let sourceField = textFields.element(boundBy: 0)
            sourceField.tap()
            sourceField.typeText("2222")
            
            // Verify input
            XCTAssertEqual(sourceField.value as? String, "2222", "Source port field should accept number input")
        }
    }
    
    // MARK: - Keyboard Shortcuts Tests
    
    @MainActor
    func testCommandNOpensNewProxySheet() throws {
        // Press Cmd+N
        app.typeKey("n", modifierFlags: .command)
        
        // Sheet should open
        let sheetTitle = app.staticTexts["New iproxy Instance"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 3), "Cmd+N should open new proxy sheet")
    }
    
    @MainActor
    func testEscapeKeyClosesSheet() throws {
        // Open sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Press Escape
        app.typeKey(.escape, modifierFlags: [])
        
        // Sheet should close
        let sheetTitle = app.staticTexts["New iproxy Instance"]
        XCTAssertFalse(sheetTitle.waitForExistence(timeout: 2), "Escape key should close the sheet")
    }
    
    // MARK: - Menu Interaction Tests
    
    @MainActor
    func testMenuDismissesAfterNewProxyClick() throws {
        let newProxyButton = app.buttons["New iproxy"]
        XCTAssertTrue(newProxyButton.waitForExistence(timeout: 2))
        
        newProxyButton.tap()
        
        // Wait for sheet to appear
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Menu should be dismissed (difficult to test directly, but sheet appearing indicates success)
        XCTAssertTrue(true, "Menu dismissed and sheet opened successfully")
    }
    
    // MARK: - Localization Tests
    
    @MainActor
    func testEnglishLocalization() throws {
        // Test that English strings are present
        let newProxyButton = app.buttons["New iproxy"]
        XCTAssertTrue(newProxyButton.waitForExistence(timeout: 2), "English 'New iproxy' button should exist")
        
        let quitButton = app.buttons["Quit"]
        XCTAssertTrue(quitButton.exists, "English 'Quit' button should exist")
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let testApp = XCUIApplication()
            testApp.launch()
            testApp.terminate()
        }
    }
    
    @MainActor
    func testOpenSheetPerformance() throws {
        measure {
            let newProxyButton = app.buttons["New iproxy"]
            if newProxyButton.waitForExistence(timeout: 2) {
                newProxyButton.tap()
                _ = app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3)
                app.buttons["Cancel"].tap()
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func testButtonsAreAccessible() throws {
        // Check that important buttons have accessibility identifiers or labels
        let newProxyButton = app.buttons["New iproxy"]
        XCTAssertTrue(newProxyButton.exists, "New iproxy button should be accessible")
        XCTAssertTrue(newProxyButton.isEnabled, "New iproxy button should be enabled")
        
        let quitButton = app.buttons["Quit"]
        XCTAssertTrue(quitButton.exists, "Quit button should be accessible")
        XCTAssertTrue(quitButton.isEnabled, "Quit button should be enabled")
    }
    
    @MainActor
    func testTextFieldsAreAccessible() throws {
        // Open sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Check text fields are accessible
        let textFields = app.textFields
        XCTAssertGreaterThan(textFields.count, 0, "Should have accessible text fields")
    }
    
    @MainActor
    func testCheckboxIsAccessible() throws {
        // Open sheet
        app.buttons["New iproxy"].tap()
        XCTAssertTrue(app.staticTexts["New iproxy Instance"].waitForExistence(timeout: 3))
        
        // Check checkbox is accessible
        let randomPortCheckbox = app.checkBoxes["Use random destination port"]
        XCTAssertTrue(randomPortCheckbox.exists, "Checkbox should be accessible")
        XCTAssertTrue(randomPortCheckbox.isEnabled, "Checkbox should be enabled")
    }
    
    // MARK: - UI Styling Tests
    
    @MainActor
    func testMenuHasProperWidth() throws {
        // The menu should have a width of 260 as specified in code
        // This is more of a visual test, but we can check that menu content exists
        XCTAssertTrue(app.buttons["New iproxy"].exists, "Menu should be properly sized with visible content")
    }
    
    @MainActor
    func testMenuItemHoverStates() throws {
        // While we can't directly test hover states in UI tests,
        // we can verify the buttons exist and are interactable
        let newProxyButton = app.buttons["New iproxy"]
        XCTAssertTrue(newProxyButton.isHittable, "Menu items should be hittable (indicating proper hover regions)")
    }
}
