import Foundation
#if canImport(Darwin)
import Darwin
#endif
@testable import OrcaBridgeCore

func jsonLines(_ objects: [[String: Any]]) -> String {
    objects.map { object in
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(data: data, encoding: .utf8)!
    }.joined(separator: "\n")
}

func makeTempSettings(_ contents: [String: Any]?) -> String {
    let path = NSTemporaryDirectory() + "orca-settings-\(UUID().uuidString).json"
    if let contents = contents {
        let data = try! JSONSerialization.data(withJSONObject: contents)
        try! data.write(to: URL(fileURLWithPath: path))
    }
    return path
}

func readJSON(_ path: String) -> [String: Any] {
    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
    return (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
}

struct StubTerminalIdentity: TerminalIdentityResolving {
    let value: TerminalIdentity
    func resolve() -> TerminalIdentity { value }
}

/// Minimal unix-domain socket server that accepts one connection, reads a single
/// newline-delimited message, and hands it back. Used for the send round-trip test.
final class UnixSocketTestServer {
    private let path: String
    private let onLine: (Data) -> Void
    private var listenFD: Int32 = -1

    init(path: String, onLine: @escaping (Data) -> Void) {
        self.path = path
        self.onLine = onLine
    }

    func start() throws {
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.ECONNREFUSED) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: bytes.count) { dst in
                bytes.withUnsafeBufferPointer { src in dst.update(from: src.baseAddress!, count: bytes.count) }
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0, listen(fd, 4) == 0 else {
            close(fd)
            throw POSIXError(.EADDRINUSE)
        }
        listenFD = fd
        Thread.detachNewThread { [weak self] in self?.accept() }
    }

    private func accept() {
        let client = Darwin.accept(listenFD, nil, nil)
        guard client >= 0 else { return }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(client, &chunk, chunk.count)
            if n <= 0 { break }
            buffer.append(contentsOf: chunk[0..<n])
            if let newline = buffer.firstIndex(of: 0x0A) {
                onLine(buffer.subdata(in: buffer.startIndex..<newline))
                break
            }
        }
        close(client)
    }

    func stop() {
        if listenFD >= 0 { close(listenFD) }
        unlink(path)
    }
}
