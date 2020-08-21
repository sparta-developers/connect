import Nimble
import Quick
import Testable

class ConnectionMonitorSpec: QuickSpec {
    override func spec() {
        describe(ConnectionMonitor.self) {
            var subject: ConnectionMonitor!
            context(ConnectionMonitor.update(complete:)) {
                context("connected") {
                    beforeEach {
                        subject = .init(url: testBundleUrl("health-check-success.json"))
                    }
                    it("should complete with true") {
                        waitUntil { done in
                            subject.update { connected in
                                expect(connected) == true
                                done()
                            }
                        }
                    }
                }
                context("error") {
                    beforeEach {
                        subject = .init(url: URL(fileURLWithPath: "/tmp/not-found.json"))
                    }
                    it("should complete with false") {
                        waitUntil { done in
                            subject.update { connected in
                                expect(connected) == false
                                done()
                            }
                        }
                    }
                }
            }
        }
    }
}
