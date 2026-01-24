//
//  PortfolioDetailView.swift
//  HatchEd
//
//  Created by Sandi Junker on 11/7/25.
//

import SwiftUI
import PDFKit

struct PortfolioDetailView: View {
    let portfolio: Portfolio
    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var showingShareSheet = false
    @State private var showingStyleSelection = false
    @State private var selectedStyle: PDFStyle = .modern
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(portfolio.studentName)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.hatchEdText)
                        
                        Text(portfolio.designPattern.rawValue + " Portfolio")
                            .font(.headline)
                            .foregroundColor(.hatchEdSecondaryText)
                        
                        if let createdAt = portfolio.createdAt {
                            Text("Created: \(createdAt.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.hatchEdSecondaryText)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
                    )
                    
                    // Student Remarks
                    if let studentRemarks = portfolio.studentRemarks, !studentRemarks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Student Remarks")
                                .font(.headline)
                                .foregroundColor(.hatchEdText)
                            Text(studentRemarks)
                                .font(.body)
                                .foregroundColor(.hatchEdText)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.hatchEdCardBackground)
                        )
                    }
                    
                    // Instructor Remarks
                    if let instructorRemarks = portfolio.instructorRemarks, !instructorRemarks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructor Remarks")
                                .font(.headline)
                                .foregroundColor(.hatchEdText)
                            Text(instructorRemarks)
                                .font(.body)
                                .foregroundColor(.hatchEdText)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.hatchEdCardBackground)
                        )
                    }
                    
                    // Compiled Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Portfolio Content")
                            .font(.headline)
                            .foregroundColor(.hatchEdText)
                        Text(portfolio.compiledContent)
                            .font(.body)
                            .foregroundColor(.hatchEdText)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.hatchEdCardBackground)
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
                PDFStyleSelectionSheet(selectedStyle: $selectedStyle) {
                    showingStyleSelection = false
                    Task {
                        await generatePDF()
                    }
                }
            }
        }
    }
    
    @MainActor
    private func generatePDF() async {
        // Pre-load all images asynchronously before PDF generation
        var imageCache: [String: UIImage] = [:]
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for image in portfolio.generatedImages {
                group.addTask {
                    if let url = URL(string: image.url) {
                        do {
                            print("[PDF] Loading image from: \(url.absoluteString.prefix(50))...")
                            var request = URLRequest(url: url)
                            request.setValue("image/*", forHTTPHeaderField: "Accept")
                            
                            let (data, response) = try await URLSession.shared.data(for: request)
                            
                            if let httpResponse = response as? HTTPURLResponse {
                                print("[PDF] Response status: \(httpResponse.statusCode)")
                                print("[PDF] Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                                print("[PDF] Data size: \(data.count) bytes")
                                
                                if httpResponse.statusCode != 200 {
                                    if let errorString = String(data: data, encoding: .utf8) {
                                        print("[PDF] Error response: \(errorString.prefix(300))")
                                    }
                                    // If authentication failed or URL expired, return nil
                                    if httpResponse.statusCode == 403 || httpResponse.statusCode == 404 {
                                        print("[PDF] Image URL appears to be expired or inaccessible (status \(httpResponse.statusCode))")
                                        return (image.url, nil)
                                    }
                                }
                            }
                            
                            // Only try to create UIImage if we got a 200 response
                            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                                if let uiImage = UIImage(data: data) {
                                    print("[PDF] Successfully loaded image: \(image.description) (\(uiImage.size.width)x\(uiImage.size.height))")
                                    return (image.url, uiImage)
                                } else {
                                    print("[PDF] Failed to create UIImage from data (size: \(data.count) bytes)")
                                    // Try to see if it's a different format
                                    if data.count > 0 {
                                        let firstBytes = data.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " ")
                                        print("[PDF] First 8 bytes (hex): \(firstBytes)")
                                    }
                                }
                            } else {
                                print("[PDF] Skipping image creation due to non-200 status")
                            }
                        } catch {
                            print("[PDF] Failed to load image: \(error.localizedDescription)")
                            if let urlError = error as? URLError {
                                print("[PDF] URL Error code: \(urlError.code.rawValue)")
                            }
                        }
                    } else {
                        print("[PDF] Invalid URL: \(image.url)")
                    }
                    return (image.url, nil)
                }
            }
            
            for await (url, image) in group {
                if let image = image {
                    // Store with both full URL and base URL (without query params) as keys
                    imageCache[url] = image
                    if let urlObj = URL(string: url), let baseUrl = urlObj.absoluteString.components(separatedBy: "?").first {
                        imageCache[baseUrl] = image
                    }
                    print("[PDF] Added image to cache: \(url.prefix(50))...")
                } else {
                    print("[PDF] Failed to cache image: \(url.prefix(50))...")
                }
            }
        }
        
        print("[PDF] Image cache populated with \(imageCache.count) images out of \(portfolio.generatedImages.count) total")
        print("[PDF] Portfolio has \(portfolio.generatedImages.count) generated images")
        for (idx, img) in portfolio.generatedImages.enumerated() {
            print("[PDF] Image \(idx): '\(img.description)' -> \(img.url.prefix(60))...")
        }
        
        // Create PDF from portfolio content with selected style and pre-loaded images
        let pdfCreator = PDFCreator()
        pdfData = pdfCreator.createPDF(from: portfolio, style: selectedStyle, imageCache: imageCache)
        showingShareSheet = true
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
                textBorderWidth: 1
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
                textBorderWidth: 1
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
                titleFont: UIFont(name: "Georgia-Bold", size: 28) ?? UIFont.boldSystemFont(ofSize: 28),
                sectionFont: UIFont(name: "Georgia-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20),
                bodyFont: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
                cornerRadius: 16,
                shadowOffset: CGSize(width: 0, height: 4),
                shadowBlur: 12,
                shadowOpacity: 0.2,
                imageSpacing: 40,
                textSpacing: 25,
                sectionSpacing: 45,
                textBorderStyle: .accent,
                textBorderWidth: 2
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
                textBorderWidth: 3
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
                textBorderWidth: 0
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
                textBorderWidth: 4
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
}

