import Combine
import Foundation
import SwiftUI

/// The languages that can be used by the app's user interface.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case italian = "it"

    var id: String { rawValue }

    /// The locale used when this language is selected explicitly.
    var localeIdentifier: String {
        switch self {
        case .system:
            "en"
        case .english:
            "en"
        case .italian:
            "it"
        }
    }

    /// A localized key suitable for use as the option's visible label.
    var displayNameKey: LocalizedStringKey {
        switch self {
        case .system:
            "System Default"
        case .english:
            "English"
        case .italian:
            "Italian"
        }
    }
}

/// Stores the user's language preference and resolves the system default.
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    static let languageDefaultsKey = "app.language"

    @Published var selection: AppLanguage {
        didSet {
            guard selection != oldValue else { return }
            defaults.set(selection.rawValue, forKey: Self.languageDefaultsKey)
        }
    }

    private let defaults: UserDefaults
    private let preferredLanguages: [String]

    /// Creates a manager using the persisted preference, or System Default when none exists.
    ///
    /// - Parameters:
    ///   - defaults: The defaults store used for persistence.
    ///   - preferredLanguages: The macOS language preference order. The parameter is injectable
    ///     so callers can verify system-language resolution without changing global settings.
    init(
        defaults: UserDefaults = .standard,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
        let savedValue = defaults.string(forKey: Self.languageDefaultsKey)
        selection = AppLanguage(rawValue: savedValue ?? "") ?? .system
    }

    /// The concrete language currently used by the UI.
    var resolvedLanguage: AppLanguage {
        guard selection == .system else { return selection }
        return Self.language(forPreferredLanguages: preferredLanguages)
    }

    /// The locale to inject into the SwiftUI environment.
    var locale: Locale {
        Locale(identifier: resolvedLanguage.localeIdentifier)
    }

    /// Resolves the first supported language in a macOS preferred-language list.
    ///
    /// Italian is selected for Italian language identifiers. English is the deliberate
    /// default for all other identifiers because it is the app's base localization.
    static func language(forPreferredLanguages preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let languageCode = identifier
                .replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .first
                .map(String.init)
                .map { $0.lowercased() }

            if languageCode == "it" {
                return .italian
            }
            if languageCode == "en" {
                return .english
            }
        }

        return .english
    }

    /// Resolves a localized string using the manager's current locale.
    func localized(_ value: String.LocalizationValue) -> String {
        String(localized: value, locale: locale)
    }
}

/// A compact settings control for selecting the app language.
struct LanguageSettingsView: View {
    @ObservedObject private var localization: LocalizationManager

    init(localization: LocalizationManager = .shared) {
        self.localization = localization
    }

    var body: some View {
        Picker("Language", selection: $localization.selection) {
            ForEach(AppLanguage.allCases) { language in
                Text(language.displayNameKey)
                    .tag(language)
            }
        }
        .pickerStyle(.menu)
    }
}
