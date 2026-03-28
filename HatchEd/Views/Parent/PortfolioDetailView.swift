//
//  PortfolioDetailView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import SwiftUI
import PDFKit
import UIKit
import WebKit

/// Escapes text for use inside a double-quoted HTML attribute.
fileprivate func portfolioEscapeForHtmlAttribute(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
}

/// Runs in WKWebView after HTML load so any `<img>` missed by Swift regex (e.g. multiline tags) still
/// moves `alt` to `aria-label` and clears `alt` for visual rendering. Hides `figcaption` under figures (often duplicates alt).
fileprivate let portfolioWebViewImagePresentationScript = """
(function(){
  function moveAltToAria(img) {
    var a = img.getAttribute('alt');
    if (a != null && a.length > 0) {
      if (!img.getAttribute('aria-label')) { img.setAttribute('aria-label', a); }
      img.setAttribute('alt', '');
    }
    img.removeAttribute('title');
  }
  document.querySelectorAll('img').forEach(moveAltToAria);
  document.querySelectorAll('figure figcaption').forEach(function(el) {
    el.style.setProperty('display','none','important');
  });
  // Remove text nodes that are only leaked img-attribute fragments (e.g. model put [IMAGE] inside src; split left ` class="photo" alt="" >`).
  function removeOrphanAttributeTextNodes() {
    var patterns = [
      /^\\s*["']?\\s*class\\s*=\\s*"[^"]*"\\s+alt\\s*=\\s*"[^"]*"(\\s*\\/?\\s*>)?\\s*$/i,
      /^\\s*["']?\\s*alt\\s*=\\s*"[^"]*"\\s+class\\s*=\\s*"[^"]*"(\\s*\\/?\\s*>)?\\s*$/i
    ];
    var w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
    var dead = [];
    var n;
    while (n = w.nextNode()) {
      var t = n.textContent;
      if (!t) continue;
      for (var i = 0; i < patterns.length; i++) {
        if (patterns[i].test(t)) { dead.push(n); break; }
      }
    }
    dead.forEach(function(node) { if (node.parentNode) node.parentNode.removeChild(node); });
  }
  removeOrphanAttributeTextNodes();
})();
"""

/// Finds the `>` that closes an `<img` tag: respects quotes and skips `<!-- ... -->` (a `>` inside a comment must not close the tag).
fileprivate func findClosingAngleBracketOfImgTag(in html: String, imgOpenStart: String.Index) -> String.Index? {
    guard html[imgOpenStart..<html.endIndex].lowercased().hasPrefix("<img") else { return nil }
    var j = html.index(imgOpenStart, offsetBy: 4)
    var inDouble = false
    var inSingle = false
    while j < html.endIndex {
        let ch = html[j]
        if inDouble {
            if ch == "\"" { inDouble = false }
        } else if inSingle {
            if ch == "'" { inSingle = false }
        } else {
            if ch == "<" {
                let tail = html[j..<html.endIndex]
                if tail.hasPrefix("<!--"), let close = html.range(of: "-->", range: j..<html.endIndex) {
                    j = close.upperBound
                    continue
                }
            }
            if ch == "\"" {
                inDouble = true
            } else if ch == "'" {
                inSingle = true
            } else if ch == ">" {
                return j
            }
        }
        j = html.index(after: j)
    }
    return nil
}

/// Each `<img …>` span; `>` inside `<!-- -->` or inside quoted attributes does not end the tag.
fileprivate func rangesOfImgTags(in html: String) -> [Range<String.Index>] {
    var ranges: [Range<String.Index>] = []
    var searchFrom = html.startIndex
    while searchFrom < html.endIndex {
        guard let imgMatch = html.range(of: "<img", options: .caseInsensitive, range: searchFrom..<html.endIndex) else { break }
        let start = imgMatch.lowerBound
        guard let gtIdx = findClosingAngleBracketOfImgTag(in: html, imgOpenStart: start) else {
            searchFrom = html.index(after: start)
            continue
        }
        let endExclusive = html.index(after: gtIdx)
        ranges.append(start..<endExclusive)
        searchFrom = endExclusive
    }
    return ranges
}

