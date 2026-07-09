import Foundation

enum ProgressStorage {
    static let appGroupIdentifier = "group.com.openprogress.personal"
    private static let fileName = "progress-items.json"

    static var fileURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return url.appendingPathComponent(fileName)
        }

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return (documents ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent(fileName)
    }

    static func load() -> [ProgressItem] {
        let url = fileURL
        guard let data = try? Data(contentsOf: url) else {
            return seedItems()
        }

        do {
            return try JSONDecoder().decode([ProgressItem].self, from: data)
        } catch {
            return seedItems()
        }
    }

    static func save(_ items: [ProgressItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Unable to save progress items: \(error)")
        }
    }

    static func seedItems() -> [ProgressItem] {
        [
            ProgressItem(
                title: "Information Retrieval",
                icon: "books.vertical.fill",
                startDate: Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now,
                endDate: Calendar.current.date(byAdding: .hour, value: 637, to: .now) ?? .now,
                tintHex: "#A98DD8",
                backgroundHex: "#CDB3F7",
                style: .aqua
            )
        ]
    }
}
