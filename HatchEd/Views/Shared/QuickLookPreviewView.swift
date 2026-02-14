//
//  QuickLookPreviewView.swift
//  HatchEd
//
//  Presents a file (PDF, image, etc.) with native image/PDF/text viewers or Quick Look.
//

import SwiftUI
import UIKit
import QuickLook
import PDFKit

// MARK: - Type-specific preview (image / PDF / text / Quick Look)
struct ResourcePreviewView: View {
    let url: URL
    var resourceType: ResourceType?
    var onDismiss: (() -> Void)?

    private var fileExtension: String { url.pathExtension.lowercased() }

    var body: some View {
        Group {
            if resourceType == .photo {
                ImagePreviewView(url: url, onDismiss: onDismiss)
            } else if fileExtension == "pdf" {
                PDFPreviewView(url: url, onDismiss: onDismiss)
            } else if ["txt", "text", "md", "json", "xml", "html", "htm"].contains(fileExtension) {
                TextFilePreviewView(url: url, onDismiss: onDismiss)
            } else {
                QuickLookPreviewView(url: url, onDismiss: onDismiss)
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Native image viewer (shows actual image)
struct ImagePreviewView: View {
    let url: URL
    var onDismiss: (() -> Void)?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding()
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else {
            image = nil
            return
        }
        image = uiImage
    }
}

// MARK: - Native PDF viewer (shows actual PDF content)
struct PDFPreviewView: View {
    let url: URL
    var onDismiss: (() -> Void)?
    @State private var document: PDFDocument?

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            if let document = document {
                PDFKitRepresentable(document: document)
                    .ignoresSafeArea()
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .onAppear {
            document = PDFDocument(url: url)
        }
    }
}

private struct PDFKitRepresentable: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = document
    }
}

// MARK: - Plain text viewer (for .txt, .md, etc.)
struct TextFilePreviewView: View {
    let url: URL
    var onDismiss: (() -> Void)?
    @State private var text: String = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .onAppear {
            text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .utf16)) ?? "Could not load text."
        }
    }
}

// MARK: - Quick Look (fallback for other file types)
struct QuickLookPreviewView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> QLPreviewController {
        let ql = QLPreviewController()
        ql.dataSource = context.coordinator
        ql.delegate = context.coordinator
        return ql
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.previewURL = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var previewURL: URL
        var onDismiss: (() -> Void)?

        init(url: URL, onDismiss: (() -> Void)?) {
            self.previewURL = url
            self.onDismiss = onDismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            previewURL as NSURL
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            onDismiss?()
        }
    }
}
