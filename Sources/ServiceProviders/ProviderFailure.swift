import Foundation

protocol ProviderFailure: Error, Sendable {
    var checkFailureReason: CheckFailureReason { get }
}

extension ProviderFailure {
    func checkFailure(at attemptedAt: Date) -> CheckFailure {
        CheckFailure(reason: checkFailureReason, attemptedAt: attemptedAt)
    }
}
