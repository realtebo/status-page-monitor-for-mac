import SwiftUI

enum AppIdentity {
    static let displayName = "Status Page Monitor"
    static let symbolName = "waveform.path.ecg"
    static let dashboardWindowID = "dashboard"
}

@main
struct StatusPageMonitorApp: App {
    var body: some Scene {
        WindowGroup(AppIdentity.displayName, id: AppIdentity.dashboardWindowID) {
            DashboardView()
        }

        MenuBarExtra(AppIdentity.displayName, systemImage: AppIdentity.symbolName) {
            MenuBarPopover()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarPopover: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(AppIdentity.displayName, systemImage: AppIdentity.symbolName)
                .font(.headline)

            Text("Service status will appear here as providers are added.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            Button {
                openWindow(id: AppIdentity.dashboardWindowID)
            } label: {
                Label("Open dashboard", systemImage: "rectangle.inset.filled")
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }
}

private struct DashboardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppIdentity.displayName)
                    .font(.largeTitle.weight(.semibold))

                Text("Monitor the status pages of the services you depend on.")
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: AppIdentity.symbolName)
                    .font(.title2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Provider setup is in progress")
                        .font(.headline)

                    Text("The service list, monitoring controls, and incident details will appear here.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Spacer(minLength: 0)

            Text("The menu bar control stays available when this window is closed.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(minWidth: 620, minHeight: 400)
    }
}
