import Foundation
import Combine

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case korean = "ko"

    var label: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        }
    }
}

final class LanguagePreferences: ObservableObject {
    static let shared = LanguagePreferences()
    private static let key = "io.github.soom-kang.touchme.language.v1"
    private let defaults: UserDefaults

    @Published var selected: AppLanguage {
        didSet {
            guard selected != oldValue else { return }
            defaults.set(selected.rawValue, forKey: Self.key)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = defaults.string(forKey: Self.key).flatMap(AppLanguage.init(rawValue:)) ?? .english
    }
}
