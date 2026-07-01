import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Sends events to the app over a unix domain socket. Fire-and-forget: if the
/// app is not running the connection fails and the caller is unaffected.
public struct SocketClient {
    public let path: String

    public init(path: String = SocketClient.defaultPath) {
        self.path = path
    }

    public static var defaultPath: String {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Orca/orca.sock")
            .path
    }

    @discardableResult
    public func send(_ event: AgentEvent) -> Bool {
        guard var data = try? JSONEncoder().encode(event) else { return false }
        data.append(0x0A)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= capacity else { return false }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                pathBytes.withUnsafeBufferPointer { src in
                    dst.update(from: src.baseAddress!, count: pathBytes.count)
                }
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
        }
        guard connected == 0 else { return false }

        return data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return false }
            return write(fd, base, data.count) == data.count
        }
    }
}
