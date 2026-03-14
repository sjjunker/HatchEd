//
//  PortfolioDetailView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import SwiftUI
import PDFKit
import UIKit

struct PortfolioDetailView: View {
    let portfolio: Portfolio
    var isStudent: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var showingShareSheet = false
    @State private var showingStyleSelection = false
    @State private var pendingPDFAction: PDFAction? = nil
    @State private var selectedStyle: PDFStyle = .professional

    private var designAccent: Color {
        portfolio.designPattern.accentColor
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header — design-pattern accent, stronger hierarchy
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(designAccent)
                                .frame(width: 4)
                                .padding(.leading, -4)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(portfolio.studentName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.hatchEdText)
                                if portfolio.designPattern != .general {
                                    Text(portfolio.designPattern.rawValue + " Portfolio")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(designAccent)
                                }
                                if let createdAt = portfolio.createdAt {
                                    Text("Created \(createdAt.formatted(date: .long, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.hatchEdCardBackground)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    )
                    
                    // Compiled Content (includes Remarks section)
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Portfolio Content")
                        PortfolioContentView(portfolio: portfolio, designAccent: designAccent)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.hatchEdCardBackground)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    )
                }
                .padding()
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingStyleSelection = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = pdfData {
                    ShareSheet(activityItems: [pdfData])
                }
            }
            .sheet(isPresented: $showingStyleSelection) {
                PDFStyleSelectionSheet(selectedStyle: $selectedStyle, onPrint: {
                    showingStyleSelection = false
                    pendingPDFAction = .print
                    Task { await generatePDF() }
                }, onShare: {
                    showingStyleSelection = false
                    pendingPDFAction = .share
                    Task { await generatePDF() }
                }, onCancel: {
                    showingStyleSelection = false
                })
            }
        }
    }

    private func portfolioSectionCard(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title)
            Text(content)
                .font(.body)
                .foregroundColor(.hatchEdText)
                .lineSpacing(6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundColor(.hatchEdText)
    }
    
    @MainActor
    private func generatePDF() async {
        // Pre-load all images asynchronously before PDF generation
        var imageCache: [String: UIImage] = [:]
        
        // Load each image from database via GET /api/portfolios/images/:id (no URLs stored)
        let api = APIClient.shared
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for image in portfolio.generatedImages {
                group.addTask {
                    let imageId = image.id
                    guard imageId.count == 24, !imageId.hasPrefix("fallback-"), !imageId.hasPrefix("missing-"), !imageId.hasPrefix("failed-") else {
                        return (imageId, nil)
                    }
                    let url = api.portfolioImageURL(imageId: imageId)
                    do {
                        var request = URLRequest(url: url)
                        request.setValue("image/*", forHTTPHeaderField: "Accept")
                        if let token = api.getAuthToken() {
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                              let uiImage = UIImage(data: data) else {
                            return (imageId, nil)
                        }
                        return (imageId, uiImage)
                    } catch {
                        return (imageId, nil)
                    }
                }
            }
            for await (imageId, image) in group {
                if let image = image {
                    imageCache[imageId] = image
                }
            }
        }
        
        print("[PDF] Image cache populated with \(imageCache.count) images out of \(portfolio.generatedImages.count) total")
        
        // Create PDF from portfolio content with selected style and pre-loaded images
        let pdfCreator = PDFCreator()
        let data = pdfCreator.createPDF(from: portfolio, style: selectedStyle, imageCache: imageCache)
        pdfData = data
        
        switch pendingPDFAction {
        case .print:
            pendingPDFAction = nil
            presentPrintController(with: data)
        case .share:
            pendingPDFAction = nil
            showingShareSheet = true
        case .none:
            showingShareSheet = true
        }
    }
    
    private func presentPrintController(with data: Data) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Portfolio"
        printInfo.orientation = .portrait
        printInfo.duplex = .none
        printController.printInfo = printInfo
        printController.showsNumberOfCopies = false
        printController.showsPaperSelectionForLoadedPapers = false
        printController.printingItem = data
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootViewController = window.rootViewController {
            var top = rootViewController
            while let presented = top.presentedViewController { top = presented }
            let rect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            printController.present(from: rect, in: top.view, animated: true, completionHandler: nil)
        } else {
            printController.present(animated: true, completionHandler: nil)
        }
    }
}

// Renders portfolio compiled content with inline images (AI-generated + user-provided from studentWorkFiles)
private struct PortfolioContentView: View {
    let portfolio: Portfolio
    var designAccent: Color = .hatchEdAccent
    
