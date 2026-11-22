import Foundation

struct Bookmark: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var chapterIndex: Int
    var chapterTitle: String
    var progress: Double = 0
    var pageIndex: Int = 0
    var createdAt: Date = Date()

    var positionLabel: String {
        if pageIndex > 0 { return "第 \(pageIndex + 1) 页" }
        let percent = Int((progress * 100).rounded())
        return percent <= 0 ? "章首" : "\(percent)%"
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }
}