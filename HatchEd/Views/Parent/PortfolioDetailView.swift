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
        // Create PDF from portfolio content with selected style
        let pdfCreator = PDFCreator()
        pdfData = pdfCreator.createPDF(from: portfolio, style: selectedStyle)
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
        case .modern: return "Clean lines with blue accents"
        case .classic: return "Traditional black and white"
        case .elegant: return "Sophisticated purple theme"
        case .vibrant: return "Bold colors and energy"
        case .minimal: return "Simple and uncluttered"
        case .professional: return "Corporate blue and gray"
        }
    }
    
    var colorScheme: PDFColorScheme {
        switch self {
        case .modern:
            return PDFColorScheme(
                accent: .systemBlue,
                background: .systemGray6,
                card: .white,
                text: .label,
                secondaryText: .secondaryLabel
            )
        case .classic:
            return PDFColorScheme(
                accent: .black,
                background: .white,
                card: .systemGray6,
                text: .black,
                secondaryText: .darkGray
            )
        case .elegant:
            return PDFColorScheme(
                accent: .systemPurple,
                background: UIColor(red: 0.98, green: 0.96, blue: 1.0, alpha: 1.0),
                card: .white,
                text: .label,
                secondaryText: .secondaryLabel
            )
        case .vibrant:
            return PDFColorScheme(
                accent: .systemOrange,
                background: UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0),
                card: .white,
                text: .label,
                secondaryText: .secondaryLabel
            )
        case .minimal:
            return PDFColorScheme(
                accent: .systemGray,
                background: .white,
                card: .white,
                text: .label,
                secondaryText: .secondaryLabel
            )
        case .professional:
            return PDFColorScheme(
                accent: UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0),
                background: UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0),
                card: .white,
                text: .label,
                secondaryText: .secondaryLabel
            )
        }
    }
}

struct PDFColorScheme {
    let accent: UIColor
    let background: UIColor
    let card: UIColor
    let text: UIColor
    let secondaryText: UIColor
}

// PDF Creator - Graphical PDF Generation
class PDFCreator {
    func createPDF(from portfolio: Portfolio, style: PDFStyle = .modern) -> Data {
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
        
        // Get color scheme based on style
        let colorScheme = style.colorScheme
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            // Draw background based on style
            colorScheme.background.setFill()
            context.fill(pageRect)
            
            var yPosition: CGFloat = margin
            
            // Header with style-specific design
            let headerHeight: CGFloat = style == .minimal ? 80 : 120
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: headerHeight)
            