    /// Splits content by [IMAGE] and pairs segments with generatedImages by order.
    private var segments: [(text: String, imageId: String?)] {
        let parts = portfolio.compiledContent.components(separatedBy: "[IMAGE]")
        var result: [(text: String, imageId: String?)] = []
        let images = portfolio.generatedImages
        for (i, part) in parts.enumerated() {
            let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                result.append((text: part, imageId: nil))
            }
            if i < parts.count - 1, i < images.count {
                let id = images[i].id
                let valid = id.count == 24 && !id.hasPrefix("fallback-") && !id.hasPrefix("missing-") && !id.hasPrefix("failed-")
                result.append((text: "", imageId: valid ? id : nil))
            }
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                if !segment.text.isEmpty {
                    portfolioTextBlock(segment.text)
                }
                if let imageId = segment.imageId {
                    PortfolioRemoteImageView(imageId: imageId, accentColor: designAccent)
                }
            }
        }
    }
    
    /// Parses text with # section headers and renders with typography hierarchy.
    @ViewBuilder
    private func portfolioTextBlock(_ text: String) -> some View {
        let sections = parseSections(text)
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                if section.title == "Remarks" {
                    remarksFormattedSection(content: section.content)
                } else if section.title == "Instructor Remarks", let (instructorPart, aiPart) = splitAtClosingQuote(section.content), !aiPart.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        standardSection(title: "Instructor Remarks", content: instructorPart)
                        Divider().padding(.vertical, 8)
                        standardSection(title: "Final Word", content: aiPart)
                    }
                } else {
                    standardSection(title: section.title, content: section.content)
                }
            }
        }
    }

    @ViewBuilder
    private func standardSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(designAccent)
            }
            if !content.isEmpty {
                sectionBody(content)
            }
        }
    }

    @ViewBuilder
    private func remarksFormattedSection(content: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remarks")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(designAccent)
            remarksContentBlock(content)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(designAccent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(designAccent.opacity(0.2), lineWidth: 1)
        )
    }

    /// Splits remarks content by "Student Remarks:", "Instructor Remarks:", and "AI Comments:" (displayed as "Final Word") for structured display.
    /// Each paragraph is shown on its own line.
    @ViewBuilder
    private func remarksContentBlock(_ content: String) -> some View {
        let parts = splitRemarksContent(content)
        if parts.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { partIndex, part in
                    let paragraphs = part.text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { paraIndex, paragraph in
                        if partIndex > 0 || paraIndex > 0 {
                            Divider()
                                .padding(.vertical, 12)
                        }
                        if paraIndex == 0 && !part.label.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(part.label)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.hatchEdText)
                                sectionBody(paragraph)
                            }
                        } else {
                            sectionBody(paragraph)
                        }
                    }
                }
            }
        } else if let first = parts.first, !first.text.isEmpty {
            let paragraphs = first.text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { i, p in
                    if i > 0 {
                        Divider()
                            .padding(.vertical, 12)
                    }
                    sectionBody(p)
                }
            }
        }
    }

    private func splitRemarksContent(_ content: String) -> [(label: String, text: String)] {
        let markers: [(String, String)] = [
            ("Student Remarks:", "Student Remarks"),
            ("Instructor Remarks:", "Instructor Remarks"),
            ("AI Comments:", "Final Word")
        ]
        var result: [(label: String, text: String)] = []
        var remaining = content

        while !remaining.isEmpty {
            var earliestRange: Range<String.Index>?
            var earliestLabel: String?
            for (marker, label) in markers {
                if let r = remaining.range(of: marker, options: .caseInsensitive),
                   earliestRange == nil || r.lowerBound < earliestRange!.lowerBound {
                    earliestRange = r
                    earliestLabel = label
                }
            }
            let (markerRange, label) = (earliestRange, earliestLabel ?? "")

            if let range = markerRange {
                let before = String(remaining[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty {
                    result.append(("", before))
                }
                remaining = String(remaining[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Find content end: either next paragraph (\n\n) or start of next marker
                var contentEnd: String.Index?
                if let paraEnd = remaining.range(of: "\n\n") {
                    contentEnd = paraEnd.lowerBound
                }
                for (marker, _) in markers {
                    if let nextMarker = remaining.range(of: marker, options: .caseInsensitive),
                       contentEnd == nil || nextMarker.lowerBound < contentEnd! {
                        contentEnd = nextMarker.lowerBound
                    }
                }
                if let end = contentEnd {
                    let text = String(remaining[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        // If Instructor Remarks contains quoted text, split at closing quote: quoted part = instructor, rest = AI comments
                        if label == "Instructor Remarks", let (instructorPart, aiPart) = splitAtClosingQuote(text) {
                            result.append(("Instructor Remarks", instructorPart))
                            if !aiPart.isEmpty {
                                result.append(("Final Word", aiPart))
                            }
                        } else {
                            result.append((label, text))
                        }
                    }
                    remaining = String(remaining[end...]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    if !remaining.isEmpty {
                        let text = remaining
                        if label == "Instructor Remarks", let (instructorPart, aiPart) = splitAtClosingQuote(text) {
                            result.append(("Instructor Remarks", instructorPart))
                            if !aiPart.isEmpty {
                                result.append(("Final Word", aiPart))
                            }
                        } else {
                            result.append((label, text))
                        }
                    }
                    break
                }
            } else {
                let text = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    result.append(("", text))
                }
                break
            }
        }
        return result.isEmpty ? [("", content)] : result
    }

    /// Splits text at the closing quote of the first quoted passage. Returns (quoted part, rest) or nil if no closing quote.
    private func splitAtClosingQuote(_ text: String) -> (String, String)? {
        let quote: Character = "\""
        guard let first = text.firstIndex(of: quote) else { return nil }
        let afterFirst = text.index(after: first)
        guard afterFirst < text.endIndex, let second = text[afterFirst...].firstIndex(of: quote) else { return nil }
        let throughClosing = text.index(after: second)
        let instructorPart = String(text[..<throughClosing]).trimmingCharacters(in: .whitespacesAndNewlines)
        let aiPart = throughClosing < text.endIndex
            ? String(text[throughClosing...]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        return (instructorPart, aiPart)
    }

    @ViewBuilder
    private func sectionBody(_ content: String) -> some View {
        if let attr = try? AttributedString(markdown: content) {
            Text(attr)
                .font(.body)
                .foregroundColor(.hatchEdText)
                .lineSpacing(6)
        } else {
            Text(content)
                .font(.body)
                .foregroundColor(.hatchEdText)
                .lineSpacing(6)
        }
    }
    
    private func parseSections(_ text: String) -> [(title: String, content: String)] {
        let lines = text.components(separatedBy: .newlines)
        var result: [(title: String, content: String)] = []
        var currentTitle = ""
        var currentContent: [String] = []

        /// Strip leading # symbols and return the heading text, or nil if not a heading line.
        func parseHeading(_ line: String) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#"), let spaceIdx = trimmed.firstIndex(of: " ") else { return nil }
            return String(trimmed[trimmed.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
        }

        /// Titles to skip (treat as empty / content only).
        let skipTitles = ["Introduction", "General Portfolio"]
        func shouldSkipTitle(_ t: String) -> Bool {
            skipTitles.contains(t) || (t.contains(" Portfolio") && (t.contains(" - ") || t.contains(" for ")))
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let heading = parseHeading(trimmed) {
                if !currentContent.isEmpty || !currentTitle.isEmpty {
                    let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    let title = shouldSkipTitle(currentTitle) ? "" : currentTitle
                    if !content.isEmpty || !title.isEmpty {
                        result.append((title, content))
                    }
                }
                currentTitle = heading
                currentContent = []
            } else {
                currentContent.append(line)
            }
        }
        if !currentContent.isEmpty || !currentTitle.isEmpty {
            let content = currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = shouldSkipTitle(currentTitle) ? "" : currentTitle
            if !content.isEmpty || !title.isEmpty {
                result.append((title, content))
            }
        }
        return result
    }
}

// Loads and displays one portfolio image (portfolioImages or studentWorkFiles) via GET /api/portfolios/images/:id
private struct PortfolioRemoteImageView: View {
    let imageId: String
    var accentColor: Color = .hatchEdAccent
    
    @State private var image: UIImage?
    @State private var failed = false
    
    private var url: URL? {
        APIClient.shared.portfolioImageURL(imageId: imageId)
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accentColor.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            } else if failed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hatchEdCardBackground)
                    .frame(height: 140)
                    .overlay(
                        Text("Image unavailable")
                            .font(.caption)
                            .foregroundColor(.hatchEdSecondaryText)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hatchEdCardBackground.opacity(0.5))
                    .frame(height: 140)
                    .overlay(ProgressView())
            }
        }
        .task(id: imageId) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        image = nil
        failed = false
        guard let url = url else {
            failed = true
            return
        }
        do {
            var request = URLRequest(url: url)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            if let token = APIClient.shared.getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let uiImage = UIImage(data: data) else {
                failed = true
                return
            }
            image = uiImage
        } catch {
            failed = true
        }
    }
}

// PDF Style Enum
enum PDFStyle: String, CaseIterable, Identifiable {
    case modern = "Modern"
    case classic = "Classic"
    case elegant = "Elegant"
    case vibrant = "Vibrant"
    case minimal = "Minimal"
    case professional = "Professional"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .modern: return "Rounded cards with soft shadows and modern sans-serif"
        case .classic: return "Sharp corners, serif fonts, traditional layout"
        case .elegant: return "Elegant curves, gradient backgrounds, refined typography"
        case .vibrant: return "Bold shapes, colorful sections, energetic design"
        case .minimal: return "Clean lines, ample whitespace, subtle borders"
        case .professional: return "Structured layout, corporate fonts, professional shadows"
        }
    }
    
    var designScheme: PDFDesignScheme {
        switch self {
        case .modern:
            return PDFDesignScheme(
                accent: UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0), // Bright cyan-blue
                accentSecondary: nil,
                background: UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0), // Light blue-gray
                backgroundColors: nil,
                card: .white,
                sectionBackground: UIColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1.0),
                text: .label,
                secondaryText: .secondaryLabel,
                titleFont: UIFont.systemFont(ofSize: 28, weight: .bold),
                sectionFont: UIFont.systemFont(ofSize: 20, weight: .semibold),
                bodyFont: UIFont.systemFont(ofSize: 11, weight: .regular),
                cornerRadius: 12,
                shadowOffset: CGSize(width: 0, height: 2),
                shadowBlur: 8,
                shadowOpacity: 0.15,
                imageSpacing: 35,
                textSpacing: 25,
                sectionSpacing: 40,
                textBorderStyle: .subtle,
                textBorderWidth: 1,
                opaqueImageBackground: false,
                fancyPageBorder: false,
                verticalFocusedLayout: false,
                narrowContentWidthRatio: nil,
                imageEdgeMargin: nil,
                textBlockCardColor: nil
            )
        case .classic:
            return PDFDesignScheme(
                accent: .black,
                accentSecondary: nil,
                background: .white,
                backgroundColors: nil,
                card: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
                sectionBackground: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0),
                text: .black,
                secondaryText: .darkGray,
                titleFont: UIFont(name: "TimesNewRomanPS-BoldMT", size: 28) ?? UIFont.boldSystemFont(ofSize: 28),
                sectionFont: UIFont(name: "TimesNewRomanPS-BoldMT", size: 20) ?? UIFont.boldSystemFont(ofSize: 20),
                bodyFont: UIFont(name: "TimesNewRomanPSMT", size: 11) ?? UIFont.systemFont(ofSize: 11),
                cornerRadius: 0,
                shadowOffset: CGSize(width: 0, height: 1),
                shadowBlur: 2,
                shadowOpacity: 0.1,
                imageSpacing: 30,
                textSpacing: 20,
                sectionSpacing: 35,
                textBorderStyle: .topBottom,
                textBorderWidth: 1,
                opaqueImageBackground: false,
                fancyPageBorder: false,
                verticalFocusedLayout: false,
                narrowContentWidthRatio: nil,
                imageEdgeMargin: nil,
                textBlockCardColor: nil
            )
        case .elegant:
            return PDFDesignScheme(
                accent: UIColor(red: 0.3, green: 0.2, blue: 0.5, alpha: 1.0), // Deep purple
                accentSecondary: nil,
                background: UIColor(red: 0.97, green: 0.96, blue: 0.99, alpha: 1.0), // Light purple-tinted
                backgroundColors: nil,
                card: UIColor(red: 1.0, green: 0.99, blue: 1.0, alpha: 1.0), // Off-white
                sectionBackground: UIColor(red: 0.99, green: 0.98, blue: 1.0, alpha: 1.0), // Very light purple
                text: .label,
                secondaryText: .secondaryLabel,
                titleFont: UIFont(name: "SnellRoundhand-Bold", size: 26) ?? UIFont(name: "Zapfino", size: 26) ?? UIFont.italicSystemFont(ofSize: 26),
                sectionFont: UIFont(name: "SnellRoundhand", size: 18) ?? UIFont(name: "Zapfino", size: 18) ?? UIFont.italicSystemFont(ofSize: 18),
                bodyFont: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
                cornerRadius: 16,
                shadowOffset: CGSize(width: 0, height: 4),
                shadowBlur: 12,
                shadowOpacity: 0.2,
                imageSpacing: 40,
                textSpacing: 25,
                sectionSpacing: 45,
                textBorderStyle: .accent,
                textBorderWidth: 0.5,
                opaqueImageBackground: true,
                fancyPageBorder: true,
                verticalFocusedLayout: true,
                narrowContentWidthRatio: 0.55,
                imageEdgeMargin: nil,
                textBlockCardColor: .white
            )
        case .vibrant:
            return PDFDesignScheme(
                accent: UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0), // Bright orange
                accentSecondary: UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 1.0), // Bright cyan
                background: UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0), // Default (first color)
                backgroundColors: [
                    UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0), // Warm peach
                    UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 1.0), // Cool blue
                    UIColor(red: 0.98, green: 1.0, blue: 0.95, alpha: 1.0), // Fresh green
                    UIColor(red: 1.0, green: 0.95, blue: 0.98, alpha: 1.0), // Soft pink
                    UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)  // Light purple
                ],
                card: .white,
                sectionBackground: UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1.0),
                text: .label,
                secondaryText: .secondaryLabel,
                titleFont: UIFont.systemFont(ofSize: 30, weight: .black),
                sectionFont: UIFont.systemFont(ofSize: 22, weight: .bold),
                bodyFont: UIFont.systemFont(ofSize: 11, weight: .medium),
                cornerRadius: 20,
                shadowOffset: CGSize(width: 0, height: 6),
                shadowBlur: 15,
                shadowOpacity: 0.25,
                imageSpacing: 45,
                textSpacing: 30,
                sectionSpacing: 50,
                textBorderStyle: .solid,
                textBorderWidth: 3,
                opaqueImageBackground: false,
                fancyPageBorder: false,
                verticalFocusedLayout: false,
                narrowContentWidthRatio: nil,
                imageEdgeMargin: nil,
                textBlockCardColor: nil
            )
        case .minimal:
            return PDFDesignScheme(
                accent: .systemGray,
                accentSecondary: nil,
                background: .white,
                backgroundColors: nil,
                card: .white,
                sectionBackground: .white,
                text: .label,
                secondaryText: .secondaryLabel,
                titleFont: UIFont.systemFont(ofSize: 24, weight: .light),
                sectionFont: UIFont.systemFont(ofSize: 18, weight: .regular),
                bodyFont: UIFont.systemFont(ofSize: 10, weight: .light),
                cornerRadius: 0,
                shadowOffset: .zero,
                shadowBlur: 0,
                shadowOpacity: 0,
                imageSpacing: 50,
                textSpacing: 35,
                sectionSpacing: 60,
                textBorderStyle: .none,
                textBorderWidth: 0,
                opaqueImageBackground: false,
                fancyPageBorder: false,
                verticalFocusedLayout: false,
                narrowContentWidthRatio: nil,
                imageEdgeMargin: nil,
                textBlockCardColor: nil
            )
        case .professional:
            return PDFDesignScheme(
                accent: UIColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 1.0), // Deep navy blue
                accentSecondary: nil,
                background: UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0), // Cool gray
                backgroundColors: nil,
                card: .white,
                sectionBackground: UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1.0), // Almost white
                text: .label,
                secondaryText: .secondaryLabel,
                titleFont: UIFont.systemFont(ofSize: 26, weight: .bold),
                sectionFont: UIFont.systemFont(ofSize: 19, weight: .semibold),
                bodyFont: UIFont.systemFont(ofSize: 10.5, weight: .regular),
                cornerRadius: 6,
                shadowOffset: CGSize(width: 0, height: 3),
                shadowBlur: 10,
                shadowOpacity: 0.12,
                imageSpacing: 35,
                textSpacing: 22,
                sectionSpacing: 38,
                textBorderStyle: .leftAccent,
                textBorderWidth: 4,
                opaqueImageBackground: false,
                fancyPageBorder: false,
                verticalFocusedLayout: false,
                narrowContentWidthRatio: nil,
                imageEdgeMargin: nil,
                textBlockCardColor: nil
            )
        }
    }
}

