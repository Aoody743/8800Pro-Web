import Foundation

public protocol RadioTransport {
    var kind: String { get }
    var label: String { get }
    func open() async throws
    func close() async throws
    func isConnected() -> Bool
    func write(_ data: Data) async throws
    func read(_ length: Int, timeoutMs: Int?) async throws -> Data
    var drain: (() -> Void)? { get }
    var reopen: (() async throws -> Void)? { get }
}
