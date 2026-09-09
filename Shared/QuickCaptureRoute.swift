import Foundation

enum QuickCaptureRoute {
    static let url = URL(string: "aitextapp://quick-capture")!

    static func matches(_ candidate: URL) -> Bool {
        guard let components = URLComponents(url: candidate, resolvingAgainstBaseURL: false) else {
            return false
        }

        return components.scheme?.lowercased() == url.scheme
            && components.host?.lowercased() == url.host
            && (components.path.isEmpty || components.path == "/")
            && components.query == nil
            && components.fragment == nil
            && components.user == nil
            && components.password == nil
            && components.port == nil
    }
}
