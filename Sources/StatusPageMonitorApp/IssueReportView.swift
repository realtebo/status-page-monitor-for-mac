import Foundation
import SwiftUI

enum IssueReportCategory: String, CaseIterable, Identifiable, Sendable {
    case feature = "[FEAT]"
    case bug = "[BUG]"
    case idea = "[IDEA]"
    case howTo = "[HOW-TO]"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .feature:
            "Request a new feature"
        case .bug:
            "Report a bug"
        case .idea:
            "Suggest an idea"
        case .howTo:
            "Ask how to use the app"
        }
    }
}

struct IssueReportDraft: Sendable {
    var category: IssueReportCategory
    var title: String
    var description: String
}

enum IssueReportValidationError: Error, Sendable {
    case emptyTitle
    case emptyDescription
    case invalidRepositoryURL
    case invalidIssueURL
    case browserUnavailable
    case issueURLTooLong

    var message: LocalizedStringKey {
        switch self {
        case .emptyTitle:
            "Enter a title before opening the GitHub issue form."
        case .emptyDescription:
            "Enter a description before opening the GitHub issue form."
        case .invalidRepositoryURL, .invalidIssueURL:
            "The GitHub issue form URL could not be created."
        case .browserUnavailable:
            "The browser could not open the GitHub issue form."
        case .issueURLTooLong:
            "The GitHub issue URL is too long. Shorten the title or description and try again."
        }
    }
}

enum IssueReportURLBuilder {
    static let maximumURLLength = 8_000

    static func makeURL(
        for draft: IssueReportDraft,
        repositoryURL: URL,
        maximumURLLength: Int = Self.maximumURLLength
    ) throws(IssueReportValidationError) -> URL {
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IssueReportValidationError.emptyTitle
        }
        guard !draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IssueReportValidationError.emptyDescription
        }
        guard maximumURLLength > 0,
              var components = URLComponents(url: repositoryURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "github.com"
        else {
            throw IssueReportValidationError.invalidRepositoryURL
        }

        let repositoryPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !repositoryPath.isEmpty else {
            throw IssueReportValidationError.invalidRepositoryURL
        }

        components.path = "/\(repositoryPath)/issues/new"
        components.query = nil
        components.fragment = nil
        components.queryItems = [
            URLQueryItem(name: "title", value: "\(draft.category.rawValue) \(draft.title)"),
            URLQueryItem(name: "body", value: draft.description)
        ]

        // URLComponents leaves literal plus signs unescaped in query values,
        // where GitHub would interpret them as spaces. Escape them after the
        // query items have supplied the remaining URL encoding.
        guard let percentEncodedQuery = components.percentEncodedQuery else {
            throw IssueReportValidationError.invalidIssueURL
        }
        components.percentEncodedQuery = percentEncodedQuery.replacingOccurrences(of: "+", with: "%2B")

        guard let url = components.url else {
            throw IssueReportValidationError.invalidIssueURL
        }
        guard url.absoluteString.utf8.count <= maximumURLLength else {
            throw IssueReportValidationError.issueURLTooLong
        }
        return url
    }
}

struct IssueReportView: View {
    @Binding var draft: IssueReportDraft
    let repositoryURL: URL
    @Environment(\.openURL) private var openURL
    @State private var validationError: IssueReportValidationError?

    var body: some View {
        Section {
            Picker("Category", selection: $draft.category) {
                ForEach(IssueReportCategory.allCases) { category in
                    Text(category.displayName)
                        .tag(category)
                }
            }

            TextField("Title", text: $draft.title)

            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                    .font(.body)
                TextEditor(text: $draft.description)
                    .font(.body)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Description")
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary)
                            .allowsHitTesting(false)
                    }
            }

            Button {
                openIssueForm()
            } label: {
                Label("Continue on GitHub", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.link)

            Text("Review the draft on GitHub and publish it with your account.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let validationError {
                Text(validationError.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("Contact us", systemImage: "exclamationmark.bubble")
        }
    }

    private func openIssueForm() {
        do {
            let url = try IssueReportURLBuilder.makeURL(for: draft, repositoryURL: repositoryURL)
            validationError = nil
            openURL(url) { accepted in
                if !accepted {
                    validationError = .browserUnavailable
                }
            }
        } catch {
            validationError = error
        }
    }
}
