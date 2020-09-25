import XCTest

enum Timeout: TimeInterval {
    case test = 5
    case launch = 10
    case install = 30
    case network = 120
}

class UpdateAppTest: XCTestCase {
    let tempAppHelper = TempAppHelper()
    lazy var app = tempAppHelper.tempApp()
    let arguments = ["-moveToApplicationsFolderAlertSuppress", "YES"]

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        executionTimeAllowance = 200
        try tempAppHelper.skipForOtherTeams()
        tempAppHelper.prepare(for: self)
        tempAppHelper.bundleHelper.clearDefaults()
        tempAppHelper.clearCache()
    }

    override func tearDownWithError() throws {
        if testRun?.hasBeenSkipped == false {
            app.terminate()
        }
        if let run = testRun, run.totalFailureCount == 0, run.skipCount == 0 {
            tempAppHelper.cleanup()
        }
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
        tempAppHelper.verifyAppRegistedToLaunch()
        tempAppHelper.waitForAppToLaunchDismissingFirstTimeOpenAlerts(app: app)
        app.activate()
    }

    func verifyUpdated() {
        app.wait(until: .runningForeground, "wait for app to relaunch")
        app.windows["Connect to Sparta Science"].waitToAppear(time: .launch)
        app.menuBars.menuBarItems["SpartaConnect"].click()
        app.menuBars.menus.menuItems["About SpartaConnect"].click()
        app.dialogs.staticTexts["Version 100.0.3 (100.0.3)"].waitToAppear()
        app.dialogs.buttons[XCUIIdentifierCloseWindow].click()
    }

    func dismissMainWindowAsAWorkaroundUpdateWindowNotFound() {
        app.buttons["Done"].click()
        app.wait(until: .runningBackground)
    }

    func preventAutomaticDownloadOfUpdates() {
        tempAppHelper.bundleHelper.persistDefaults([
            "SULastCheckTime": Date()
        ])
    }

    func testAutoUpgrade() throws {
        preventAutomaticDownloadOfUpdates()
        tempAppHelper.launch(arguments: arguments)
        dismissMainWindowAsAWorkaroundUpdateWindowNotFound()
        app.activate()
        checkForUpdatesAndInstall()
        installAndRelaunch()
        app.respondToMoveAlert("Do Not Move")
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
        tempAppHelper.syncFileSystem()
    }

    func waitForUpdatesInstalled() {
        waitForAppToStartAndTerminate(
            bundleId: "org.sparkle-project.Sparkle.Autoupdate",
            timeout: .install
        )
        tempAppHelper.syncFileSystem()
        tempAppHelper.verifyAppRegistedToLaunch()
    }

    func checkForUpdatesAndInstallOnQuit() {
        app.clickStatusItem()
        app.statusBarMenu().menuItems["Check for updates..."].click()
        let popup = app.windows.containing(.button, identifier: "Install and Relaunch").element
        popup.waitToAppear()

        XCTAssertTrue(popup
            .staticTexts["A new version of SpartaConnect is ready to install!"].exists)
        XCTAssertTrue(popup.buttons["Don't Install"].exists)
        popup.buttons["Install on Quit"].click()
        popup.waitToDisappear()
    }

    func testUpgradeOnQuit() {
        tempAppHelper.launch(arguments: arguments)
        waitForUpdatesDownloaded()
        checkForUpdatesAndInstallOnQuit()
        quitApp()
        waitForUpdatesInstalled()
        tempAppHelper.launch(arguments: arguments)
        verifyUpdated()
    }
}
