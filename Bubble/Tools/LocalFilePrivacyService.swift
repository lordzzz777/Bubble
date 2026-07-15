import Foundation

enum LocalFilePrivacyService {
    static func protectCacheFile(at url: URL) throws {
        try protectFile(at: url, excludeFromBackup: true)
    }

    static func protectTemporaryFile(at url: URL) throws {
        try protectFile(at: url, excludeFromBackup: true)
    }

    static func protectUserFile(at url: URL) throws {
        try protectFile(at: url, excludeFromBackup: false)
    }

    static func removeProtectedTemporaryFile(at url: URL?) {
        guard let url, url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func protectFile(at url: URL, excludeFromBackup: Bool) throws {
        try FileManager.default.setAttributes([
            .protectionKey: FileProtectionType.complete
        ], ofItemAtPath: url.path)

        try (url as NSURL).setResourceValue(excludeFromBackup, forKey: URLResourceKey.isExcludedFromBackupKey)
    }
}