enum TextBorderStyle {
    case none
    case solid
    case subtle
    case accent
    case leftAccent
    case topBottom
}

struct PDFDesignScheme {
    let accent: UIColor
    let accentSecondary: UIColor? // For vibrant style with multiple colors
    let background: UIColor
    let backgroundColors: [UIColor]? // For vibrant style with multiple background colors
    let card: UIColor
    let sectionBackground: UIColor
    let text: UIColor
    let secondaryText: UIColor
    let titleFont: UIFont
    let sectionFont: UIFont
    let bodyFont: UIFont
    let cornerRadius: CGFloat
    let shadowOffset: CGSize
    let shadowBlur: CGFloat
    let shadowOpacity: CGFloat
    let imageSpacing: CGFloat
    let textSpacing: CGFloat
    let sectionSpacing: CGFloat
    let textBorderStyle: TextBorderStyle
    let textBorderWidth: CGFloat
    let opaqueImageBackground: Bool  // For Elegant: solid background behind non-hero images
    let fancyPageBorder: Bool  // For Elegant: ornate double-line page frame
    let verticalFocusedLayout: Bool  // For Elegant: narrow centered text and images, images match text width
    let narrowContentWidthRatio: CGFloat?  // When set, text uses pageWidth * this (centered)
    let imageEdgeMargin: CGFloat?  // When set, images extend to page edges with this margin
    let textBlockCardColor: UIColor?  // When set, use for text card background (e.g. white)
}

/// Layout variants for portfolio PDF content—adds variety: columns, text-wrap, asymmetric blocks.
enum PDFContentLayoutType {
    case singleColumn          // Default full-width
    case twoColumn             // Text in two columns
    case heroImage             // First image: full page width
    case imageLeftTextWrap     // Image left, text wraps around (Core Text exclusion)
    case imageRightTextWrap    // Image right, text wraps around (Core Text exclusion)
    case sideBySide            // Image and text as adjacent blocks (left/right)
    case magazineGrid          // Multiple small text boxes in 2-column grid
    case calloutBox            // Narrow callout strip (left or right edge)
}

// PDF Creator - Graphical PDF Generation
class PDFCreator {
    private var contentPairIndex = 0 // Track pairs for alternating text/image order and background colors
    private var sectionIndex = 0
    
    /// Choose layout based on position and content to create visual variety.
    private func layoutForPair(sectionIndex: Int, pairIndex: Int, hasImage: Bool, textLength: Int, imageIndex: Int?, design: PDFDesignScheme) -> PDFContentLayoutType {
        if design.verticalFocusedLayout {
            return .singleColumn
        }
        let idx = sectionIndex * 10 + pairIndex
        if hasImage {
            switch idx % 5 {
            case 0: return .imageLeftTextWrap
            case 1: return .imageRightTextWrap
            case 2: return .sideBySide
            case 3: return .imageLeftTextWrap
            default: return .imageRightTextWrap
            }
        } else {
            // Text-only: vary between single column, two column, magazine grid
            if textLength > 400 { return .twoColumn }
            switch idx % 4 {
            case 0: return .singleColumn
            case 1: return .twoColumn
            case 2: return .magazineGrid
            default: return .singleColumn
            }
        }
    }
    
