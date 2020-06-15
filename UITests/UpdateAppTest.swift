import XCTest

enum Timeout: TimeInterval {
    case test = 5
    case launch = 10
    case install = 30
    case network = 60
}

class UpdateAppTest: XCTestCase {
    let tempAppHelper = TempAppHelper()
    lazy var app = tempAppHelper.tempApp()
    let arguments = ["-moveToApplicationsFolderAlertSuppress", "YES"]


    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        tempAppHelper.prepare(for: self)
        tempAppHelper.bundleHelper.clearDefaults()
        tempAppHelper.clearCache()
    }

    override func tearDownWithError() throws {
        app.terminate()
        tempAppHelper.cleanup()
        try super.tearDownWithError()
    }
    
    func checkForUpdatesAndInstall() {
        app.clickStatusItem()
        app.statusBarMenu().menuItems["Check for updates..."].click()
        let updateDialog = app.windows["Software Update"]
        updateDialog.waitToAppear()
        XCTAssertTrue(updateDialog
            .checkBoxes["Automatically download and install updates in the future"]
            .value as! Bool, "should be enabled")
        updateDialog.staticTexts["Initial Release"].waitToAppear()
        updateDialog.buttons["Install Update"].click()
    }
    
    func installAndRelaunch() {
        let updatingWindow = app.windows["Updating SpartaConnect"]
        updatingWindow.waitToAppear()
        updatingWindow.staticTexts["Ready to Install"]
            .waitToAppear(time: .install)
        updatingWindow.buttons["Install and Relaunch"].waitToAppear().click()
        app.wait(until: .notRunning, "wait for app to terminate")
        LaunchService.waitForAppToBeReadyForLaunch(at: tempAppHelper.tempUrl)
        let agent = XCUIApplication(bundleIdentifier: "com.apple.coreservices.uiagent")
        repeat {
            agent.activate()
            let predicate = NSPredicate(format: "title == Open")
            let button = agent.buttons.matching(predicate).element
            if agent.state != .notRunning, button.exists {
                NSLog("agent: " + agent.debugDescription)
                button.click()
            }
        } while !app.wait(for: .runningForeground)
    }
    
    func dismissMoveToApplicationsAlert() {
        let alert = app.waitForMoveAlert()
        alert.buttons["Do Not Move"].click()
        alert.waitToDisappear()
    }
    
    
    func verifyUpdated() {
        app.wait(until: .runningForeground, "wait for app to relaunch")
        app.windows["Window"].waitToAppear(time: .launch)
        app.menuBars.menuBarItems["SpartaConnect"].click()
        app.menuBars.menus.menuItems["About SpartaConnect"].click()
        app.dialogs.staticTexts["Version 1.0 (1.0.3)"].waitToAppear()
        app.dialogs.buttons[XCUIIdentifierCloseWindow].click()
    }
    
    func testAutoUpgrade() throws {
        tempAppHelper.bundleHelper.persistDefaults([
            "SULastCheckTime": Date()
        ])
        tempAppHelper.launch(arguments: arguments)
        app.wait(until: .runningBackground)
        checkForUpdatesAndInstall()
        installAndRelaunch()
        dismissMoveToApplicationsAlert()
        verifyUpdated()
    }
    
    func quitApp() {
        app.activate()
        app.clickStatusItem()
        app.statusBarMenu().menuItems["Quit SpartaConnect"].click()
        app.wait(until: .notRunning, timeout: .install)
    }
    
    func checkUpdateDownloaded() -> NSPredicate {
        tempAppHelper.hasDownloaded(fileName: "SpartaConnect.app")
    }
    
    func waitForUpdatesDownloaded() {
        let downloadComplete = expectation(for: checkUpdateDownloaded(),
                                           evaluatedWith: nil)
        let downloadTimeout = 2 * Timeout.network.rawValue
        wait(for: [downloadComplete], timeout: downloadTimeout)
    }
    
    func waitForUpdatesInstalled() {
        let downloadedDeleted = NSCompoundPredicate(
            notPredicateWithSubpredicate: checkUpdateDownloaded()
        )
        let expectDownload = expectation(for: downloadedDeleted, evaluatedWith: nil)
        wait(for: [expectDownload], timeout: Timeout.install.rawValue)
    }
    
    func checkForUpdatesAndInstallOnQuit() {
        app.clickStatusItem()
        app.statusBarMenu().menuItems["Check for updates..."].click()
        let popup = app.windows.containing(.button, identifier:"Install and Relaunch").element
        popup.waitToAppear()

        XCTAssertTrue(popup
            .staticTexts["A new version of SpartaConnect is ready to install!"].exists)
        XCTAssertTrue(popup.buttons["Don't Install"].exists)
        popup.buttons["Install on Quit"].click()
        popup.waitToDisappear()
    }

    
    func testUpgradeOnQuit() {
        tempAppHelper.launch(arguments: arguments)
        app.wait(until: .runningBackground)
        waitForUpdatesDownloaded()
        checkForUpdatesAndInstallOnQuit()
        quitApp()
        waitForUpdatesInstalled()
        tempAppHelper.launch(arguments: arguments)
        app.wait(until: .runningForeground)
        verifyUpdated()
    }
}
