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
                        Task {
                            await generatePDF()
                        }
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
        }
    }
    
    @MainActor
    private func generatePDF() async {
        // Create PDF from portfolio content
        let pdfCreator = PDFCreator()
        pdfData = pdfCreator.createPDF(from: portfolio)
        showingShareSheet = true
    }
}

// PDF Creator
class PDFCreator {
    func createPDF(from portfolio: Portfolio) -> Data {
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
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 60
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            let title = "\(portfolio.studentName) - \(portfolio.designPattern.rawValue) Portfolio"
            title.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Student Remarks
            if let studentRemarks = portfolio.studentRemarks, !studentRemarks.isEmpty {
                let sectionTitle = "Student Remarks"
                sectionTitle.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.label
                ])
                yPosition += 30
                
                let remarksAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]
                let remarksRect = CGRect(x: 60, y: yPosition, width: pageWidth - 120, height: 200)
                studentRemarks.draw(in: remarksRect, withAttributes: remarksAttributes)
                yPosition += 220
            }
            
            // Instructor Remarks
            if let instructorRemarks = portfolio.instructorRemarks, !instructorRemarks.isEmpty {
                if yPosition > pageHeight - 200 {
                    context.beginPage()
                    yPosition = 60
                }
                
                let sectionTitle = "Instructor Remarks"
                sectionTitle.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.label
                ])
                yPosition += 30
                
                let remarksAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.label
                ]
                let remarksRect = CGRect(x: 60, y: yPosition, width: pageWidth - 120, height: 200)
                instructorRemarks.draw(in: remarksRect, withAttributes: remarksAttributes)
                yPosition += 220
            }
            
            // Portfolio Content
            if yPosition > pageHeight - 200 {
                context.beginPage()
                yPosition = 60
            }
            
            let contentTitle = "Portfolio Content"
            contentTitle.draw(at: CGPoint(x: 60, y: yPosition), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.label
            ])
            yPosition += 30
            
            let contentAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            let contentRect = CGRect(x: 60, y: yPosition, width: pageWidth - 120, height: pageHeight - yPosition - 60)
            portfolio.compiledContent.draw(in: contentRect, withAttributes: contentAttributes)
        }
        
        return data
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

