import Foundation

enum AsyncTimeoutError: Error, LocalizedError {
    case timedOut
    
    var errorDescription: String? {
        "Operation timed out. Tap to retry or skip."
    }
}

func withTimeout<T>(
    seconds: TimeInterval = 10,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AsyncTimeoutError.timedOut
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

func withTimeoutOrDefault<T>(
    seconds: TimeInterval = 10,
    defaultValue: T,
    operation: @escaping () async throws -> T
) async -> T {
    do {
        return try await withTimeout(seconds: seconds, operation: operation)
    } catch {
        print("⏰ Operation timed out after \(seconds)s, using default")
        return defaultValue
    }
}