    func createPDF(from portfolio: Portfolio, style: PDFStyle = .professional, imageCache: [String: UIImage] = [:]) -> Data {
        contentPairIndex = 0 // Reset for each PDF generation
        let pdfMetaData = [
            kCGPDFContextCreator: "HatchEd",
            kCGPDFContextAuthor: portfolio.studentName,
            kCGPDFContextTitle: "\(portfolio.studentName) - \(portfolio.designPattern.rawValue) Portfolio"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 72.0 // 1 inch margins
        let contentWidth = pageWidth - (margin * 2)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        // Get design scheme based on style
        let design = style.designScheme
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Draw background based on style (use first color for vibrant)
            let bgColor = getBackgroundColor(for: 0, design: design)
            bgColor.setFill()
            context.fill(pageRect)
            drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
            
            var yPosition: CGFloat = margin
            
            // Header with style-specific design
            let headerHeight: CGFloat = style == .minimal ? 80 : 140
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: headerHeight)
            
            if style == .minimal {
                // Minimal style: no header background, just a line
                design.accent.setStroke()
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: headerHeight - 2))
                linePath.addLine(to: CGPoint(x: pageWidth - margin, y: headerHeight - 2))
                linePath.lineWidth = 1
                linePath.stroke()
            } else if style == .elegant {
                // Elegant: gradient-like header
                let gradientRect = headerRect
                design.accent.withAlphaComponent(0.9).setFill()
                context.fill(gradientRect)
                // Add subtle gradient effect with overlay
                UIColor.white.withAlphaComponent(0.1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: headerHeight / 2))
            } else {
                // Other styles: solid colored header background
                design.accent.setFill()
                context.fill(headerRect)
            }
            
            // Title in header - style-specific
            let titleColor = style == .minimal ? design.accent : UIColor.white
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: design.titleFont,
                .foregroundColor: titleColor
            ]
            let title = portfolio.studentName
            let titleBoundingRect = NSString(string: title).boundingRect(
                with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: titleAttributes,
                context: nil
            )
            let titleHeight = ceil(titleBoundingRect.height)
            title.draw(at: CGPoint(x: margin, y: style == .minimal ? 30 : 50), withAttributes: titleAttributes)
            
            // Subtitle (omit for General)
            if portfolio.designPattern != .general {
                let subtitleColor = style == .minimal ? design.secondaryText : UIColor.white.withAlphaComponent(0.95)
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: design.sectionFont.pointSize - 4, weight: .medium),
                    .foregroundColor: subtitleColor
                ]
                let subtitle = "\(portfolio.designPattern.rawValue) Portfolio"
                subtitle.draw(at: CGPoint(x: margin, y: (style == .minimal ? 30 : 50) + titleHeight + 10), withAttributes: subtitleAttributes)
            }
            
            yPosition = headerHeight + design.sectionSpacing / 2
            
            // Parse and render portfolio content with sections
            yPosition = renderPortfolioContent(
                context: context,
                content: portfolio.compiledContent,
                yPosition: yPosition,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                contentWidth: contentWidth,
                style: style,
                design: design,
                generatedImages: portfolio.generatedImages,
                imageCache: imageCache,
                contentPairIndex: &contentPairIndex
            )
            
            // Footer on last page
            let footerPattern = portfolio.designPattern == .general ? "Portfolio" : "\(portfolio.designPattern.rawValue) Portfolio"
            drawPageFooter(
                context: context,
                pageRect: pageRect,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                studentName: portfolio.studentName,
                designPattern: footerPattern,
                design: design
            )
        }
        
        return data
    }

    private func drawPageFooter(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        studentName: String,
        designPattern: String,
        design: PDFDesignScheme
    ) {
        let footerBottom = pageHeight - 20
        let lineY = footerBottom - 14
        design.secondaryText.setStroke()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: lineY))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: lineY))
        linePath.lineWidth = 0.5
        linePath.stroke()
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = .center
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: design.secondaryText,
            .paragraphStyle: paraStyle
        ]
        let footerText = "\(studentName) · \(designPattern)"
        let footerRect = CGRect(x: margin, y: lineY + 4, width: pageWidth - margin * 2, height: 12)
        (footerText as NSString).draw(in: footerRect, withAttributes: footerAttributes)
    }
    
    private func drawFancyPageBorder(pageWidth: CGFloat, pageHeight: CGFloat, design: PDFDesignScheme) {
        guard design.fancyPageBorder else { return }
        let outerInset: CGFloat = 24
        let innerInset: CGFloat = 36
        let frameInset: CGFloat = 48
        let cornerRadius: CGFloat = 20
        let lineW: CGFloat = 1.2
        let accent = design.accent
        
        // Outer ornamental frame — rounded rectangle
        let outerRect = CGRect(x: outerInset, y: outerInset, width: pageWidth - outerInset * 2, height: pageHeight - outerInset * 2)
        accent.withAlphaComponent(0.85).setStroke()
        let outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: cornerRadius)
        outerPath.lineWidth = lineW
        outerPath.stroke()
        
        // Inner frame
        let innerRect = CGRect(x: innerInset, y: innerInset, width: pageWidth - innerInset * 2, height: pageHeight - innerInset * 2)
        accent.withAlphaComponent(0.5).setStroke()
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius - 6)
        innerPath.lineWidth = 0.6
        innerPath.stroke()
        
        // Ornamental curved corner flourishes (scrollwork S-curves)
        let flourishSize: CGFloat = 28
        accent.withAlphaComponent(0.7).setStroke()
        let strokePath = UIBezierPath()
        for (pt, flipH, flipV) in [
            (CGPoint(x: frameInset, y: frameInset), false, false),
            (CGPoint(x: pageWidth - frameInset, y: frameInset), true, false),
            (CGPoint(x: pageWidth - frameInset, y: pageHeight - frameInset), true, true),
            (CGPoint(x: frameInset, y: pageHeight - frameInset), false, true)
        ] {
            let sx: CGFloat = flipH ? -1 : 1
            let sy: CGFloat = flipV ? -1 : 1
            strokePath.move(to: CGPoint(x: pt.x, y: pt.y))
            strokePath.addCurve(to: CGPoint(x: pt.x + sx * flourishSize * 0.7, y: pt.y + sy * flourishSize * 0.3),
                               controlPoint1: CGPoint(x: pt.x + sx * flourishSize * 0.4, y: pt.y),
                               controlPoint2: CGPoint(x: pt.x + sx * flourishSize * 0.7, y: pt.y + sy * flourishSize * 0.1))
            strokePath.addCurve(to: CGPoint(x: pt.x + sx * flourishSize, y: pt.y + sy * flourishSize),
                               controlPoint1: CGPoint(x: pt.x + sx * flourishSize * 0.85, y: pt.y + sy * flourishSize * 0.5),
                               controlPoint2: CGPoint(x: pt.x + sx * flourishSize, y: pt.y + sy * flourishSize * 0.75))
            strokePath.addCurve(to: CGPoint(x: pt.x + sx * flourishSize * 0.3, y: pt.y + sy * flourishSize * 0.7),
                               controlPoint1: CGPoint(x: pt.x + sx * flourishSize, y: pt.y + sy * flourishSize * 0.9),
                               controlPoint2: CGPoint(x: pt.x + sx * flourishSize * 0.5, y: pt.y + sy * flourishSize))
            strokePath.addCurve(to: pt,
                               controlPoint1: CGPoint(x: pt.x + sx * flourishSize * 0.1, y: pt.y + sy * flourishSize * 0.6),
                               controlPoint2: CGPoint(x: pt.x, y: pt.y + sy * flourishSize * 0.3))
        }
        strokePath.lineWidth = 0.8
        strokePath.lineJoinStyle = .round
        strokePath.stroke()
        
        // Small curved corner brackets (arcs)
        let bracketRadius: CGFloat = 12
        accent.withAlphaComponent(0.6).setStroke()
        for (cx, cy, startAngle, endAngle) in [
            (outerInset + bracketRadius, outerInset + bracketRadius, CGFloat.pi, CGFloat.pi * 1.5),
            (pageWidth - outerInset - bracketRadius, outerInset + bracketRadius, CGFloat.pi * 1.5, 0),
            (pageWidth - outerInset - bracketRadius, pageHeight - outerInset - bracketRadius, 0, CGFloat.pi * 0.5),
            (outerInset + bracketRadius, pageHeight - outerInset - bracketRadius, CGFloat.pi * 0.5, CGFloat.pi)
        ] {
            let arc = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: bracketRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            arc.lineWidth = 0.7
            arc.stroke()
        }
    }
    
    private func drawSection(
        context: UIGraphicsPDFRendererContext,
        title: String,
        content: String,
        yPosition: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme
    ) -> CGFloat {
        var currentY = yPosition
        let (effectiveMargin, effectiveContentWidth) = effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        
        // Section title with design-specific font
        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: design.sectionFont,
            .foregroundColor: design.accent
        ]
        let sectionTitleBoundingRect = NSString(string: title).boundingRect(
            with: CGSize(width: effectiveContentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: sectionTitleAttributes,
            context: nil
        )
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height)
        title.draw(at: CGPoint(x: effectiveMargin, y: currentY), withAttributes: sectionTitleAttributes)
        currentY += sectionTitleHeight + design.textSpacing
        
        // Content in styled card
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.firstLineHeadIndent = 0
        
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: design.bodyFont,
            .foregroundColor: design.text,
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate padding based on border style
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 30 : 20
        let verticalPadding: CGFloat = 20
        
        let contentBoundingRect = NSString(string: content).boundingRect(
            with: CGSize(width: effectiveContentWidth - (horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        let contentHeight = ceil(contentBoundingRect.height)
        
        // Draw section background
        let sectionBgRect = CGRect(x: effectiveMargin, y: currentY - 10, width: effectiveContentWidth, height: contentHeight + (verticalPadding * 2) + 20)
        design.sectionBackground.setFill()
        context.fill(sectionBgRect)
        
        // Draw card background with shadow
        let cardRect = CGRect(x: effectiveMargin, y: currentY, width: effectiveContentWidth, height: contentHeight + (verticalPadding * 2))
        
        // Apply shadow if enabled
        if design.shadowOpacity > 0 {
            context.cgContext.setShadow(
                offset: design.shadowOffset,
                blur: design.shadowBlur,
                color: UIColor.black.withAlphaComponent(design.shadowOpacity).cgColor
            )
        }
        
        (design.textBlockCardColor ?? design.card).setFill()
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
        cardPath.fill()
        
        // Reset shadow for border
        context.cgContext.setShadow(offset: .zero, blur: 0)
        
        // Draw border based on style
        switch design.textBorderStyle {
        case .none:
            // No border
            break
        case .solid:
            // Full border with accent color (or alternating colors for vibrant)
            if let secondaryAccent = design.accentSecondary {
                // Vibrant style: use both colors
                design.accent.setStroke()
                let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
                borderPath.lineWidth = design.textBorderWidth
                borderPath.stroke()
                // Add inner border with secondary color
                secondaryAccent.setStroke()
                let innerPath = UIBezierPath(roundedRect: cardRect.insetBy(dx: 2, dy: 2), cornerRadius: design.cornerRadius - 1)
                innerPath.lineWidth = 1
                innerPath.stroke()
            } else {
                design.accent.setStroke()
                let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
                borderPath.lineWidth = design.textBorderWidth
                borderPath.stroke()
            }
        case .subtle:
            // Subtle gray border
            design.secondaryText.withAlphaComponent(0.3).setStroke()
            let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
            borderPath.lineWidth = design.textBorderWidth
            borderPath.stroke()
        case .accent:
            // Accent color border
            design.accent.setStroke()
            let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
            borderPath.lineWidth = design.textBorderWidth
            borderPath.stroke()
        case .leftAccent:
            // Left accent bar
            design.accent.setFill()
            let accentBarRect = CGRect(x: effectiveMargin, y: currentY, width: design.textBorderWidth, height: cardRect.height)
            context.fill(accentBarRect)
        case .topBottom:
            // Top and bottom borders only
            design.accent.setStroke()
            let topPath = UIBezierPath()
            topPath.move(to: CGPoint(x: effectiveMargin, y: currentY))
            topPath.addLine(to: CGPoint(x: effectiveMargin + effectiveContentWidth, y: currentY))
            topPath.lineWidth = design.textBorderWidth
            topPath.stroke()
            
            let bottomPath = UIBezierPath()
            bottomPath.move(to: CGPoint(x: effectiveMargin, y: currentY + cardRect.height))
            bottomPath.addLine(to: CGPoint(x: effectiveMargin + effectiveContentWidth, y: currentY + cardRect.height))
            bottomPath.lineWidth = design.textBorderWidth
            bottomPath.stroke()
        }
        
        // Draw content text with appropriate padding
        let textRect = cardRect.insetBy(dx: horizontalPadding, dy: verticalPadding)
        let attributedContent = NSAttributedString(string: content, attributes: contentAttributes)
        attributedContent.draw(in: textRect)
        
        currentY += contentHeight + (verticalPadding * 2) + design.textSpacing
        
        return currentY
    }
    
    // Parse and render portfolio content with markdown sections
    private func renderPortfolioContent(
        context: UIGraphicsPDFRendererContext,
        content: String,
        yPosition: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        style: PDFStyle,
        design: PDFDesignScheme,
        generatedImages: [PortfolioImage],
        imageCache: [String: UIImage],
        contentPairIndex: inout Int
    ) -> CGFloat {
        var currentY = yPosition
        var globalImageIndex = 0 // Track image index across all sections
        let lines = content.components(separatedBy: .newlines)
        var currentSection: (title: String, content: [String])? = nil
        var allSections: [(title: String, content: [String])] = []
        
        // Parse markdown sections (#, ##, ###)
        func pdfParseHeading(_ line: String) -> String? {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("#"), let spaceIdx = t.firstIndex(of: " ") else { return nil }
            return String(t[t.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
        }
        let pdfSkipTitles = ["Introduction", "General Portfolio"]
        func pdfShouldSkipTitle(_ t: String) -> Bool {
            pdfSkipTitles.contains(t) || (t.contains(" Portfolio") && (t.contains(" - ") || t.contains(" for ")))
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let heading = pdfParseHeading(trimmed) {
                if let section = currentSection {
                    allSections.append(section)
                }
                currentSection = (title: heading, content: [])
            } else if let section = currentSection {
                var sectionContent = section.content
                sectionContent.append(line)
                currentSection = (title: section.title, content: sectionContent)
            } else {
                if allSections.isEmpty && currentSection == nil {
                    currentSection = (title: "", content: [line])
                }
            }
        }
        
        if let section = currentSection {
            allSections.append(section)
        }
        
        if allSections.isEmpty {
            let singleHeight = estimateDrawSectionHeight(title: "Portfolio Content", content: content, pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
            if currentY + singleHeight > pageHeight - margin {
                context.beginPage()
                let bgColor = getBackgroundColor(for: contentPairIndex, design: design)
                bgColor.setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                currentY = margin
            }
            return drawSection(
                context: context,
                title: "Portfolio Content",
                content: content,
                yPosition: currentY,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                contentWidth: contentWidth,
                design: design
            )
        }
        
        for (secIdx, section) in allSections.enumerated() {
            let displayTitle = pdfShouldSkipTitle(section.title) ? "" : section.title
            currentY = drawPortfolioSection(
                context: context,
                sectionIndex: secIdx,
                title: displayTitle,
                content: section.content,
                yPosition: currentY,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                contentWidth: contentWidth,
                design: design,
                generatedImages: generatedImages,
                imageCache: imageCache,
                contentPairIndex: &contentPairIndex,
                globalImageIndex: &globalImageIndex
            )
        }
        
        return currentY
    }
    
    // Helper function to get background color (alternating for vibrant)
    private func getBackgroundColor(for index: Int, design: PDFDesignScheme) -> UIColor {
        if let backgroundColors = design.backgroundColors, !backgroundColors.isEmpty {
            return backgroundColors[index % backgroundColors.count]
        }
        return design.background
    }
    
    /// Estimated height for a simple section (title + content) for page-break and centering.
    private func estimateDrawSectionHeight(
        title: String,
        content: String,
        pageWidth: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme
    ) -> CGFloat {
        let (_, effContentWidth) = effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: design.sectionFont,
            .foregroundColor: design.accent
        ]
        let sectionTitleBoundingRect = NSString(string: title).boundingRect(
            with: CGSize(width: effContentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: sectionTitleAttributes,
            context: nil
        )
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height)
        var height = sectionTitleHeight + design.textSpacing
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: design.bodyFont,
            .foregroundColor: design.text,
            .paragraphStyle: paragraphStyle
        ]
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 30 : 20
        let verticalPadding: CGFloat = 20
        let contentBoundingRect = NSString(string: content).boundingRect(
            with: CGSize(width: effContentWidth - (horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        height += ceil(contentBoundingRect.height) + (verticalPadding * 2) + design.textSpacing
        return height
    }
    
    /// Build content pairs (same logic as drawPortfolioSection) for height estimation.
    private func buildContentPairsForHeight(
        content: [String],
        generatedImages: [PortfolioImage]
    ) -> [(text: [(type: String, content: String, index: Int?)], image: (type: String, content: String, index: Int?)?)] {
        var processedContent: [(type: String, content: String, index: Int?)] = []
        var globalImageIndex = 0
        for line in content {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = line.components(separatedBy: "[IMAGE]")
            if parts.count > 1 {
                for (i, part) in parts.enumerated() {
                    let textPart = part.trimmingCharacters(in: .whitespaces)
                    if !textPart.isEmpty {
                        processedContent.append((type: "text", content: part, index: nil))
                    }
                    if i < parts.count - 1 {
                        processedContent.append((type: "image", content: "", index: globalImageIndex))
                        globalImageIndex += 1
                    }
                }
            } else if trimmed == "[IMAGE]" || (trimmed.hasPrefix("[IMAGE") && trimmed.hasSuffix("]")) {
                processedContent.append((type: "image", content: trimmed == "[IMAGE]" ? "" : String(trimmed.dropFirst(7).dropLast(1)).trimmingCharacters(in: .whitespaces), index: globalImageIndex))
                globalImageIndex += 1
            } else {
                if let last = processedContent.last, last.type == "text" {
                    let lastIndex = processedContent.count - 1
                    processedContent[lastIndex] = (type: "text", content: last.content + "\n" + line, index: nil)
                } else {
                    processedContent.append((type: "text", content: line, index: nil))
                }
            }
        }
        var contentPairs: [(text: [(type: String, content: String, index: Int?)], image: (type: String, content: String, index: Int?)?)] = []
        var currentText: [(type: String, content: String, index: Int?)] = []
        for item in processedContent {
            if item.type == "image" {
                contentPairs.append((text: currentText, image: item))
                currentText = []
            } else {
                currentText.append(item)
            }
        }
        if !currentText.isEmpty {
            contentPairs.append((text: currentText, image: nil))
        }
        return contentPairs
    }
    
    /// Estimated height for a portfolio section (title + all content pairs) for page-break and centering.
    private func estimatePortfolioSectionHeight(
        title: String,
        content: [String],
        contentWidth: CGFloat,
        design: PDFDesignScheme,
        generatedImages: [PortfolioImage],
        imageCache: [String: UIImage]
    ) -> CGFloat {
        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: design.sectionFont,
            .foregroundColor: design.accent
        ]
        let sectionTitleBoundingRect = NSString(string: title).boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: sectionTitleAttributes,
            context: nil
        )
        var height = ceil(sectionTitleBoundingRect.height) + design.textSpacing
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: design.bodyFont,
            .foregroundColor: design.text,
            .paragraphStyle: paragraphStyle
        ]
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 30 : 20
        let verticalPadding: CGFloat = 20
        let maxImageHeight: CGFloat = 280
        
        let contentPairs = buildContentPairsForHeight(content: content, generatedImages: generatedImages)
        for pair in contentPairs {
            if !pair.text.isEmpty {
                let textContent = pair.text.map { $0.content }.joined(separator: "\n")
                let contentBoundingRect = NSString(string: textContent).boundingRect(
                    with: CGSize(width: contentWidth - (horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: contentAttributes,
                    context: nil
                )
                height += ceil(contentBoundingRect.height) + (verticalPadding * 2) + design.textSpacing
            }
            if let imageTuple = pair.image {
                var imageHeight: CGFloat = 200
                if let index = imageTuple.index, index < generatedImages.count {
                    let img = generatedImages[index]
                    let isValidId = img.id.count == 24 && !img.id.hasPrefix("fallback-") && !img.id.hasPrefix("missing-") && !img.id.hasPrefix("failed-")
                    if isValidId, let cached = imageCache[img.id] {
                        let aspectRatio = cached.size.width / cached.size.height
                        imageHeight = min(maxImageHeight, contentWidth / aspectRatio)
                    }
                }
                height += imageHeight + design.imageSpacing
            }
        }
        return height
    }
    
    // Draw a portfolio section with image placeholders and varied layouts
    private func drawPortfolioSection(
        context: UIGraphicsPDFRendererContext,
        sectionIndex: Int,
        title: String,
        content: [String],
        yPosition: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme,
        generatedImages: [PortfolioImage],
        imageCache: [String: UIImage],
        contentPairIndex: inout Int,
        globalImageIndex: inout Int
    ) -> CGFloat {
        var currentY = yPosition
        
        // Build content pairs first so we can enforce "heading never alone"
        var processedContent: [(type: String, content: String, index: Int?)] = []
        for line in content {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = line.components(separatedBy: "[IMAGE]")
            if parts.count > 1 {
                for (i, part) in parts.enumerated() {
                    let textPart = part.trimmingCharacters(in: .whitespaces)
                    if !textPart.isEmpty { processedContent.append((type: "text", content: part, index: nil)) }
                    if i < parts.count - 1 {
                        processedContent.append((type: "image", content: "", index: globalImageIndex))
                        globalImageIndex += 1
                    }
                }
            } else if trimmed == "[IMAGE]" || (trimmed.hasPrefix("[IMAGE") && trimmed.hasSuffix("]")) {
                let description = trimmed == "[IMAGE]" ? "" : String(trimmed.dropFirst(7).dropLast(1)).trimmingCharacters(in: .whitespaces)
                processedContent.append((type: "image", content: description, index: globalImageIndex))
                globalImageIndex += 1
            } else {
                if let last = processedContent.last, last.type == "text" {
                    let lastIndex = processedContent.count - 1
                    processedContent[lastIndex] = (type: "text", content: last.content + "\n" + line, index: nil)
                } else {
                    processedContent.append((type: "text", content: line, index: nil))
                }
            }
        }
        var contentPairs: [(text: [(type: String, content: String, index: Int?)], image: (type: String, content: String, index: Int?)?)] = []
        var currentText: [(type: String, content: String, index: Int?)] = []
        for item in processedContent {
            if item.type == "image" {
                contentPairs.append((text: currentText, image: item))
                currentText = []
            } else {
                currentText.append(item)
            }
        }
        if !currentText.isEmpty { contentPairs.append((text: currentText, image: nil)) }
        
        // Helper to estimate text block height (card + content) — must match renderTextBlock
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.firstLineHeadIndent = 0
        let textAttrs: [NSAttributedString.Key: Any] = [.font: design.bodyFont, .paragraphStyle: paragraphStyle]
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 30 : 20
        let verticalPadding: CGFloat = 20
        let (_, effTextWidth) = effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        let (_, effImageWidth) = design.verticalFocusedLayout ? effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design) : effectiveImageLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        let textWidth = effTextWidth - (horizontalPadding * 2)
        
        func estimatedTextBlockHeight(for content: String) -> CGFloat {
            guard !content.isEmpty else { return 0 }
            let rect = NSString(string: content).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: textAttrs,
                context: nil
            )
            return ceil(rect.height) + (verticalPadding * 2) + design.textSpacing
        }
        
        func estimatedImageHeight(for imageTuple: (type: String, content: String, index: Int?)) -> CGFloat {
            var h: CGFloat = 200
            if let index = imageTuple.index, index < generatedImages.count {
                let img = generatedImages[index]
                let valid = img.id.count == 24 && !img.id.hasPrefix("fallback-") && !img.id.hasPrefix("missing-") && !img.id.hasPrefix("failed-")
                if valid, let cached = imageCache[img.id] {
                    let aspect = cached.size.width / cached.size.height
                    h = min(280, effImageWidth / aspect)
                }
            }
            return h + design.imageSpacing
        }
        
        // Section title — never leave it alone on a page; ensure at least first pair fits with it
        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: design.sectionFont,
            .foregroundColor: design.accent
        ]
        let sectionTitleBoundingRect = NSString(string: title).boundingRect(
            with: CGSize(width: effTextWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: sectionTitleAttributes,
            context: nil
        )
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height)
        let ratio = design.narrowContentWidthRatio
        let titleX = (design.verticalFocusedLayout && ratio != nil) ? (pageWidth - pageWidth * (ratio ?? 1)) / 2 : margin
        if let firstPair = contentPairs.first {
            let firstTextContent = firstPair.text.map { $0.content }.joined(separator: "\n")
            let firstPairHeight = estimatedTextBlockHeight(for: firstTextContent) + (firstPair.image.map { estimatedImageHeight(for: $0) } ?? 0)
            if currentY + sectionTitleHeight + design.textSpacing + firstPairHeight > pageHeight - margin {
                context.beginPage()
                getBackgroundColor(for: contentPairIndex, design: design).setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                currentY = margin
            }
        }
        title.draw(at: CGPoint(x: titleX, y: currentY), withAttributes: sectionTitleAttributes)
        currentY += sectionTitleHeight + design.textSpacing

        let newPageThreshold: CGFloat = 24
        for (pairIndex, pair) in contentPairs.enumerated() {
            let textContent = pair.text.map { $0.content }.joined(separator: "\n")
            let textBlockHeight = estimatedTextBlockHeight(for: textContent)
            let imagePartHeight = pair.image.map { estimatedImageHeight(for: $0) } ?? 0
            let pairHeight = textBlockHeight + imagePartHeight
            let fitsOnPage = (currentY + pairHeight <= pageHeight - margin)
            let shouldImageFirst = design.verticalFocusedLayout ? false : (contentPairIndex % 2 == 1)
            let isFirstPair = (pairIndex == 0)
            
            if !fitsOnPage && (pair.text.isEmpty == false || pair.image != nil) {
                if isFirstPair {
                    if shouldImageFirst {
                        if let imageTuple = pair.image {
                            currentY = renderImage(context: context, image: imageTuple, yPosition: currentY, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
                        }
                        if !pair.text.isEmpty {
                            context.beginPage()
                            getBackgroundColor(for: contentPairIndex, design: design).setFill()
                            context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                            drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                            currentY = renderTextBlock(context: context, content: textContent, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
                        }
                    } else {
                        if !pair.text.isEmpty {
                            currentY = renderTextBlock(context: context, content: textContent, yPosition: currentY, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
                        }
                        if let imageTuple = pair.image {
                            context.beginPage()
                            getBackgroundColor(for: contentPairIndex, design: design).setFill()
                            context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                            drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                            currentY = renderImage(context: context, image: imageTuple, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
                        }
                    }
                } else {
                    // Not first pair: image on one page, text on another (top-aligned)
                    if shouldImageFirst, let imageTuple = pair.image {
                        context.beginPage()
                        getBackgroundColor(for: contentPairIndex, design: design).setFill()
                        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                        drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                        currentY = renderImage(context: context, image: imageTuple, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
                    }
                    if !pair.text.isEmpty {
                        context.beginPage()
                        getBackgroundColor(for: contentPairIndex + (shouldImageFirst && pair.image != nil ? 1 : 0), design: design).setFill()
                        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                        drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                        currentY = renderTextBlock(context: context, content: textContent, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
                    }
                    if !shouldImageFirst, let imageTuple = pair.image {
                        context.beginPage()
                        getBackgroundColor(for: contentPairIndex + (pair.text.isEmpty ? 0 : 1), design: design).setFill()
                        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                        drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                        currentY = renderImage(context: context, image: imageTuple, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
                    }
                }
                contentPairIndex += 1
                continue
            }
            
            if currentY > pageHeight - margin - newPageThreshold {
context.beginPage()
                getBackgroundColor(for: contentPairIndex, design: design).setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                currentY = margin
            }

            let layout = layoutForPair(sectionIndex: sectionIndex, pairIndex: pairIndex, hasImage: pair.image != nil, textLength: textContent.count, imageIndex: pair.image?.index, design: design)
            let imageFirst = design.verticalFocusedLayout ? false : (contentPairIndex % 2 == 1)
            currentY = renderContentPairWithLayout(
                context: context,
                layout: layout,
                textContent: textContent,
                imageTuple: pair.image,
                yPosition: currentY,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin,
                contentWidth: contentWidth,
                design: design,
                generatedImages: generatedImages,
                imageCache: imageCache,
                imageFirst: imageFirst
            )
            contentPairIndex += 1
        }
        
        return currentY
    }
    
    /// Renders a content pair (text + optional image) using the chosen layout for visual variety.
    private func renderContentPairWithLayout(
        context: UIGraphicsPDFRendererContext,
        layout: PDFContentLayoutType,
        textContent: String,
        imageTuple: (type: String, content: String, index: Int?)?,
        yPosition: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme,
        generatedImages: [PortfolioImage],
        imageCache: [String: UIImage],
        imageFirst: Bool
    ) -> CGFloat {
        let hasImage = imageTuple != nil
        switch layout {
        case .heroImage:
            if hasImage, let img = imageTuple {
                return renderHeroImage(context: context, image: img, text: textContent, yPosition: yPosition, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
            }
        case .imageLeftTextWrap, .imageRightTextWrap:
            if hasImage, let img = imageTuple {
                return renderImageWithTextWrap(context: context, image: img, text: textContent, imageOnLeft: layout == .imageLeftTextWrap, yPosition: yPosition, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
            }
        case .sideBySide:
            if hasImage, let img = imageTuple {
                return renderSideBySide(context: context, image: img, text: textContent, imageOnLeft: imageFirst, yPosition: yPosition, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
            }
        case .twoColumn, .magazineGrid:
            if !hasImage, !textContent.isEmpty {
                if layout == .twoColumn {
                    return renderTwoColumnTextBlock(context: context, content: textContent, yPosition: yPosition, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
                } else {
                    return renderMagazineGridTextBlock(context: context, content: textContent, yPosition: yPosition, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
                }
            }
        default:
            break
        }
        // Fallback: original single-column layout
        var y = yPosition
        if imageFirst, let img = imageTuple {
            y = renderImage(context: context, image: img, yPosition: y, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
        }
        if !textContent.isEmpty {
            y = renderTextBlock(context: context, content: textContent, yPosition: y, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
        }
        if !imageFirst, let img = imageTuple {
            y = renderImage(context: context, image: img, yPosition: y, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache)
        }
        return y
    }
    
    private func renderHeroImage(context: UIGraphicsPDFRendererContext, image: (type: String, content: String, index: Int?), text: String, yPosition: CGFloat, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme, generatedImages: [PortfolioImage], imageCache: [String: UIImage]) -> CGFloat {
        let (heroMargin, heroWidth): (CGFloat, CGFloat)
        if design.verticalFocusedLayout {
            (heroMargin, heroWidth) = effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        } else {
            (heroMargin, heroWidth) = (0, pageWidth)
        }
        let heroHeight: CGFloat = min(pageHeight * 0.42, 320)
        var img: UIImage?
        if let idx = image.index, idx < generatedImages.count, let c = imageCache[generatedImages[idx].id] {
            img = c
        }
        let heroRect = CGRect(x: heroMargin, y: yPosition, width: heroWidth, height: heroHeight)
        if let img = img {
            let aspect = img.size.width / img.size.height
            let drawH = min(heroHeight, heroWidth / aspect)
            let drawW = heroWidth
            let drawRect = CGRect(x: heroMargin, y: yPosition + (heroHeight - drawH) / 2, width: drawW, height: drawH)
            if design.cornerRadius > 0 {
                context.cgContext.saveGState()
                UIBezierPath(roundedRect: drawRect, cornerRadius: design.cornerRadius).addClip()
            }
            img.draw(in: drawRect)
            if design.cornerRadius > 0 { context.cgContext.restoreGState() }
        } else {
            drawImagePlaceholder(context: context, rect: heroRect, description: image.content, design: design)
        }
        var currentY = yPosition + heroHeight + design.sectionSpacing
        if !text.isEmpty {
            currentY = renderTextBlock(context: context, content: text, yPosition: currentY, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
        }
        return currentY
    }
    
    private func renderTwoColumnTextBlock(context: UIGraphicsPDFRendererContext, content: String, yPosition: CGFloat, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme) -> CGFloat {
        let gap: CGFloat = 16
        let colWidth = (contentWidth - gap) / 2
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 16 : 12
        let verticalPadding: CGFloat = 14
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        let attrs: [NSAttributedString.Key: Any] = [.font: design.bodyFont, .foregroundColor: design.text, .paragraphStyle: paragraphStyle]
        let textWidth = colWidth - (horizontalPadding * 2)
        let mid = content.count / 2
        let splitIdx = content.index(content.startIndex, offsetBy: min(mid, content.count))
        let breakPoint = content[..<splitIdx].lastIndex(of: " ") ?? splitIdx
        let col1Text = String(content[..<breakPoint]).trimmingCharacters(in: .whitespacesAndNewlines)
        let col2Text = String(content[breakPoint...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let r1 = NSString(string: col1Text).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        let r2 = NSString(string: col2Text).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        let cardHeight = max(ceil(r1.height), ceil(r2.height)) + (verticalPadding * 2)
        let cardRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: cardHeight)
        drawTextCardBackgroundAndBorder(context: context, cardRect: cardRect, margin: margin, contentWidth: contentWidth, design: design, currentY: yPosition)
        let col1Rect = CGRect(x: margin + horizontalPadding, y: yPosition + verticalPadding, width: textWidth, height: ceil(r1.height))
        let col2Rect = CGRect(x: margin + colWidth + gap + horizontalPadding, y: yPosition + verticalPadding, width: textWidth, height: ceil(r2.height))
        NSAttributedString(string: col1Text, attributes: attrs).draw(in: col1Rect)
        NSAttributedString(string: col2Text, attributes: attrs).draw(in: col2Rect)
        return yPosition + cardHeight + design.textSpacing
    }
    
    private func renderMagazineGridTextBlock(context: UIGraphicsPDFRendererContext, content: String, yPosition: CGFloat, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme) -> CGFloat {
        let gap: CGFloat = 12
        let boxWidth = (contentWidth - gap) / 2
        let boxHeight: CGFloat = 72
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        paragraphStyle.paragraphSpacing = 6
        let attrs: [NSAttributedString.Key: Any] = [.font: design.bodyFont, .foregroundColor: design.text, .paragraphStyle: paragraphStyle]
        let parts = content.replacingOccurrences(of: "\n", with: " ").split(separator: ". ", omittingEmptySubsequences: false).map { String($0) + ". " }
        let chunkSize = max(1, (parts.count + 3) / 4)
        var chunks: [String] = []
        for i in stride(from: 0, to: parts.count, by: chunkSize) {
            chunks.append(parts[i..<min(i + chunkSize, parts.count)].joined())
        }
        if chunks.isEmpty { chunks = [content] }
        let rows = (chunks.count + 1) / 2
        let gridHeight = CGFloat(rows) * (boxHeight + gap) + 24
        let cardRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: gridHeight)
        drawTextCardBackgroundAndBorder(context: context, cardRect: cardRect, margin: margin, contentWidth: contentWidth, design: design, currentY: yPosition)
        for (i, chunk) in chunks.enumerated() where !chunk.trimmingCharacters(in: .whitespaces).isEmpty {
            let col = i % 2
            let row = i / 2
            let boxRect = CGRect(x: margin + CGFloat(col) * (boxWidth + gap) + 10, y: yPosition + CGFloat(row) * (boxHeight + gap) + 14, width: boxWidth - 8, height: boxHeight - 8)
            let truncated = String(chunk.prefix(130)).trimmingCharacters(in: .whitespaces)
            NSAttributedString(string: (truncated + (chunk.count > 130 ? "…" : "")), attributes: attrs).draw(in: boxRect)
        }
        return yPosition + gridHeight + design.textSpacing
    }
    
    private func renderSideBySide(context: UIGraphicsPDFRendererContext, image: (type: String, content: String, index: Int?), text: String, imageOnLeft: Bool, yPosition: CGFloat, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme, generatedImages: [PortfolioImage], imageCache: [String: UIImage]) -> CGFloat {
        let gap: CGFloat = 14
        let imageWidth = contentWidth * 0.42
        let textWidth = contentWidth - imageWidth - gap
        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 14
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 6
        let attrs: [NSAttributedString.Key: Any] = [.font: design.bodyFont, .foregroundColor: design.text, .paragraphStyle: paragraphStyle]
        let textBounding = NSString(string: text).boundingRect(with: CGSize(width: textWidth - horizontalPadding * 2, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        var imageHeight: CGFloat = 180
        if let idx = image.index, idx < generatedImages.count, let cached = imageCache[generatedImages[idx].id] {
            let aspect = cached.size.width / cached.size.height
            imageHeight = min(200, imageWidth / aspect)
        }
        let blockHeight = max(ceil(textBounding.height) + verticalPadding * 2, imageHeight + 20)
        let cardRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: blockHeight)
        drawTextCardBackgroundAndBorder(context: context, cardRect: cardRect, margin: margin, contentWidth: contentWidth, design: design, currentY: yPosition)
        let imgX = imageOnLeft ? margin + 10 : margin + textWidth + gap + 10
        let txtX = imageOnLeft ? margin + imageWidth + gap + horizontalPadding : margin + horizontalPadding
        let imageRect = CGRect(x: imgX, y: yPosition + (blockHeight - imageHeight) / 2, width: imageWidth - 10, height: imageHeight)
        let txtRect = CGRect(x: txtX, y: yPosition + verticalPadding, width: textWidth - horizontalPadding * 2, height: ceil(textBounding.height))
        renderImageAtRect(context: context, image: image, rect: imageRect, design: design, generatedImages: generatedImages, imageCache: imageCache)
        NSAttributedString(string: text, attributes: attrs).draw(in: txtRect)
        return yPosition + blockHeight + design.textSpacing
    }
    
    private func renderImageAtRect(context: UIGraphicsPDFRendererContext, image: (type: String, content: String, index: Int?), rect: CGRect, design: PDFDesignScheme, generatedImages: [PortfolioImage], imageCache: [String: UIImage]) {
        if design.opaqueImageBackground, image.index != 0 {
            let bgRect = rect.insetBy(dx: -6, dy: -6)
            design.card.setFill()
            let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: design.cornerRadius + 2)
            bgPath.fill()
        }
        var img: UIImage?
        if let idx = image.index, idx < generatedImages.count {
            let pid = generatedImages[idx].id
            if let c = imageCache[pid] { img = c }
        }
        if let img = img {
            let aspect = img.size.width / img.size.height
            let drawRect = aspect > rect.width / rect.height ? CGRect(x: rect.minX, y: rect.midY - (rect.width / aspect) / 2, width: rect.width, height: rect.width / aspect) : CGRect(x: rect.midX - (rect.height * aspect) / 2, y: rect.minY, width: rect.height * aspect, height: rect.height)
            if design.cornerRadius > 0 {
                context.cgContext.saveGState()
                UIBezierPath(roundedRect: drawRect, cornerRadius: design.cornerRadius).addClip()
            }
            img.draw(in: drawRect)
            if design.cornerRadius > 0 { context.cgContext.restoreGState() }
        } else {
            drawImagePlaceholder(context: context, rect: rect, description: image.content, design: design)
        }
    }
    
    private func renderImageWithTextWrap(context: UIGraphicsPDFRendererContext, image: (type: String, content: String, index: Int?), text: String, imageOnLeft: Bool, yPosition: CGFloat, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme, generatedImages: [PortfolioImage], imageCache: [String: UIImage]) -> CGFloat {
        // Simple side-by-side layout (no text wrapping) — image on one side, text in column on other
        let gap: CGFloat = 12
        let imageWidth = contentWidth * 0.42
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 18 : 12
        let verticalPadding: CGFloat = 14
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 8
        let attrs: [NSAttributedString.Key: Any] = [.font: design.bodyFont, .foregroundColor: design.text, .paragraphStyle: paragraphStyle]
        let textWidth = contentWidth - imageWidth - gap - horizontalPadding * 2
        let textBounding = NSString(string: text).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        var imageHeight: CGFloat = 180
        if let idx = image.index, idx < generatedImages.count, let cached = imageCache[generatedImages[idx].id] {
            let aspect = cached.size.width / cached.size.height
            imageHeight = min(240, imageWidth / aspect)
        }
        let blockHeight = max(ceil(textBounding.height) + verticalPadding * 2, imageHeight + 20)
        let cardRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: blockHeight)
        drawTextCardBackgroundAndBorder(context: context, cardRect: cardRect, margin: margin, contentWidth: contentWidth, design: design, currentY: yPosition)
        let imgX = imageOnLeft ? margin + 10 : margin + contentWidth - imageWidth - 10
        let txtX = imageOnLeft ? margin + imageWidth + gap + horizontalPadding : margin + horizontalPadding
        let imageRect = CGRect(x: imgX, y: yPosition + (blockHeight - imageHeight) / 2, width: imageWidth - 10, height: imageHeight)
        let txtRect = CGRect(x: txtX, y: yPosition + verticalPadding, width: textWidth, height: ceil(textBounding.height))
        renderImageAtRect(context: context, image: image, rect: imageRect, design: design, generatedImages: generatedImages, imageCache: imageCache)
        NSAttributedString(string: text, attributes: attrs).draw(in: txtRect)
        return yPosition + blockHeight + design.textSpacing
    }
    
    // Helper function to render an image
    private func renderImage(
        context: UIGraphicsPDFRendererContext,
        image: (type: String, content: String, index: Int?),
        yPosition: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme,
        generatedImages: [PortfolioImage],
        imageCache: [String: UIImage]
    ) -> CGFloat {
        var currentY = yPosition
        
        // Try to find matching image - first by index if available, then by description
        var matchingImage: PortfolioImage?
        
        if let index = image.index, index < generatedImages.count {
            // Use index-based matching as primary method
            matchingImage = generatedImages[index]
            print("[PDF] Using index-based matching: index \(index) -> '\(matchingImage?.description ?? "none")'")
        } else {
            // Fallback to description-based matching
            let searchDescription = image.content.lowercased().trimmingCharacters(in: .whitespaces)
            matchingImage = generatedImages.first { img in
                let imgDesc = img.description.lowercased().trimmingCharacters(in: .whitespaces)
                return imgDesc == searchDescription ||
                       searchDescription.contains(imgDesc) ||
                       imgDesc.contains(searchDescription) ||
                       // Also try partial matching
                       searchDescription.split(separator: " ").contains { word in
                           imgDesc.contains(word)
                       }
            }
            if let matched = matchingImage {
                print("[PDF] Found description-based match for '\(image.content)': \(matched.description)")
            }
        }
        
        let (imageMargin, imageContentWidth): (CGFloat, CGFloat)
        if design.verticalFocusedLayout {
            (imageMargin, imageContentWidth) = effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        } else {
            (imageMargin, imageContentWidth) = effectiveImageLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        }
        let imageRect = CGRect(x: imageMargin, y: currentY, width: imageContentWidth, height: 200)
        
        if let img = matchingImage {
            let imageId = img.id
            let isValidId = imageId.count == 24 && !imageId.hasPrefix("fallback-") && !imageId.hasPrefix("missing-") && !imageId.hasPrefix("failed-")
            guard isValidId else {
                drawImagePlaceholder(context: context, rect: imageRect, description: img.description.isEmpty ? "Image unavailable" : img.description, design: design)
                currentY += 200 + design.imageSpacing
                return currentY
            }
            let cachedImage = imageCache[imageId]
            if let cachedImage = cachedImage {
                print("[PDF] Image found in cache, rendering...")
                let aspectRatio = cachedImage.size.width / cachedImage.size.height
                let maxHeight: CGFloat = 280
                var imageHeight = min(maxHeight, imageContentWidth / aspectRatio)
                let availablePageHeight = pageHeight - imageMargin - currentY - design.imageSpacing
                if imageHeight > availablePageHeight && availablePageHeight > 60 {
                    imageHeight = availablePageHeight
                }
                let drawWidth = min(imageContentWidth, imageHeight * aspectRatio)
                let imageX = imageMargin + (imageContentWidth - drawWidth) / 2
                let imageY = currentY
            
            // Apply shadow if enabled
            if design.shadowOpacity > 0 {
                context.cgContext.setShadow(
                    offset: design.shadowOffset,
                    blur: design.shadowBlur,
                    color: UIColor.black.withAlphaComponent(design.shadowOpacity).cgColor
                )
            }
            
            let imageDrawRect = CGRect(
                x: imageX,
                y: imageY,
                width: drawWidth,
                height: imageHeight
            )
            
            // Elegant style: opaque background behind non-hero images
            if design.opaqueImageBackground, image.index != 0 {
                let bgRect = imageDrawRect.insetBy(dx: -8, dy: -8)
                design.card.setFill()
                let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: design.cornerRadius + 4)
                bgPath.fill()
            }
            
            // Draw rounded image if corner radius > 0
            if design.cornerRadius > 0 {
                let imagePath = UIBezierPath(roundedRect: imageDrawRect, cornerRadius: design.cornerRadius)
                context.cgContext.addPath(imagePath.cgPath)
                context.cgContext.clip()
            }
            
                cachedImage.draw(in: imageDrawRect)
            context.cgContext.resetClip()
            context.cgContext.setShadow(offset: .zero, blur: 0)
            
                currentY += imageHeight + design.imageSpacing
            } else {
                drawImagePlaceholder(context: context, rect: imageRect, description: image.content.isEmpty ? img.description : image.content, design: design)
                currentY += 200 + design.imageSpacing
            }
        } else {
            drawImagePlaceholder(context: context, rect: imageRect, description: image.content, design: design)
            currentY += 200 + design.imageSpacing
        }
        
        return currentY
    }
    
    private func effectiveTextLayout(pageWidth: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme) -> (CGFloat, CGFloat) {
        guard let ratio = design.narrowContentWidthRatio else { return (margin, contentWidth) }
        let w = pageWidth * ratio
        return ((pageWidth - w) / 2, w)
    }
    
    private func effectiveImageLayout(pageWidth: CGFloat, margin: CGFloat, contentWidth: CGFloat, design: PDFDesignScheme) -> (margin: CGFloat, contentWidth: CGFloat) {
        guard let imageMargin = design.imageEdgeMargin else { return (margin, contentWidth) }
        return (imageMargin, pageWidth - imageMargin * 2)
    }
    
    // Helper to draw card background and border for a given rect (used for full and split text chunks)
    private func drawTextCardBackgroundAndBorder(
        context: UIGraphicsPDFRendererContext,
        cardRect: CGRect,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme,
        currentY: CGFloat
    ) {
        design.sectionBackground.setFill()
        context.fill(CGRect(x: margin, y: cardRect.minY - 10, width: contentWidth, height: cardRect.height + 20))
        if design.shadowOpacity > 0 {
            context.cgContext.setShadow(
                offset: design.shadowOffset,
                blur: design.shadowBlur,
                color: UIColor.black.withAlphaComponent(design.shadowOpacity).cgColor
            )
        }
        (design.textBlockCardColor ?? design.card).setFill()
        UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius).fill()
        context.cgContext.setShadow(offset: .zero, blur: 0)
        switch design.textBorderStyle {
        case .none: break
        case .solid:
            if design.accentSecondary != nil {
                design.accent.setStroke()
                let bp = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
                bp.lineWidth = design.textBorderWidth
                bp.stroke()
                design.accentSecondary?.setStroke()
                let inner = UIBezierPath(roundedRect: cardRect.insetBy(dx: 2, dy: 2), cornerRadius: max(0, design.cornerRadius - 1))
                inner.lineWidth = 1
                inner.stroke()
            } else {
                design.accent.setStroke()
                let bp = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
                bp.lineWidth = design.textBorderWidth
                bp.stroke()
            }
        case .subtle:
            design.secondaryText.withAlphaComponent(0.3).setStroke()
            let bp = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
            bp.lineWidth = design.textBorderWidth
            bp.stroke()
        case .accent:
            design.accent.setStroke()
            let bp = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
            bp.lineWidth = design.textBorderWidth
            bp.stroke()
        case .leftAccent:
            design.accent.setFill()
            context.fill(CGRect(x: margin, y: currentY, width: design.textBorderWidth, height: cardRect.height))
        case .topBottom:
            design.accent.setStroke()
            let topPath = UIBezierPath()
            topPath.move(to: CGPoint(x: margin, y: currentY))
            topPath.addLine(to: CGPoint(x: margin + contentWidth, y: currentY))
            topPath.lineWidth = design.textBorderWidth
            topPath.stroke()
            let bottomPath = UIBezierPath()
            bottomPath.move(to: CGPoint(x: margin, y: currentY + cardRect.height))
            bottomPath.addLine(to: CGPoint(x: margin + contentWidth, y: currentY + cardRect.height))
            bottomPath.lineWidth = design.textBorderWidth
            bottomPath.stroke()
        }
    }
    
    // Helper function to render a text block (single card, no splitting)
    private func renderTextBlock(
        context: UIGraphicsPDFRendererContext,
        content: String,
        yPosition: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat,
        contentWidth: CGFloat,
        design: PDFDesignScheme
    ) -> CGFloat {
        let currentY = yPosition
        let (effectiveMargin, effectiveContentWidth) = effectiveTextLayout(pageWidth: pageWidth, margin: margin, contentWidth: contentWidth, design: design)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.firstLineHeadIndent = 0
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: design.bodyFont,
            .foregroundColor: design.text,
            .paragraphStyle: paragraphStyle
        ]
        let horizontalPadding: CGFloat = design.textBorderStyle == .leftAccent ? 30 : 20
        let verticalPadding: CGFloat = 20
        let textWidth = effectiveContentWidth - (horizontalPadding * 2)
        let contentBoundingRect = NSString(string: content).boundingRect(
            with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        let contentHeight = ceil(contentBoundingRect.height)
        let cardRect = CGRect(x: effectiveMargin, y: currentY, width: effectiveContentWidth, height: contentHeight + (verticalPadding * 2))
        drawTextCardBackgroundAndBorder(context: context, cardRect: cardRect, margin: effectiveMargin, contentWidth: effectiveContentWidth, design: design, currentY: currentY)
        let textRect = cardRect.insetBy(dx: horizontalPadding, dy: verticalPadding)
        NSAttributedString(string: content, attributes: contentAttributes).draw(in: textRect)
        return currentY + contentHeight + (verticalPadding * 2) + design.textSpacing
    }
    // Helper function to draw image placeholder
    private func drawImagePlaceholder(
        context: UIGraphicsPDFRendererContext,
        rect: CGRect,
        description: String,
        design: PDFDesignScheme
    ) {
        // Draw background with section background color
        design.sectionBackground.setFill()
        let roundedRect = UIBezierPath(roundedRect: rect, cornerRadius: design.cornerRadius)
        roundedRect.fill()
        
        // Draw border (dashed for placeholder)
        design.accent.withAlphaComponent(0.5).setStroke()
        let borderPath = UIBezierPath(roundedRect: rect, cornerRadius: design.cornerRadius)
        borderPath.lineWidth = 2
        let dashPattern: [CGFloat] = [5, 5]
        borderPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        borderPath.stroke()
        
        // Draw image icon
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32),
            .foregroundColor: design.secondaryText.withAlphaComponent(0.4)
        ]
        let iconText = "📷"
        let iconBoundingRect = NSString(string: iconText).boundingRect(
            with: CGSize(width: 50, height: 50),
            options: [],
            attributes: iconAttributes,
            context: nil
        )
        let iconX = rect.midX - iconBoundingRect.width / 2
        let iconY = rect.midY - iconBoundingRect.height / 2 - 10
        iconText.draw(at: CGPoint(x: iconX, y: iconY), withAttributes: iconAttributes)
        
        // Draw description
        let descAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: design.bodyFont.pointSize - 1),
            .foregroundColor: design.secondaryText
        ]
        let descBoundingRect = NSString(string: description).boundingRect(
            with: CGSize(width: rect.width - 40, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: descAttributes,
            context: nil
        )
        let descHeight = ceil(descBoundingRect.height)
        let descRect = CGRect(x: rect.minX + 20, y: rect.maxY - descHeight - 10, width: rect.width - 40, height: descHeight)
        description.draw(in: descRect, withAttributes: descAttributes)
    }
}

private enum PDFAction {
    case print
    case share
}

// PDF Style Selection Sheet
struct PDFStyleSelectionSheet: View {
    @Binding var selectedStyle: PDFStyle
    let onPrint: () -> Void
    let onShare: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Choose PDF Style")) {
                    ForEach(PDFStyle.allCases) { style in
                        Button {
                            selectedStyle = style
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(style.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.hatchEdText)
                                    Text(style.description)
                                        .font(.caption)
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                                Spacer()
                                if selectedStyle == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.hatchEdAccent)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.hatchEdSecondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("PDF Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    HStack(spacing: 12) {
                        Button("Print") {
                            onPrint()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.hatchEdAccent)
                        Button("Share") {
                            onShare()
                        }
                        .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

// Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = [.print]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

