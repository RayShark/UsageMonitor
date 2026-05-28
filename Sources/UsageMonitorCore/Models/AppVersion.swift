import Foundation

package struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    package enum PrereleaseIdentifier: Comparable, Equatable {
        case numeric(Int)
        case text(String)

        package static func < (lhs: PrereleaseIdentifier, rhs: PrereleaseIdentifier) -> Bool {
            switch (lhs, rhs) {
            case let (.numeric(lhsValue), .numeric(rhsValue)):
                return lhsValue < rhsValue
            case (.numeric, .text):
                return true
            case (.text, .numeric):
                return false
            case let (.text(lhsValue), .text(rhsValue)):
                return lhsValue < rhsValue
            }
        }
    }

    package let major: Int
    package let minor: Int
    package let patch: Int
    package let prereleaseIdentifiers: [PrereleaseIdentifier]

    package var description: String {
        displayText
    }

    package var displayText: String {
        var text = "v\(major).\(minor).\(patch)"
        if !prereleaseIdentifiers.isEmpty {
            text += "-\(prereleaseIdentifiers.map(\.displayText).joined(separator: "."))"
        }
        return text
    }

    package var isPrerelease: Bool {
        !prereleaseIdentifiers.isEmpty
    }

    package static func parse(_ rawValue: String) -> AppVersion? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let versionAndBuild = normalized.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        guard let versionPart = versionAndBuild.first, !versionPart.isEmpty else { return nil }

        let components = versionPart.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let coreParts = components[0].split(separator: ".", omittingEmptySubsequences: false)
        guard
            coreParts.count == 3,
            let major = Int(coreParts[0]),
            let minor = Int(coreParts[1]),
            let patch = Int(coreParts[2])
        else {
            return nil
        }

        let prereleaseIdentifiers: [PrereleaseIdentifier]
        if components.count == 2 {
            let prereleasePart = components[1]
            guard !prereleasePart.isEmpty else { return nil }
            let rawIdentifiers = prereleasePart.split(separator: ".", omittingEmptySubsequences: false)
            guard !rawIdentifiers.isEmpty, rawIdentifiers.allSatisfy({ !$0.isEmpty }) else {
                return nil
            }

            prereleaseIdentifiers = rawIdentifiers.map { identifier in
                if let numeric = Int(identifier), String(numeric) == identifier {
                    return .numeric(numeric)
                }
                return .text(String(identifier))
            }
        } else {
            prereleaseIdentifiers = []
        }

        return AppVersion(
            major: major,
            minor: minor,
            patch: patch,
            prereleaseIdentifiers: prereleaseIdentifiers
        )
    }

    package static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        switch (lhs.prereleaseIdentifiers.isEmpty, rhs.prereleaseIdentifiers.isEmpty) {
        case (true, true):
            return false
        case (true, false):
            return false
        case (false, true):
            return true
        case (false, false):
            for (lhsIdentifier, rhsIdentifier) in zip(lhs.prereleaseIdentifiers, rhs.prereleaseIdentifiers) {
                if lhsIdentifier == rhsIdentifier {
                    continue
                }
                return lhsIdentifier < rhsIdentifier
            }
            return lhs.prereleaseIdentifiers.count < rhs.prereleaseIdentifiers.count
        }
    }
}

private extension AppVersion.PrereleaseIdentifier {
    var displayText: String {
        switch self {
        case let .numeric(value):
            return String(value)
        case let .text(value):
            return value
        }
    }
}
