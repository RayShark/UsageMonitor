import Foundation

package struct UpdateReleaseInfo: Equatable {
    package let version: AppVersion
    package let isPrerelease: Bool
    package let publishedAt: Date?
    package let releaseURL: URL
    package let downloadURL: URL

    package init(
        version: AppVersion,
        isPrerelease: Bool,
        publishedAt: Date?,
        releaseURL: URL,
        downloadURL: URL
    ) {
        self.version = version
        self.isPrerelease = isPrerelease
        self.publishedAt = publishedAt
        self.releaseURL = releaseURL
        self.downloadURL = downloadURL
    }

    package var versionText: String {
        version.displayText
    }
}

package enum UpdateCheckFailure: Equatable {
    case invalidResponse
    case network

    package var userMessage: String {
        switch self {
        case .invalidResponse:
            return "更新信息格式异常"
        case .network:
            return "检查更新失败，请稍后重试"
        }
    }
}

package enum UpdateCheckResult: Equatable {
    case upToDate
    case updateAvailable(UpdateReleaseInfo)
    case failure(UpdateCheckFailure)

    package var statusText: String {
        switch self {
        case .upToDate:
            return "已是最新版"
        case let .updateAvailable(info):
            if info.isPrerelease {
                return "发现测试版 \(info.versionText)"
            }
            return "发现新版本 \(info.versionText)"
        case let .failure(failure):
            return failure.userMessage
        }
    }

    package var downloadURL: URL? {
        switch self {
        case .upToDate, .failure:
            return nil
        case let .updateAvailable(info):
            return info.downloadURL
        }
    }
}

package struct UpdateChecker {
    private let client: GitHubReleaseProviding
    private let currentVersionProvider: () -> AppVersion?

    package init(
        client: GitHubReleaseProviding = GitHubReleaseClient(),
        currentVersion: AppVersion? = nil,
        bundle: Bundle = .main
    ) {
        self.client = client
        if let currentVersion {
            currentVersionProvider = { currentVersion }
        } else {
            currentVersionProvider = {
                let rawVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                return rawVersion.flatMap { AppVersion.parse($0) }
            }
        }
    }

    package func checkForUpdate(includePrereleases: Bool) async -> UpdateCheckResult {
        guard let currentVersion = currentVersionProvider() else {
            return .failure(.invalidResponse)
        }

        do {
            let releases = try await client.fetchReleases()
            let candidates = releases.compactMap { release -> UpdateReleaseInfo? in
                guard !release.draft else { return nil }
                guard includePrereleases || !release.prerelease else { return nil }
                guard let releaseVersion = release.version else { return nil }
                guard releaseVersion > currentVersion else { return nil }
                return UpdateReleaseInfo(
                    version: releaseVersion,
                    isPrerelease: release.prerelease,
                    publishedAt: release.publishedAt,
                    releaseURL: release.htmlURL,
                    downloadURL: release.downloadURL
                )
            }

            guard let bestCandidate = candidates.sorted(by: { $0.version < $1.version }).last else {
                return .upToDate
            }
            return .updateAvailable(bestCandidate)
        } catch let error as GitHubReleaseClientError {
            switch error {
            case .invalidResponse, .decoding:
                return .failure(.invalidResponse)
            case .httpStatus, .network:
                return .failure(.network)
            }
        } catch {
            return .failure(.network)
        }
    }
}