            if style == .minimal {
                // Minimal style: no header background, just a line
                colorScheme.accent.setStroke()
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: headerHeight - 2))
                linePath.addLine(to: CGPoint(x: pageWidth - margin, y: headerHeight - 2))
                linePath.lineWidth = 2
                linePath.stroke()
            } else {
                // Other styles: colored header background
                colorScheme.accent.setFill()
                context.fill(headerRect)
            }
            
            // Title in header - style-specific
            let titleColor = style == .minimal ? colorScheme.accent : UIColor.white
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: style == .minimal ? 24 : 28),
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
            title.draw(at: CGPoint(x: margin, y: style == .minimal ? 30 : 40), withAttributes: titleAttributes)
            
            // Subtitle
            let subtitleColor = style == .minimal ? colorScheme.secondaryText : UIColor.white.withAlphaComponent(0.9)
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: style == .minimal ? 14 : 16, weight: .medium),
                .foregroundColor: subtitleColor
            ]
            let subtitle = "\(portfolio.designPattern.rawValue) Portfolio"
            subtitle.draw(at: CGPoint(x: margin, y: (style == .minimal ? 30 : 40) + titleHeight + 8), withAttributes: subtitleAttributes)
            
            yPosition = headerHeight + 30
            
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
                colorScheme: colorScheme,
                generatedImages: portfolio.generatedImages
            )
            
            // Student Remarks Section (if not already in compiled content)
            if let studentRemarks = portfolio.studentRemarks, !studentRemarks.isEmpty, !portfolio.compiledContent.contains("Student Remarks") {
                if yPosition > pageHeight - 250 {
                    context.beginPage()
                    colorScheme.background.setFill()
                    context.fill(pageRect)
                    yPosition = margin
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
                    style: style,
                    colorScheme: colorScheme
                )
            }
            
            // Instructor Remarks Section (if not already in compiled content)
            if let instructorRemarks = portfolio.instructorRemarks, !instructorRemarks.isEmpty, !portfolio.compiledContent.contains("Instructor Remarks") {
                if yPosition > pageHeight - 250 {
                    context.beginPage()
                    colorScheme.background.setFill()
                    context.fill(pageRect)
                    yPosition = margin
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
                    style: style,
                    colorScheme: colorScheme
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
        style: PDFStyle,
        colorScheme: PDFColorScheme
    ) -> CGFloat {
        var currentY = yPosition
        
        // Section title
        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: style == .minimal ? 18 : 20),
            .foregroundColor: colorScheme.accent
        ]
        let sectionTitleBoundingRect = NSString(string: title).boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: sectionTitleAttributes,
            context: nil
        )
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height)
        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionTitleAttributes)
        currentY += sectionTitleHeight + 15
        
        // Content in styled card
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: style == .minimal ? 10 : 11),
            .foregroundColor: colorScheme.text,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.lineSpacing = 4
                style.paragraphSpacing = 8
                return style
            }()
        ]
        
        let contentBoundingRect = NSString(string: content).boundingRect(
            with: CGSize(width: contentWidth - 40, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: contentAttributes,
            context: nil
        )
        let contentHeight = ceil(contentBoundingRect.height)
        
        // Draw card background
        let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: contentHeight + 40)
        colorScheme.card.setFill()
        context.fill(cardRect)
        
        // Draw card border - style-specific
        if style != .minimal {
            colorScheme.accent.setStroke()
            let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: style == .classic ? 0 : 8)
            borderPath.lineWidth = style == .classic ? 1 : 2
            borderPath.stroke()
        } else {
            // Minimal: subtle border
            colorScheme.secondaryText.withAlphaComponent(0.3).setStroke()
            let borderPath = UIBezierPath(rect: cardRect)
            borderPath.lineWidth = 1
            borderPath.stroke()
        }
        
        // Draw content text
        let textRect = cardRect.insetBy(dx: 20, dy: 20)
        let attributedContent = NSAttributedString(string: content, attributes: contentAttributes)
        attributedContent.draw(in: textRect)
        
        currentY += contentHeight + 50
        
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
        colorScheme: PDFColorScheme,
        generatedImages: [PortfolioImage]
    ) -> CGFloat {
        var currentY = yPosition
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
                style: style,
                colorScheme: colorScheme
            )
        }
        
        // Render each section
        for section in allSections {
            // Check if we need a new page
            if currentY > pageHeight - 300 {
                context.beginPage()
                colorScheme.background.setFill()
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
                style: style,
                colorScheme: colorScheme,
                generatedImages: generatedImages
            )
        }
        
        return currentY
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
        style: PDFStyle,
        colorScheme: PDFColorScheme,
        generatedImages: [PortfolioImage]
    ) -> CGFloat {
        var currentY = yPosition
        
        // Section title
        let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: style == .minimal ? 18 : 20),
            .foregroundColor: colorScheme.accent
        ]
        let sectionTitleBoundingRect = NSString(string: title).boundingRect(
            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: sectionTitleAttributes,
            context: nil
        )
        let sectionTitleHeight = ceil(sectionTitleBoundingRect.height) + (style == .minimal ? 0 : colorScheme.accent.cgColor.components?[0] != nil ? 0 : 0)
        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionTitleAttributes)
        currentY += sectionTitleHeight + 15
        
        // Process content lines - handle text and image placeholders in order
        var processedContent: [(type: String, content: String)] = []
        
        for line in content {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[IMAGE:") && trimmed.hasSuffix("]") {
                // Extract image description
                let description = String(trimmed.dropFirst(7).dropLast(1)).trimmingCharacters(in: .whitespaces)
                processedContent.append((type: "image", content: description))
            } else if !trimmed.isEmpty {
                // Check if we need to append to last text block or create new one
                if let last = processedContent.last, last.type == "text" {
                    processedContent[processedContent.count - 1] = (type: "text", content: last.content + "\n" + line)
                } else {
                    processedContent.append((type: "text", content: line))
                }
            }
        }
        
        // Render processed content in order
        for item in processedContent {
            if currentY > pageHeight - 200 {
                context.beginPage()
                colorScheme.background.setFill()
                context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
                currentY = margin
            }
            
            if item.type == "image" {
                // Find matching generated image by description
                let matchingImage = generatedImages.first { image in
                    image.description.lowercased() == item.content.lowercased() ||
                    item.content.lowercased().contains(image.description.lowercased()) ||
                    image.description.lowercased().contains(item.content.lowercased())
                }
                
                let imageRect = CGRect(x: margin, y: currentY, width: contentWidth, height: 200)
                
                if let image = matchingImage, let imageUrl = URL(string: image.url) {
                    // Try to load and draw the actual image synchronously
                    // Note: In production, you might want to pre-download images
                    if let imageData = try? Data(contentsOf: imageUrl),
                       let uiImage = UIImage(data: imageData) {
                        // Draw the actual image with proper aspect ratio
                        let aspectRatio = uiImage.size.width / uiImage.size.height
                        let maxHeight: CGFloat = 250
                        let imageHeight = min(maxHeight, contentWidth / aspectRatio)
                        let imageWidth = min(contentWidth, imageHeight * aspectRatio)
                        let imageDrawRect = CGRect(
                            x: margin + (contentWidth - imageWidth) / 2,
                            y: currentY,
                            width: imageWidth,
                            height: imageHeight
                        )
                        uiImage.draw(in: imageDrawRect)
                        currentY += imageHeight + 20
                    } else {
                        // Fallback to placeholder if image fails to load
                        drawImagePlaceholder(context: context, rect: imageRect, description: item.content, colorScheme: colorScheme)
                        currentY += 200 + 20
                    }
                } else {
                    // No matching image found, draw placeholder
                    drawImagePlaceholder(context: context, rect: imageRect, description: item.content, colorScheme: colorScheme)
                    currentY += 200 + 20
                }
            } else {
                // Draw text content in styled card
                let contentAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: style == .minimal ? 10 : 11),
                    .foregroundColor: colorScheme.text,
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineSpacing = 4
                        style.paragraphSpacing = 8
                        return style
                    }()
                ]
                
                let contentBoundingRect = NSString(string: item.content).boundingRect(
                    with: CGSize(width: contentWidth - 40, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: contentAttributes,
                    context: nil
                )
                let contentHeight = ceil(contentBoundingRect.height)
                
                // Draw card background
                let cardRect = CGRect(x: margin, y: currentY, width: contentWidth, height: contentHeight + 40)
                colorScheme.card.setFill()
                context.fill(cardRect)
                
                // Draw card border
                if style != .minimal {
                    colorScheme.accent.setStroke()
                    let borderPath = UIBezierPath(roundedRect: cardRect, cornerRadius: style == .classic ? 0 : 8)
                    borderPath.lineWidth = style == .classic ? 1 : 2
                    borderPath.stroke()
                } else {
                    colorScheme.secondaryText.withAlphaComponent(0.3).setStroke()
                    let borderPath = UIBezierPath(rect: cardRect)
                    borderPath.lineWidth = 1
                    borderPath.stroke()
                }
                
                // Draw content text
                let textRect = cardRect.insetBy(dx: 20, dy: 20)
                let attributedContent = NSAttributedString(string: item.content, attributes: contentAttributes)
                attributedContent.draw(in: textRect)
                
                currentY += contentHeight + 50
            }
        }
        
        return currentY
    }
    
    // Helper function to draw image placeholder
    private func drawImagePlaceholder(
        context: UIGraphicsPDFRendererContext,
        rect: CGRect,
        description: String,
        colorScheme: PDFColorScheme
    ) {
        // Draw background
        colorScheme.secondaryText.withAlphaComponent(0.1).setFill()
        context.fill(rect)
        
        // Draw border (dashed for placeholder)
        colorScheme.accent.setStroke()
        let borderPath = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        borderPath.lineWidth = 2
        let dashPattern: [CGFloat] = [5, 5]
        borderPath.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        borderPath.stroke()
        
        // Draw image icon
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32),
            .foregroundColor: colorScheme.secondaryText.withAlphaComponent(0.4)
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
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: colorScheme.secondaryText
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

