import Foundation

public enum OrcaVersion {
    public static let current = "0.3.3"
    public static let repo = "FatihErtugral/orca"

    /// Numeric, piecewise semver comparison; tolerates a leading "v".
    public static func isNewer(_ remote: String, than local: String = current) -> Bool {
        let remoteParts = components(remote)
        let localParts = components(local)
        let count = max(remoteParts.count, localParts.count)
        for index in 0..<count {
            let r = index < remoteParts.count ? remoteParts[index] : 0
            let l = index < localParts.count ? localParts[index] : 0
            if r != l { return r > l }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: .whitespaces)
            .drop(while: { $0 == "v" || $0 == "V" })
            .split(separator: ".")
            .map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }
}