// PDF Creator - Graphical PDF Generation
class PDFCreator {
    private var contentPairIndex = 0 // Track pairs for alternating text/image order and background colors
    
    func createPDF(from portfolio: Portfolio, style: PDFStyle = .modern, imageCache: [String: UIImage] = [:]) -> Data {
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
            let subtitle = "\(portfolio.designPattern.rawValue) Portfolio"
            subtitle.draw(at: CGPoint(x: margin, y: (style == .minimal ? 30 : 50) + titleHeight + 10), withAttributes: subtitleAttributes)
            
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
            
            // Student Remarks Section (if not already in compiled content)
            if let studentRemarks = portfolio.studentRemarks, !studentRemarks.isEmpty, !portfolio.compiledContent.contains("Student Remarks") {
                if yPosition > pageHeight - 250 {
                    context.beginPage()
                    let bgColor = getBackgroundColor(for: contentPairIndex, design: design)
                    bgColor.setFill()
                    context.fill(pageRect)
                    yPosition = margin
                    contentPairIndex += 1
                }
                
                yPosition = drawSection(
                    context: context,
                    title: "Student Remarks",
                    content: studentRemarks,
                    yPosition: yPosition,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth,
                    design: design
                )
            }
            
            // Instructor Remarks Section (if not already in compiled content)
            if let instructorRemarks = portfolio.instructorRemarks, !instructorRemarks.isEmpty, !portfolio.compiledContent.contains("Instructor Remarks") {
                if yPosition > pageHeight - 250 {
                    context.beginPage()
                    let bgColor = getBackgroundColor(for: contentPairIndex, design: design)
                    bgColor.setFill()
                    context.fill(pageRect)
                    yPosition = margin
                    contentPairIndex += 1
                }
                
                yPosition = drawSection(
                    context: context,
                    title: "Instructor Remarks",
                    content: instructorRemarks,
                    yPosition: yPosition,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth,
                    design: design
                )
            }
        }
        
        return data
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
        
