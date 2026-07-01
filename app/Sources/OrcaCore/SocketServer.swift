import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Listens on a unix domain socket for newline-delimited `AgentEvent` JSON.
/// Decoded events are delivered on a background queue; the caller hops to main.
public final class SocketServer {
    public static var defaultPath: String {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Orca/orca.sock")
            .path
    }

    private let path: String
    private let onEvent: (AgentEvent) -> Void
    private let acceptQueue = DispatchQueue(label: "orca.socket.accept", qos: .utility)
    private let clientQueue = DispatchQueue(label: "orca.socket.client", qos: .utility, attributes: .concurrent)
    private var running = false

    public init(path: String = SocketServer.defaultPath, onEvent: @escaping (AgentEvent) -> Void) {
        self.path = path
        self.onEvent = onEvent
    }

    public func start() {
        acceptQueue.async { [weak self] in self?.run() }
    }

    private func run() {
        let directory = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= capacity else { close(fd); return }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                pathBytes.withUnsafeBufferPointer { src in
                    dst.update(from: src.baseAddress!, count: pathBytes.count)
                }
            }
        }

        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0, listen(fd, 16) == 0 else { close(fd); return }

        running = true
        while running {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if running { continue } else { break }
            }
            clientQueue.async { [weak self] in self?.handleClient(client) }
        }
        close(fd)
    }

    private func handleClient(_ client: Int32) {
        defer { close(client) }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(client, &chunk, chunk.count)
            if n <= 0 { break }
            buffer.append(contentsOf: chunk[0..<n])
            while let newline = buffer.firstIndex(of: 0x0A) {
                process(buffer.subdata(in: buffer.startIndex..<newline))
                buffer.removeSubrange(buffer.startIndex...newline)
            }
        }
        if !buffer.isEmpty { process(buffer) }
    }

    private func process(_ data: Data) {
        guard !data.isEmpty, let event = try? JSONDecoder().decode(AgentEvent.self, from: data) else { return }
        onEvent(event)
    }
}
