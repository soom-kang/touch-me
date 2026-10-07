import Foundation

enum AppVersion {
    static var release: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TouchMeReleaseVersion") as? String,
              !value.isEmpty else {
            return "Development build"
        }
        return value
    }
}
