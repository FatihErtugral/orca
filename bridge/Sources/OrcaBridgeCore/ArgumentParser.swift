import Foundation

public struct ParsedArguments: Equatable {
    public let flags: [String: String]
    public let rest: [String]
}

/// Parses `--flag value` pairs. Everything after a lone `--` is captured as the
/// passthrough command in `rest` (used by `wrap`).
public enum ArgumentParser {
    public static func parse(_ args: [String]) -> ParsedArguments {
        var flags: [String: String] = [:]
        var rest: [String] = []
        var index = 0
        while index < args.count {
            let arg = args[index]
            if arg == "--" {
                rest = Array(args[(index + 1)...])
                break
            }
            if arg.hasPrefix("--") {
                let key = String(arg.dropFirst(2))
                if index + 1 < args.count, !args[index + 1].hasPrefix("--") {
                    flags[key] = args[index + 1]
                    index += 2
                    continue
                }
                flags[key] = ""
            }
            index += 1
        }
        return ParsedArguments(flags: flags, rest: rest)
    }
}
