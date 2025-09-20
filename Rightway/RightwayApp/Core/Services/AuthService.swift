import Combine
import Foundation

protocol AuthService {
    var currentUser: CurrentValueSubject<AuthUser?, Never> { get }
    var hasActiveSession: Bool { get }
    func signInAnonymously()
}

struct AuthUser: Codable, Hashable {
    let id: UUID
    let displayName: String
    let email: String?
}

final class DefaultAuthService: AuthService {
    let currentUser = CurrentValueSubject<AuthUser?, Never>(nil)

    var hasActiveSession: Bool {
        currentUser.value != nil
    }

    func signInAnonymously() {
        let user = AuthUser(id: UUID(), displayName: "Guest", email: nil)
        currentUser.send(user)
    }
}
