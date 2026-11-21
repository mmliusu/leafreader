import SwiftUI
import UIKit
import PDFKit

struct PDFReaderView: UIViewRepresentable {
    let url: URL
    let pageIndex: Int
    let theme: ReaderTheme
    let onPageChange: (Int, Int) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageBreakMargins = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        view.backgroundColor = UIColor(theme.backgroundColor)
        view.document = PDFDocument(url: url)

        if let document = view.document,
           pageIndex > 0,
           pageIndex < document.pageCount,
           let page = document.page(at: pageIndex) {
            DispatchQueue.main.async {
                view.go(to: page)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: view
        )

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        let background = UIColor(theme.backgroundColor)
        if pdfView.backgroundColor != background {
            pdfView.backgroundColor = background
        }
        if pdfView.document == nil {
            pdfView.document = PDFDocument(url: url)
        }
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator, name: Notification.Name.PDFViewPageChanged, object: view)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PDFReaderView

        init(_ parent: PDFReaderView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let document = view.document,
                  let page = view.currentPage else { return }
            let index = document.index(for: page)
            parent.onPageChange(index, document.pageCount)
        }

        @objc func handleTap() {
            parent.onTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}