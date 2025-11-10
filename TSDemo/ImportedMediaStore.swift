import Foundation

/// 已导入媒体类型
enum ImportedMediaType: CaseIterable {
    case image
    case video
    case audio
    
    var directoryName: String {
        switch self {
        case .image:
            return "Images"
        case .video:
            return "Videos"
        case .audio:
            return "Audios"
        }
    }
}

/// 本地已导入媒体存储管理
final class ImportedMediaStore {
    static let shared = ImportedMediaStore()
    
    private let fileManager = FileManager.default
    private let baseURL: URL
    
    private init() {
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            baseURL = documentsURL.appendingPathComponent("ImportedMedia", isDirectory: true)
        } else {
            baseURL = fileManager.temporaryDirectory.appendingPathComponent("ImportedMedia", isDirectory: true)
        }
        createDirectoriesIfNeeded()
    }
    
    /// 获取指定类型媒体文件名称列表（按名称排序）
    func fileNames(for type: ImportedMediaType) -> [String] {
        let directoryURL = directoryURL(for: type)
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            return contents
                .filter { !$0.hasDirectoryPath }
                .map { $0.lastPathComponent }
                .sorted()
        } catch {
            print("[ImportedMediaStore] 列取失败 - type: \(type), error: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 保存媒体文件到指定类型目录
    func save(data: Data, fileName: String, type: ImportedMediaType) throws {
        let safeName = sanitizedFileName(fileName)
        let directory = directoryURL(for: type)
        let fileURL = directory.appendingPathComponent(safeName, isDirectory: false)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try data.write(to: fileURL, options: .atomic)
    }
    
    // MARK: - Private
    private func createDirectoriesIfNeeded() {
        do {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
            for type in ImportedMediaType.allCases {
                let directory = directoryURL(for: type)
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        } catch {
            print("[ImportedMediaStore] 创建目录失败: \(error.localizedDescription)")
        }
    }
    
    private func directoryURL(for type: ImportedMediaType) -> URL {
        return baseURL.appendingPathComponent(type.directoryName, isDirectory: true)
    }
    
    private func sanitizedFileName(_ fileName: String) -> String {
        let lastComponent = (fileName as NSString).lastPathComponent
        let cleaned = lastComponent.replacingOccurrences(of: "..", with: "_")
        return cleaned.isEmpty ? UUID().uuidString : cleaned
    }
}

