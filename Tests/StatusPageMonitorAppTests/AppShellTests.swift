import Testing
@testable import StatusPageMonitor

@Test func appUsesTheStatusPageMonitorProductName() {
    #expect(AppIdentity.displayName == "Status Page Monitor")
}