/// GPT occasionally wraps HTML in markdown fences; older saved rows may still contain ```html at the top.
/// Strip for display only (does not mutate stored content).
fileprivate func stripMarkdownHtmlFencesForDisplay(_ html: String) -> String {
    var s = html.trimmingCharacters(in: .whitespacesAndNewlines)
    for _ in 0..<4 {
        let before = s
        if s.hasPrefix("```") {
            var rest = String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            let lower = rest.lowercased()
            if lower.hasPrefix("html") {
                rest = String(rest.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if lower.hasPrefix("xml") {
                rest = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            s = rest
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if s == before { break }
    }
    return s
}

/// If the model emitted `<img ... src="[IMAGE]" ...>`, splitting HTML on `[IMAGE]` tears the tag and leaves visible attribute text (e.g. `class="photo" alt=""`). Collapse the whole tag to one `[IMAGE]` token before injection.
fileprivate func collapseMalformedImgTagsWithImagePlaceholder(_ html: String) -> String {
    let pattern = "<img\\b[\\s\\S]*?\\bsrc\\s*=\\s*([\"'])\\[IMAGE\\]\\1[\\s\\S]*?>"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return html }
    var s = html
    for _ in 0..<32 {
        let len = (s as NSString).length
        let range = NSRange(location: 0, length: len)
        let next = regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "[IMAGE]")
        if next == s { break }
        s = next
    }
    return s
}

/// Display-only transform for WKWebView / print HTML. Does not change stored `compiledContent`.
/// Moves non-empty `alt` to `aria-label`, sets `alt=""` so WebKit does not paint alt text when an image fails,
/// while VoiceOver still gets a name from `aria-label`. Strips `title` (tooltips). Removes echoed `alt="…"` paragraphs.
fileprivate func portfolioHTMLForWebViewDisplay(_ html: String) -> String {
    var result = stripMarkdownHtmlFencesForDisplay(html)
    // Model HTML sometimes includes `<!-- ... -->` between attributes; strip so nothing can leak as text beside tags.
    result = result.replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)
    let imgRanges = rangesOfImgTags(in: result).sorted { $0.lowerBound > $1.lowerBound }
    for r in imgRanges {
        let tag = String(result[r])
        let transformed = portfolioTransformImgTagForVisualRendering(tag)
        result.replaceSubrange(r, with: transformed)
    }
    result = result.replacingOccurrences(of: #"(?i)<p[^>]*>\s*alt\s*=\s*"[^"]*"\s*</p>"#, with: "", options: .regularExpression)
    result = result.replacingOccurrences(of: #"(?i)<div[^>]*>\s*alt\s*=\s*"[^"]*"\s*</div>"#, with: "", options: .regularExpression)
    // Do not regex-strip ` class="…" alt="…">` here — that pattern also appears inside valid <img> tags and would corrupt them (stray quotes in the UI).
    return result
}

/// Rewrites a single `<img …>` tag: clear visible alt fallback, preserve accessible name via `aria-label`.
fileprivate func portfolioTransformImgTagForVisualRendering(_ tag: String) -> String {
    let ns = tag as NSString
    let full = NSRange(location: 0, length: ns.length)

    func firstCapture(_ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        guard let m = re.firstMatch(in: tag, options: [], range: full), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: tag) else { return nil }
        return String(tag[r])
    }

    // Allow newlines inside quoted alt/aria (valid in HTML; [^"]* misses only if unquoted)
    var altText = firstCapture(#"\salt\s*=\s*"([\s\S]*?)""#)
    if altText == nil {
        altText = firstCapture(#"\salt\s*=\s*'([\s\S]*?)'"#)
    }

    var ariaFromTag = firstCapture(#"\saria-label\s*=\s*"([\s\S]*?)""#)
    if ariaFromTag == nil {
        ariaFromTag = firstCapture(#"\saria-label\s*=\s*'([\s\S]*?)'"#)
    }

    var stripped = tag
    let removePatterns = [
        #"\salt\s*=\s*"[\s\S]*?""#,
        #"\salt\s*=\s*'[\s\S]*?'"#,
        #"\stitle\s*=\s*"[\s\S]*?""#,
        #"\stitle\s*=\s*'[\s\S]*?'"#,
        #"\saria-label\s*=\s*"[\s\S]*?""#,
        #"\saria-label\s*=\s*'[\s\S]*?'"#
    ]
    for p in removePatterns {
        stripped = stripped.replacingOccurrences(of: p, with: "", options: .regularExpression)
    }

    let trimmedAlt = altText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let trimmedAria = ariaFromTag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let labelForAria: String? = {
        if !trimmedAlt.isEmpty { return trimmedAlt }
        if !trimmedAria.isEmpty { return trimmedAria }
        return nil
    }()

    guard let gtIdx = findClosingAngleBracketOfImgTag(in: stripped, imgOpenStart: stripped.startIndex) else { return tag }
    let before = stripped[..<gtIdx]
    let afterClose = stripped[gtIdx...]

    var inject = " alt=\"\""
    if let label = labelForAria {
        inject += " aria-label=\"\(portfolioEscapeForHtmlAttribute(label))\""
    }
    return String(before) + inject + String(afterClose)
}

struct PortfolioDetailView: View {
    let portfolio: Portfolio
    var isStudent: Bool = false
    /// Called after a successful delete (e.g. refresh list). Sheet presenters should set this; push navigation may omit it.
    var onDeleted: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var showingShareSheet = false
    @State private var showingExportOptions = false
    @State private var pendingPDFAction: PDFAction? = nil
    @State private var showDeleteConfirmation = false
    @State private var isDeletingPortfolio = false
    @State private var portfolioDeleteError: String?

    private var designAccent: Color {
        portfolio.audience.accentColor
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
                                Text(portfolio.portfolioLabel + " Portfolio")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(designAccent)
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
                    
                    // Compiled Content (HTML with inline images)
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Portfolio Content")
                        PortfolioHTMLContentView(portfolio: portfolio, designAccent: designAccent)
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
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        showingExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Export or print")
                    if !isStudent {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(isDeletingPortfolio)
                        .accessibilityLabel("Delete portfolio")
                    }
                }
            }
            .confirmationDialog(
                "Delete this portfolio?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await deletePortfolioAndDismiss() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "This permanently removes “\(portfolio.portfolioLabel) Portfolio” for \(portfolio.studentName), including all AI-generated images for this portfolio. Files in Best work are not deleted. You cannot undo this."
                )
            }
            .alert("Could not delete portfolio", isPresented: Binding(
                get: { portfolioDeleteError != nil },
                set: { if !$0 { portfolioDeleteError = nil } }
            )) {
                Button("OK", role: .cancel) { portfolioDeleteError = nil }
            } message: {
                if let portfolioDeleteError {
                    Text(portfolioDeleteError)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = pdfData {
                    ShareSheet(activityItems: [pdfData])
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                PortfolioExportSheet(onPrint: {
                    showingExportOptions = false
                    pendingPDFAction = .print
                    Task { await generatePDF() }
                }, onShare: {
                    showingExportOptions = false
                    pendingPDFAction = .share
                    Task { await generatePDF() }
                }, onCancel: {
                    showingExportOptions = false
                })
            }
        }
    }

    @MainActor
    private func deletePortfolioAndDismiss() async {
        isDeletingPortfolio = true
        defer { isDeletingPortfolio = false }
        do {
            try await APIClient.shared.deletePortfolio(id: portfolio.id)
            onDeleted?()
            dismiss()
        } catch {
            portfolioDeleteError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
        guard let html = await buildPortfolioHTMLWithImages(portfolio: portfolio) else {
            pdfData = Data()
            showingShareSheet = true
            return
        }
        let data = await createPDFFromHTML(html: html, title: "\(portfolio.studentName) - \(portfolio.portfolioLabel) Portfolio")
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

// Renders portfolio HTML content in WKWebView with [IMAGE] placeholders replaced by actual images
private struct PortfolioHTMLContentView: View {
    let portfolio: Portfolio
    var designAccent: Color = .hatchEdAccent

    @State private var htmlToDisplay: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let html = htmlToDisplay {
                PortfolioWebView(html: html)
                    .frame(minHeight: 400)
            } else {
                Text("Unable to load portfolio content.")
                    .foregroundColor(.hatchEdSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .task {
            await loadHTMLWithImages()
        }
    }

    @MainActor
    private func loadHTMLWithImages() async {
        let content = collapseMalformedImgTagsWithImagePlaceholder(portfolio.compiledContent)
        let images = portfolio.generatedImages
        let api = APIClient.shared

        // Fetch all images in parallel
        var imageDataByIndex: [Int: (mimeType: String, base64: String)] = [:]
        await withTaskGroup(of: (Int, (String, String)?).self) { group in
            for (index, img) in images.enumerated() {
                let id = img.id
                guard id.count == 24, !id.hasPrefix("fallback-"), !id.hasPrefix("missing-"), !id.hasPrefix("failed-") else { continue }
                group.addTask {
                    let url = api.portfolioImageURL(imageId: id)
                    do {
                        var request = URLRequest(url: url)
                        request.setValue("image/*", forHTTPHeaderField: "Accept")
                        if let token = api.getAuthToken() {
                            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                        }
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                            return (index, nil)
                        }
                        let mime = http.value(forHTTPHeaderField: "Content-Type") ?? "image/png"
                        let base64 = data.base64EncodedString()
                        return (index, (mime, base64))
                    } catch {
                        return (index, nil)
                    }
                }
            }
            for await (index, result) in group {
                if let result = result {
                    imageDataByIndex[index] = result
                }
            }
        }

        // Replace [IMAGE] placeholders with <img src="data:..."> in order
        var imageIndex = 0
        let parts = content.components(separatedBy: "[IMAGE]")
        var builtParts: [String] = []
        for (i, part) in parts.enumerated() {
            builtParts.append(part)
            if i < parts.count - 1, imageIndex < images.count {
                if let (mime, base64) = imageDataByIndex[imageIndex] {
                    builtParts.append("<span style=\"display:block;clear:both;page-break-inside:avoid;margin:1em 0\"><img src=\"data:\(mime);base64,\(base64)\" style=\"max-width:100%;max-height:650px;width:auto;height:auto;object-fit:contain;border-radius:8px;margin:12px 0;display:block;clear:both;\" alt=\"\" /></span>")
                }
                imageIndex += 1
            }
        }
        var finalHTML = portfolioHTMLForWebViewDisplay(builtParts.joined())

        // Ensure valid HTML document for display
        if !finalHTML.lowercased().contains("<!doctype") && !finalHTML.lowercased().hasPrefix("<html") {
            finalHTML = """
            <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
            <style>*{box-sizing:border-box}body{font-family:system-ui,-apple-system,sans-serif;font-size:16px;line-height:1.6;color:#333;padding:0;margin:0}h1,h2,h3{color:#1a1a1a;margin-top:1.5em}h2{border-bottom:1px solid #eee;padding-bottom:.25em}section,article,.keepsake-section,div[class*="section"],div[class*="card"]{overflow:auto;clear:both}img{max-width:100%;max-height:650px;width:auto;height:auto;object-fit:contain;display:block;clear:both;vertical-align:top}p{margin:1em 0}ul{margin:1em 0;padding-left:1.5em}</style>
            </head><body>\(finalHTML)</body></html>
            """
        } else if let headEnd = finalHTML.range(of: "</head>", options: .caseInsensitive) {
            let css = "section,article,.keepsake-section,div[class*='section'],div[class*='card']{overflow:auto !important;clear:both !important}img{display:block !important;clear:both !important;vertical-align:top !important}"
            finalHTML.insert(contentsOf: "<style>\(css)</style>", at: headEnd.lowerBound)
        }

        htmlToDisplay = finalHTML
        isLoading = false
    }
}

// WKWebView wrapper for displaying HTML
private struct PortfolioWebView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(portfolioWebViewImagePresentationScript, completionHandler: nil)
            // Second pass: layout sometimes mutates DOM after first paint; re-apply alt/figcaption handling.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                webView.evaluateJavaScript(portfolioWebViewImagePresentationScript, completionHandler: nil)
            }
        }
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - HTML/PDF Helpers
@MainActor
private func buildPortfolioHTMLWithImages(portfolio: Portfolio) async -> String? {
    let content = collapseMalformedImgTagsWithImagePlaceholder(portfolio.compiledContent)
    let images = portfolio.generatedImages
    let api = APIClient.shared

    var imageDataByIndex: [Int: (mimeType: String, base64: String)] = [:]
    await withTaskGroup(of: (Int, (String, String)?).self) { group in
        for (index, img) in images.enumerated() {
            let id = img.id
            guard id.count == 24, !id.hasPrefix("fallback-"), !id.hasPrefix("missing-"), !id.hasPrefix("failed-") else { continue }
            group.addTask {
                let url = api.portfolioImageURL(imageId: id)
                do {
                    var request = URLRequest(url: url)
                    request.setValue("image/*", forHTTPHeaderField: "Accept")
                    if let token = api.getAuthToken() {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        return (index, nil)
                    }
                    let mime = http.value(forHTTPHeaderField: "Content-Type") ?? "image/png"
                    return (index, (mime, data.base64EncodedString()))
                } catch {
                    return (index, nil)
                }
            }
        }
        for await (index, result) in group {
            if let result = result { imageDataByIndex[index] = result }
        }
    }

    var imageIndex = 0
    let parts = content.components(separatedBy: "[IMAGE]")
    var builtParts: [String] = []
    for (i, part) in parts.enumerated() {
        builtParts.append(part)
        if i < parts.count - 1, imageIndex < images.count {
            if let (mime, base64) = imageDataByIndex[imageIndex] {
                builtParts.append("<span style=\"display:block;clear:both;page-break-inside:avoid;margin:1em 0\"><img src=\"data:\(mime);base64,\(base64)\" style=\"max-width:100%;max-height:650px;width:auto;height:auto;object-fit:contain;border-radius:8px;margin:12px 0;display:block;clear:both;\" alt=\"\" /></span>")
            }
            imageIndex += 1
        }
    }
    var finalHTML = portfolioHTMLForWebViewDisplay(builtParts.joined())
    let overlapPreventionCSS = "section,article,.keepsake-section,div[class*='section'],div[class*='card']{overflow:auto !important;clear:both !important}img{display:block !important;clear:both !important;vertical-align:top !important}"
    if !finalHTML.lowercased().contains("<!doctype") && !finalHTML.lowercased().hasPrefix("<html") {
        finalHTML = """
        <!DOCTYPE html><html><head><meta charset="utf-8"><style>*{box-sizing:border-box}body{font-family:system-ui,sans-serif;font-size:12pt;line-height:1.6;color:#333;padding:48px;margin:0}h1,h2,h3{color:#1a1a1a}h2{margin-top:1.5em;border-bottom:1px solid #eee}section,article,.keepsake-section,div[class*="section"],div[class*="card"]{overflow:auto;clear:both}img{max-width:100%;max-height:650px;width:auto;height:auto;object-fit:contain;display:block;clear:both;vertical-align:top}p{margin:1em 0}ul{margin:1em 0;padding-left:1.5em}@media print{body{padding:0;margin:0}h2,h3{page-break-after:avoid}img{page-break-inside:avoid;page-break-before:auto;page-break-after:auto}}</style></head><body>\(finalHTML)</body></html>
        """
    } else if let headEnd = finalHTML.range(of: "</head>", options: .caseInsensitive) {
        finalHTML.insert(contentsOf: "<style>\(overlapPreventionCSS)</style>", at: headEnd.lowerBound)
    }
    return finalHTML
}

@MainActor
private func createPDFFromHTML(html: String, title: String) async -> Data {
    let config = WKWebViewConfiguration()
    // Use a tall frame so content lays out fully; ensures contentSize reflects full height
    let pageWidth: CGFloat = 612
    let pageHeight: CGFloat = 792
    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: pageWidth, height: 20000), configuration: config)
    webView.loadHTMLString(html, baseURL: nil)

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        var observation: NSKeyValueObservation?
        observation = webView.observe(\.estimatedProgress) { wv, _ in
            if wv.estimatedProgress >= 1.0 {
                observation?.invalidate()
                continuation.resume()
            }
        }
    }

    // Match on-screen portfolio: normalize img alt / hide duplicate figcaptions before layout & PDF rasterization
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        webView.evaluateJavaScript(portfolioWebViewImagePresentationScript) { _, _ in
            cont.resume()
        }
    }

    // Allow layout to complete (images, etc.)
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec

    // Get full content height via JS; contentSize may lag for long content
    let jsHeight: CGFloat = await withCheckedContinuation { cont in
        webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight, document.documentElement.offsetHeight)") { result, _ in
            let h = (result as? NSNumber)?.doubleValue ?? 0
            cont.resume(returning: CGFloat(h))
        }
    }
    let contentHeight = max(webView.scrollView.contentSize.height, jsHeight, pageHeight)

    // Expand web view bounds so UIPrintPageRenderer sees full content for pagination
    let originalBounds = webView.bounds
    webView.bounds = CGRect(x: 0, y: 0, width: pageWidth, height: contentHeight)

    let formatter = webView.viewPrintFormatter()
    let renderer = UIPrintPageRenderer()
    renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

    let margin: CGFloat = 36
    let printableRect = CGRect(x: margin, y: margin, width: pageWidth - 2 * margin, height: pageHeight - 2 * margin)
    let paperRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

    webView.bounds = originalBounds

    let pdfData = NSMutableData()
    UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)
    renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
    let printRect = UIGraphicsGetPDFContextBounds()
    for i in 0..<renderer.numberOfPages {
        UIGraphicsBeginPDFPage()
        renderer.drawPage(at: i, in: printRect)
    }
    UIGraphicsEndPDFContext()

    return pdfData as Data
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
            kCGPDFContextTitle: "\(portfolio.studentName) - \(portfolio.portfolioLabel) Portfolio"
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
            
            // Subtitle
            let subtitleColor = style == .minimal ? design.secondaryText : UIColor.white.withAlphaComponent(0.95)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: design.sectionFont.pointSize - 4, weight: .medium),
                .foregroundColor: subtitleColor
            ]
            let subtitle = "\(portfolio.portfolioLabel) Portfolio"
            subtitle.draw(at: CGPoint(x: margin, y: (style == .minimal ? 30 : 50) + titleHeight + 10), withAttributes: subtitleAttributes)

            yPosition = headerHeight + design.sectionSpacing / 2
            
            // Parse and render portfolio content with sections
            yPosition = renderPortfolioContent(
                context: context,
                content: stripMarkdownHtmlFencesForDisplay(portfolio.compiledContent),
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
            let footerPattern = "\(portfolio.portfolioLabel) Portfolio"
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
                            currentY = renderImage(context: context, image: imageTuple, yPosition: currentY, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache, contentPairIndex: contentPairIndex)
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
                            currentY = renderImage(context: context, image: imageTuple, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache, contentPairIndex: contentPairIndex)
                        }
                    }
                } else {
                    // Not first pair: image on one page, text on another (top-aligned)
                    if shouldImageFirst, let imageTuple = pair.image {
                        context.beginPage()
                        getBackgroundColor(for: contentPairIndex, design: design).setFill()
                        context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                        drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                        currentY = renderImage(context: context, image: imageTuple, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache, contentPairIndex: contentPairIndex)
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
                        currentY = renderImage(context: context, image: imageTuple, yPosition: margin, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache, contentPairIndex: contentPairIndex + (pair.text.isEmpty ? 0 : 1))
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
                imageFirst: imageFirst,
                contentPairIndex: contentPairIndex
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
        imageFirst: Bool,
        contentPairIndex: Int
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
            y = renderImage(context: context, image: img, yPosition: y, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache, contentPairIndex: contentPairIndex)
        }
        if !textContent.isEmpty {
            y = renderTextBlock(context: context, content: textContent, yPosition: y, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design)
        }
        if !imageFirst, let img = imageTuple {
            y = renderImage(context: context, image: img, yPosition: y, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth, design: design, generatedImages: generatedImages, imageCache: imageCache, contentPairIndex: contentPairIndex)
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
            drawImagePlaceholder(context: context, rect: heroRect, design: design)
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
            drawImagePlaceholder(context: context, rect: rect, design: design)
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
    
    // Helper function to render an image (keeps image on a single page; starts new page if needed)
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
        imageCache: [String: UIImage],
        contentPairIndex: Int
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
                drawImagePlaceholder(context: context, rect: imageRect, design: design)
                currentY += 200 + design.imageSpacing
                return currentY
            }
            let cachedImage = imageCache[imageId]
            if let cachedImage = cachedImage {
                print("[PDF] Image found in cache, rendering...")
                let aspectRatio = cachedImage.size.width / cachedImage.size.height
                let maxHeight: CGFloat = 280
                var imageHeight = min(maxHeight, imageContentWidth / aspectRatio)
                let maxImageHeightOnPage = pageHeight - margin * 2 - design.imageSpacing
                imageHeight = min(imageHeight, maxImageHeightOnPage)
                let availablePageHeight = pageHeight - imageMargin - currentY - design.imageSpacing
                if imageHeight > availablePageHeight {
                    context.beginPage()
                    getBackgroundColor(for: contentPairIndex, design: design).setFill()
                    context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                    drawFancyPageBorder(pageWidth: pageWidth, pageHeight: pageHeight, design: design)
                    currentY = margin
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
                drawImagePlaceholder(context: context, rect: imageRect, design: design)
                currentY += 200 + design.imageSpacing
            }
        } else {
            drawImagePlaceholder(context: context, rect: imageRect, design: design)
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
        // Do not draw `description` (often matches DALL-E prompts or alt-like text); keep placeholder visual-only.
    }
}

private enum PDFAction {
    case print
    case share
}

// Export options: Share or Print (PDF is generated from HTML; no style selection)
struct PortfolioExportSheet: View {
    let onPrint: () -> Void
    let onShare: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Button {
                    onShare()
                } label: {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                }
                Button {
                    onPrint()
                } label: {
                    Label("Print", systemImage: "printer")
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
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