        // Section title with design-specific font
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
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height)
        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionTitleAttributes)
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
            with: CGSize(width: contentWidth - (horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        let contentHeight = ceil(contentBoundingRect.height)
        
        // Draw section background
        let sectionBgRect = CGRect(x: margin, y: currentY - 10, width: contentWidth, height: contentHeight + (verticalPadding * 2) + 20)
        design.sectionBackground.setFill()
        context.fill(sectionBgRect)
        
        // Draw card background with shadow
        let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: contentHeight + (verticalPadding * 2))
        
        // Apply shadow if enabled
        if design.shadowOpacity > 0 {
            context.cgContext.setShadow(
                offset: design.shadowOffset,
                blur: design.shadowBlur,
                color: UIColor.black.withAlphaComponent(design.shadowOpacity).cgColor
            )
        }
        
        design.card.setFill()
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
            let accentBarRect = CGRect(x: margin, y: currentY, width: design.textBorderWidth, height: cardRect.height)
            context.fill(accentBarRect)
        case .topBottom:
            // Top and bottom borders only
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
        
        // Parse markdown sections
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                // Save previous section
                if let section = currentSection {
                    allSections.append(section)
                }
                // Start new section
                let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentSection = (title: title, content: [])
            } else if trimmed.hasPrefix("# ") {
                // Main title - skip or handle separately
                continue
            } else if let section = currentSection {
                // Add line to current section
                var sectionContent = section.content
                sectionContent.append(line)
                currentSection = (title: section.title, content: sectionContent)
            } else {
                // Content before first section
                if allSections.isEmpty && currentSection == nil {
                    // Create a default section for content before first ##
                    currentSection = (title: "Introduction", content: [line])
                }
            }
        }
        
        // Add last section
        if let section = currentSection {
            allSections.append(section)
        }
        
        // If no sections found, render as single block
        if allSections.isEmpty {
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
        
        // Render each section
        for section in allSections {
            // Check if we need a new page
            if currentY > pageHeight - 300 {
                context.beginPage()
                // Use alternating background colors for vibrant style
                let bgColor = getBackgroundColor(for: contentPairIndex, design: design)
                bgColor.setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                currentY = margin
            }
            
            // Render section with image placeholders
            currentY = drawPortfolioSection(
                context: context,
                title: section.title,
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
    
    // Draw a portfolio section with image placeholders
    private func drawPortfolioSection(
        context: UIGraphicsPDFRendererContext,
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
        
        // Section title with design-specific font
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
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height)
        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionTitleAttributes)
        currentY += sectionTitleHeight + design.textSpacing
        
        // Process content lines - handle text and image placeholders in order
        var processedContent: [(type: String, content: String, index: Int?)] = []
        
        for line in content {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[IMAGE:") && trimmed.hasSuffix("]") {
                // Extract image description and use global index
                let description = String(trimmed.dropFirst(7).dropLast(1)).trimmingCharacters(in: .whitespaces)
                processedContent.append((type: "image", content: description, index: globalImageIndex))
                globalImageIndex += 1
            } else if !trimmed.isEmpty {
                // Check if we need to append to last text block or create new one
                if let last = processedContent.last, last.type == "text" {
                    let lastIndex = processedContent.count - 1
                    processedContent[lastIndex] = (type: "text", content: last.content + "\n" + line, index: nil)
                } else {
                    processedContent.append((type: "text", content: line, index: nil))
                }
            }
        }
        
        // Group content into text-image pairs
        var contentPairs: [(text: [(type: String, content: String, index: Int?)], image: (type: String, content: String, index: Int?)?)] = []
        var currentText: [(type: String, content: String, index: Int?)] = []
        
        for item in processedContent {
            if item.type == "image" {
                // Save current text and image as a pair
                contentPairs.append((text: currentText, image: item))
                currentText = []
            } else {
                currentText.append(item)
            }
        }
        // Add any remaining text without an image
        if !currentText.isEmpty {
            contentPairs.append((text: currentText, image: nil))
        }
        
        print("[PDF] Created \(contentPairs.count) content pairs")
        for (index, pair) in contentPairs.enumerated() {
            if let img = pair.image {
                print("[PDF] Pair \(index): text lines=\(pair.text.count), image='\(img.content)' (index: \(img.index ?? -1))")
            } else {
                print("[PDF] Pair \(index): text lines=\(pair.text.count), image=none")
            }
        }
        
        // Render content pairs, alternating order
        for pair in contentPairs {
            if currentY > pageHeight - 200 {
                context.beginPage()
                let bgColor = getBackgroundColor(for: contentPairIndex, design: design)
                bgColor.setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                currentY = margin
            }
            
            // Alternate order: even pairs = text first, odd pairs = image first
            let shouldImageFirst = (contentPairIndex % 2 == 1)
            
            if shouldImageFirst, let imageTuple = pair.image {
                // Render image first
                currentY = renderImage(
                    context: context,
                    image: imageTuple,
                    yPosition: currentY,
                    pageWidth: pageWidth,
                    pageHeight: pageHeight,
                    margin: margin,
                    contentWidth: contentWidth,
                    design: design,
                    generatedImages: generatedImages,
                    imageCache: imageCache
                )
                
                // Then render text
                if !pair.text.isEmpty {
                    let textContent = pair.text.map { $0.content }.joined(separator: "\n")
                    currentY = renderTextBlock(
                        context: context,
                        content: textContent,
                        yPosition: currentY,
                        pageWidth: pageWidth,
                        pageHeight: pageHeight,
                        margin: margin,
                        contentWidth: contentWidth,
                        design: design
                    )
                }
            } else {
                // Render text first
                if !pair.text.isEmpty {
                    let textContent = pair.text.map { $0.content }.joined(separator: "\n")
                    currentY = renderTextBlock(
                        context: context,
                        content: textContent,
                        yPosition: currentY,
                        pageWidth: pageWidth,
                        pageHeight: pageHeight,
                        margin: margin,
                        contentWidth: contentWidth,
                        design: design
                    )
                }
                
                // Then render image
                if let imageTuple = pair.image {
                    currentY = renderImage(
                        context: context,
                        image: imageTuple,
                        yPosition: currentY,
                        pageWidth: pageWidth,
                        pageHeight: pageHeight,
                        margin: margin,
                        contentWidth: contentWidth,
                        design: design,
                        generatedImages: generatedImages,
                        imageCache: imageCache
                    )
                }
            }
            
            contentPairIndex += 1
        }
        
        return currentY
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
        
        let imageRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 200)
        
        if let img = matchingImage {
            print("[PDF] Attempting to render image: \(img.description)")
            print("[PDF] Image URL: \(img.url.prefix(80))...")
            
            // Try to get image from cache - try full URL first, then base URL
            var uiImage: UIImage? = imageCache[img.url]
            if uiImage == nil, let urlObj = URL(string: img.url), let baseUrl = urlObj.absoluteString.components(separatedBy: "?").first {
                uiImage = imageCache[baseUrl]
                print("[PDF] Tried base URL: \(baseUrl.prefix(50))...")
            }
            
            if let cachedImage = uiImage {
                print("[PDF] Image found in cache, rendering...")
                // Calculate image size - full width, centered
                let aspectRatio = cachedImage.size.width / cachedImage.size.height
            let maxHeight: CGFloat = 280
            let imageHeight = min(maxHeight, contentWidth / aspectRatio)
            let imageWidth = min(contentWidth, imageHeight * aspectRatio)
            
            // Center image horizontally
            let imageX = margin + (contentWidth - imageWidth) / 2
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
                width: imageWidth,
                height: imageHeight
            )
            
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
                print("[PDF] Image not in cache for URL: \(img.url)")
                print("[PDF] Cache has \(imageCache.count) images")
                // Fallback to placeholder
                drawImagePlaceholder(context: context, rect: imageRect, description: image.content, design: design)
                currentY += 200 + design.imageSpacing
            }
        } else {
            print("[PDF] No matching image found for description: '\(image.content)'")
            print("[PDF] Available images: \(generatedImages.map { $0.description })")
            // Fallback to placeholder
            drawImagePlaceholder(context: context, rect: imageRect, description: image.content, design: design)
            currentY += 200 + design.imageSpacing
        }
        
        return currentY
    }
    
    // Helper function to render a text block
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
        var currentY = yPosition
        
        // Draw text content with style-specific borders
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
            with: CGSize(width: contentWidth - (horizontalPadding * 2), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        let contentHeight = ceil(contentBoundingRect.height)
        
        // Draw section background
        let sectionBgRect = CGRect(x: margin, y: currentY - 10, width: contentWidth, height: contentHeight + (verticalPadding * 2) + 20)
        design.sectionBackground.setFill()
        context.fill(sectionBgRect)
        
        // Draw card background with shadow
        let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: contentHeight + (verticalPadding * 2))
        
        // Apply shadow if enabled
        if design.shadowOpacity > 0 {
            context.cgContext.setShadow(
                offset: design.shadowOffset,
                blur: design.shadowBlur,
                color: UIColor.black.withAlphaComponent(design.shadowOpacity).cgColor
            )
        }
        
        design.card.setFill()
        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
        cardPath.fill()
        
        // Reset shadow for border
        context.cgContext.setShadow(offset: .zero, blur: 0)
        
        // Draw border based on style
        switch design.textBorderStyle {
        case .none:
            break
        case .solid:
            if let secondaryAccent = design.accentSecondary {
                design.accent.setStroke()
                let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
                borderPath.lineWidth = design.textBorderWidth
                borderPath.stroke()
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
            design.secondaryText.withAlphaComponent(0.3).setStroke()
            let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
            borderPath.lineWidth = design.textBorderWidth
            borderPath.stroke()
        case .accent:
            design.accent.setStroke()
            let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: design.cornerRadius)
            borderPath.lineWidth = design.textBorderWidth
            borderPath.stroke()
        case .leftAccent:
            design.accent.setFill()
            let accentBarRect = CGRect(x: margin, y: currentY, width: design.textBorderWidth, height: cardRect.height)
            context.fill(accentBarRect)
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
        
        // Draw content text with appropriate padding
        let textRect = cardRect.insetBy(dx: horizontalPadding, dy: verticalPadding)
        let attributedContent = NSAttributedString(string: content, attributes: contentAttributes)
        attributedContent.draw(in: textRect)
        
        currentY += contentHeight + (verticalPadding * 2) + design.textSpacing
        
        return currentY
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

// PDF Style Selection Sheet
struct PDFStyleSelectionSheet: View {
    @Binding var selectedStyle: PDFStyle
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.hatchEdAccent)
                }
            }
        }
    }
}

// Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

