import SwiftUI
import UIKit

struct BookCard: View {
    let book: Book
    @EnvironmentObject private var library: LibraryStore
    @State private var cover: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            coverView
            Text(book.title)
                .font(AppFont.footnote)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(book.displayAuthor)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(book.progressText)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onAppear(perform: loadCover)
    }

    private var coverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = cover {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: book.format.symbolName)
                        .font(.system(size: 24, weight: .light))
                    Text(book.format.displayName)
                        .font(AppFont.caption2)
                }
                .foregroundStyle(.white.opacity(0.92))
            }
        }
        .aspectRatio(0.68, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            if book.progress > 0.001 {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.black.opacity(0.22))
                        Rectangle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: proxy.size.width * CGFloat(book.progress))
                    }
                }
                .frame(height: 3)
                .clipShape(Capsule())
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 3)
    }

    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "#2F4858"), Color(hex: "#33658A")],
            [Color(hex: "#5B3A29"), Color(hex: "#8C5E3C")],
            [Color(hex: "#3C3B54"), Color(hex: "#6D5C7B")],
            [Color(hex: "#254E45"), Color(hex: "#3F7A62")],
            [Color(hex: "#4A2C2A"), Color(hex: "#7E4A46")]
        ]
        let total = book.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palettes[total % palettes.count]
    }

    private func loadCover() {
        guard cover == nil, let url = library.coverURL(for: book) else { return }
        cover = UIImage(contentsOfFile: url.path)
    }
}