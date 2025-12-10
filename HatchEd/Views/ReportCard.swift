//
//  ReportCard.swift
//  HatchEd
//
//  Created by Sandi Junker on 10/22/25.
//  Updated with assistance from Cursor (ChatGPT) on 11/7/25.
//
import SwiftUI
import PDFKit
import UIKit

struct ReportCard: View {
    @EnvironmentObject private var signInManager: AppleSignInManager
    @State private var courses: [Course] = []
    @State private var attendanceRecords: [String: [AttendanceRecordDTO]] = [:] // studentId -> records
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pdfData: Data?
    @State private var pdfURL: URL?
    @State private var showingShareSheet = false
    @State private var showingPrintSheet = false
    
    private let api = APIClient.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if courses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 64))
                            .foregroundColor(.hatchEdSecondaryText)
                        Text("No courses found")
                            .font(.headline)
                            .foregroundColor(.hatchEdSecondaryText)
                        Text("Add courses in the Curriculum section to see report cards")
                            .font(.subheadline)
                            .foregroundColor(.hatchEdSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Group courses by student
                    let coursesByStudent = Dictionary(grouping: courses) { $0.student.id }
                    
                    ForEach(signInManager.students) { student in
                        if let studentCourses = coursesByStudent[student.id], !studentCourses.isEmpty {
                            studentReportCard(student: student, courses: studentCourses)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.hatchEdCoralAccent)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Report Cards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task {
                            await generatePDF()
                        }
                    } label: {
                        Label("Download PDF", systemImage: "square.and.arrow.down")
                    }
                    
                    Button {
                        Task {
                            await printReportCard()
                        }
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            Task {
                await loadCourses()
            }
        }
        .refreshable {
            await loadCourses()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURL = pdfURL {
                ShareSheet(activityItems: [pdfURL])
            } else if let pdfData = pdfData {
                ShareSheet(activityItems: [pdfData])
            }
        }
        .onDisappear {
            // Clean up temporary file when view disappears
            if let pdfURL = pdfURL {
                try? FileManager.default.removeItem(at: pdfURL)
            }
        }
        .background(Color.hatchEdBackground)
    }
    
    private func studentReportCard(student: User, courses: [Course]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Student Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.hatchEdAccent)
                    .font(.title2)
                Text(student.name ?? "Student")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.hatchEdText)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hatchEdAccentBackground)
            )
            
            // Attendance Summary
            if let records = attendanceRecords[student.id], !records.isEmpty {
                AttendanceSummaryRow(records: records)
            }
            
            // Courses List
            VStack(spacing: 12) {
                ForEach(courses.sorted(by: { $0.name < $1.name })) { course in
                    CourseGradeRow(course: course)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.hatchEdCardBackground)
                .shadow(color: Color.hatchEdAccent.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    @MainActor
    private func loadCourses() async {
        isLoading = true
        errorMessage = nil
        do {
            courses = try await api.fetchCourses()
            // Calculate grade for each course based on its assignments
            courses = courses.map { course in
                var updatedCourse = course
                // Always calculate from assignments
                updatedCourse.grade = calculateCourseGrade(for: course)
                return updatedCourse
            }
            
            // Load attendance for each student
            await loadAttendanceForStudents()
        } catch {
            errorMessage = "Failed to load courses: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    @MainActor
    private func loadAttendanceForStudents() async {
        var recordsDict: [String: [AttendanceRecordDTO]] = [:]
        
        // Fetch attendance for each student (limit to last 90 days for report card)
        for student in signInManager.students {
            do {
                let records = try await api.fetchAttendance(studentUserId: student.id, limit: 90)
                recordsDict[student.id] = records
            } catch {
                // Silently fail for attendance - don't block report card display
                print("Failed to load attendance for student \(student.id): \(error.localizedDescription)")
            }
        }
        
        attendanceRecords = recordsDict
    }
    
    private func calculateCourseGrade(for course: Course) -> Double? {
        // Filter to only graded assignments (have both pointsAwarded and pointsPossible)
        let gradedAssignments = course.assignments.filter { assignment in
            assignment.pointsAwarded != nil && assignment.pointsPossible != nil && assignment.pointsPossible! > 0
        }
        guard !gradedAssignments.isEmpty else { return nil }
        
        // Sum all pointsAwarded
        let totalPointsAwarded = gradedAssignments.reduce(0.0) { sum, assignment in
            sum + (assignment.pointsAwarded ?? 0)
        }
        
        // Sum all pointsPossible
        let totalPointsPossible = gradedAssignments.reduce(0.0) { sum, assignment in
            sum + (assignment.pointsPossible ?? 0)
        }
        
        guard totalPointsPossible > 0 else { return nil }
        
        // Calculate percentage: (total earned / total possible) * 100
        return (totalPointsAwarded / totalPointsPossible) * 100
    }
    
    @MainActor
    private func generatePDF() async {
        let pdfCreator = ReportCardPDFCreator()
        // Create PDF optimized for digital viewing (smaller margins, uses more of the page)
        let data = pdfCreator.createPDF(
            students: signInManager.students,
            courses: courses,
            attendanceRecords: attendanceRecords,
            forPrinting: false
        )
        pdfData = data
        
        // Create a temporary file with proper name for sharing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ReportCards_\(Date().timeIntervalSince1970).pdf")
        do {
            try data.write(to: tempURL)
            pdfURL = tempURL
            showingShareSheet = true
        } catch {
            errorMessage = "Failed to create PDF file: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func printReportCard() async {
        let pdfCreator = ReportCardPDFCreator()
        // Create PDF optimized for printing (larger margins, printer-safe)
        let pdfData = pdfCreator.createPDF(
            students: signInManager.students,
            courses: courses,
            attendanceRecords: attendanceRecords,
            forPrinting: true
        )
        
        // Check if PDF data is valid
        guard !pdfData.isEmpty else {
            errorMessage = "Failed to generate PDF: No data"
            return
        }
        
        // Use UIPrintInteractionController for printing
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Report Cards"
        printInfo.orientation = .portrait
        printInfo.duplex = .none
        printController.printInfo = printInfo
        
        // Set print settings to ensure proper scaling
        printController.showsNumberOfCopies = false
        printController.showsPaperSelectionForLoadedPapers = false
        
        // Use PDF data directly for printing (more reliable than file URL)
        printController.printingItem = pdfData
        
        // For iPad support, we need to set the popover presentation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            printController.present(animated: true, completionHandler: { (controller, completed, error) in
                if let error = error {
                    errorMessage = "Print failed: \(error.localizedDescription)"
                }
            })
        } else {
            // Fallback presentation
            printController.present(animated: true, completionHandler: { (controller, completed, error) in
                if let error = error {
                    errorMessage = "Print failed: \(error.localizedDescription)"
                }
            })
        }
    }
}

// PDF Creator for Report Cards
class ReportCardPDFCreator {
    func createPDF(students: [User], courses: [Course], attendanceRecords: [String: [AttendanceRecordDTO]], forPrinting: Bool = false) -> Data {
        let pdfMetaData: [String: Any] = [
            kCGPDFContextCreator as String: "HatchEd",
            kCGPDFContextAuthor as String: "HatchEd App",
            kCGPDFContextTitle as String: "Report Cards"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData
        
        // Use standard US Letter size (8.5" x 11")
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        
        // Use different margins based on whether this is for printing or digital viewing
        let topMargin: CGFloat
        let bottomMargin: CGFloat
        let sideMargin: CGFloat
        
        if forPrinting {
            // Printer-safe margins - account for printer's unprintable areas
            // Most printers have ~0.25-0.5" unprintable margins, so we add extra buffer
            topMargin = 108  // 1.5 inches - extra buffer for printer margins
            bottomMargin = 90  // 1.25 inches
            sideMargin = 90  // 1.25 inches
        } else {
            // Digital viewing margins - smaller, uses more of the page
            topMargin = 36  // 0.5 inches
            bottomMargin = 36  // 0.5 inches
            sideMargin = 36  // 0.5 inches
        }
        
        // Create page rect that matches the full page size
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let contentWidth = pageWidth - (sideMargin * 2)
        
        // Create renderer with full page bounds - it will handle clipping automatically
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            var currentPage = 0
            
            // Group courses by student
            let coursesByStudent = Dictionary(grouping: courses) { $0.student.id }
            
            // Check if we have any students with courses
            let studentsWithCourses = students.filter { student in
                guard let studentCourses = coursesByStudent[student.id] else { return false }
                return !studentCourses.isEmpty
            }
            
            guard !studentsWithCourses.isEmpty else {
                // If no students with courses, create a blank page with a message
                context.beginPage()
                let message = "No report card data available"
                let messageAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.label
                ]
                message.draw(at: CGPoint(x: sideMargin, y: pageHeight / 2), withAttributes: messageAttributes)
                return
            }
            
            for student in studentsWithCourses {
                guard let studentCourses = coursesByStudent[student.id], !studentCourses.isEmpty else {
                    continue
                }
                
                // Start new page for each student
                context.beginPage()
                currentPage += 1
                // Start at top margin for each new page
                var yPosition: CGFloat = topMargin
                
                // Debug: Ensure we have all courses
                // studentCourses should contain all courses for this student
                
                // Student Header
                let studentName = student.name ?? "Student"
                let titleFont = UIFont.boldSystemFont(ofSize: 24)
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor.black
                ]
                // Calculate actual text height using boundingRect
                let titleBoundingRect = NSString(string: studentName).boundingRect(
                    with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: titleAttributes,
                    context: nil
                )
                let titleHeight = ceil(titleBoundingRect.height)
                let titleRect = CGRect(x: sideMargin, y: yPosition, width: contentWidth, height: titleHeight + 4)
                let titleAttributedString = NSAttributedString(string: studentName, attributes: titleAttributes)
                titleAttributedString.draw(in: titleRect)
                yPosition += titleHeight + 10
                
                // Date
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let dateString = "Generated: \(dateFormatter.string(from: Date()))"
                let dateFont = UIFont.systemFont(ofSize: 12)
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.darkGray
                ]
                // Calculate actual text height using boundingRect
                let dateBoundingRect = NSString(string: dateString).boundingRect(
                    with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: dateAttributes,
                    context: nil
                )
                let dateHeight = ceil(dateBoundingRect.height)
                let dateRect = CGRect(x: sideMargin, y: yPosition, width: contentWidth, height: dateHeight + 4)
                let dateAttributedString = NSAttributedString(string: dateString, attributes: dateAttributes)
                dateAttributedString.draw(in: dateRect)
                yPosition += dateHeight + 15
                
                // Check if we need a new page before starting Courses section
                // Calculate how much space we need for title + at least 2 courses
                let coursesTitleFont = UIFont.boldSystemFont(ofSize: 18)
                let courseNameFont = UIFont.systemFont(ofSize: 14, weight: .medium)
                let minCoursesSpace = coursesTitleFont.lineHeight + 15.0 + (courseNameFont.lineHeight + 6.0) * 2.0
                
                if yPosition + minCoursesSpace > pageHeight - bottomMargin {
                    context.beginPage()
                    yPosition = topMargin
                }
                
                // Courses Section
                let coursesTitle = "Course Grades"
                let coursesTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: coursesTitleFont,
                    .foregroundColor: UIColor.black
                ]
                // Calculate actual text height using boundingRect
                let coursesTitleBoundingRect = NSString(string: coursesTitle).boundingRect(
                    with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: coursesTitleAttributes,
                    context: nil
                )
                let coursesTitleHeight = ceil(coursesTitleBoundingRect.height)
                let coursesTitleRect = CGRect(x: sideMargin, y: yPosition, width: contentWidth, height: coursesTitleHeight + 4)
                let coursesTitleAttributedString = NSAttributedString(string: coursesTitle, attributes: coursesTitleAttributes)
                coursesTitleAttributedString.draw(in: coursesTitleRect)
                // Move down by the title's actual height plus spacing
                yPosition += coursesTitleHeight + 15
                
                // Course rows
                let sortedCourses = studentCourses.sorted(by: { $0.name < $1.name })
                
                // Define font attributes (courseNameFont already declared above)
                let courseNameAttributes: [NSAttributedString.Key: Any] = [
                    .font: courseNameFont,
                    .foregroundColor: UIColor.black
                ]
                let rowHeight = courseNameFont.lineHeight + 6 // Use actual line height plus spacing
                let maxY = pageHeight - bottomMargin
                
                // Draw each course - ensure yPosition increments for each iteration
                for (index, course) in sortedCourses.enumerated() {
                    let courseName = course.name
                    let maxNameWidth = contentWidth - 100
                    
                    // Calculate actual text height using boundingRect FIRST, before page-break check
                    let nameBoundingRect = NSString(string: courseName).boundingRect(
                        with: CGSize(width: maxNameWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: courseNameAttributes,
                        context: nil
                    )
                    let nameHeight = ceil(nameBoundingRect.height)
                    
                    // Check if we need a new page before drawing this course
                    // Use actual calculated nameHeight instead of fixed rowHeight
                    if yPosition + nameHeight + 8.0 > maxY {
                        context.beginPage()
                        yPosition = topMargin
                        // Redraw the "Course Grades" header on new page using actual calculated height
                        let coursesTitleBoundingRect = NSString(string: coursesTitle).boundingRect(
                            with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: coursesTitleAttributes,
                            context: nil
                        )
                        let coursesTitleHeight = ceil(coursesTitleBoundingRect.height)
                        let coursesTitleRect = CGRect(x: sideMargin, y: yPosition, width: contentWidth, height: coursesTitleHeight + 4)
                        let coursesTitleAttributedString = NSAttributedString(string: coursesTitle, attributes: coursesTitleAttributes)
                        coursesTitleAttributedString.draw(in: coursesTitleRect)
                        yPosition += coursesTitleHeight + 15
                    }
                    
                    // Store current yPosition for this course to ensure proper spacing
                    let currentCourseY = yPosition
                    
                    // Draw course name using rect with actual calculated height
                    let courseNameRect = CGRect(
                        x: sideMargin,
                        y: currentCourseY,
                        width: maxNameWidth,
                        height: nameHeight + 4
                    )
                    courseName.draw(in: courseNameRect, withAttributes: courseNameAttributes)
                    
                    // Draw grade on the right side - calculate actual height
                    if let grade = course.grade {
                        let gradeString = String(format: "%.1f%%", grade)
                        let gradeFont = UIFont.boldSystemFont(ofSize: 14)
                        let gradeAttributes: [NSAttributedString.Key: Any] = [
                            .font: gradeFont,
                            .foregroundColor: UIColor.black
                        ]
                        let gradeBoundingRect = NSString(string: gradeString).boundingRect(
                            with: CGSize(width: 80, height: CGFloat.greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: gradeAttributes,
                            context: nil
                        )
                        let gradeHeight = ceil(gradeBoundingRect.height)
                        let gradeRect = CGRect(x: pageWidth - sideMargin - 80, y: currentCourseY, width: 80, height: gradeHeight + 4)
                        gradeString.draw(in: gradeRect, withAttributes: gradeAttributes)
                    } else {
                        let noGradeString = "No Grade"
                        let noGradeFont = UIFont.systemFont(ofSize: 12)
                        let noGradeAttributes: [NSAttributedString.Key: Any] = [
                            .font: noGradeFont,
                            .foregroundColor: UIColor.darkGray
                        ]
                        let noGradeBoundingRect = NSString(string: noGradeString).boundingRect(
                            with: CGSize(width: 80, height: CGFloat.greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: noGradeAttributes,
                            context: nil
                        )
                        let noGradeHeight = ceil(noGradeBoundingRect.height)
                        let noGradeRect = CGRect(x: pageWidth - sideMargin - 80, y: currentCourseY, width: 80, height: noGradeHeight + 4)
                        noGradeString.draw(in: noGradeRect, withAttributes: noGradeAttributes)
                    }
                    
                    // CRITICAL: Increment yPosition using REAL height
                    yPosition = currentCourseY + nameHeight + 8
                }
                
                // Add spacing after courses section
                yPosition += 20
                
                // Attendance Summary (moved to end)
                if let records = attendanceRecords[student.id], !records.isEmpty {
                    // Check if we need a new page for attendance section
                    let attendanceTitleFont = UIFont.boldSystemFont(ofSize: 16)
                    let attendanceTextFont = UIFont.systemFont(ofSize: 12)
                    let attendanceSectionHeight = attendanceTitleFont.lineHeight + 8 + attendanceTextFont.lineHeight + 10
                    
                    if yPosition + attendanceSectionHeight > pageHeight - bottomMargin {
                        context.beginPage()
                        yPosition = topMargin
                    }
                    
                    let summary = AttendanceSummary.from(records: records)
                    let attendancePercentage = summary.average
                    let attendancePercentageString = NumberFormatter.percentFormatter.string(from: NSNumber(value: attendancePercentage)) ?? "0%"
                    
                    let attendanceTitle = "Attendance"
                    let attendanceTitleAttributes: [NSAttributedString.Key: Any] = [
                        .font: attendanceTitleFont,
                        .foregroundColor: UIColor.black
                    ]
                    // Calculate actual text height for attendance title using boundingRect
                    let attendanceTitleBoundingRect = NSString(string: attendanceTitle).boundingRect(
                        with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attendanceTitleAttributes,
                        context: nil
                    )
                    let attendanceTitleHeight = ceil(attendanceTitleBoundingRect.height)
                    let attendanceTitleRect = CGRect(x: sideMargin, y: yPosition, width: contentWidth, height: attendanceTitleHeight + 4)
                    let attendanceTitleAttributedString = NSAttributedString(string: attendanceTitle, attributes: attendanceTitleAttributes)
                    attendanceTitleAttributedString.draw(in: attendanceTitleRect)
                    // Move down by actual height plus spacing
                    yPosition += attendanceTitleHeight + 8
                    
                    // attendanceTextFont already declared above for page break calculation
                    let attendanceText = "Present: \(summary.classesAttended) • Absent: \(summary.classesMissed) • Percentage: \(attendancePercentageString)"
                    let finalAttendanceText: String
                    if summary.streakDays > 0 {
                        finalAttendanceText = attendanceText + " • Current Streak: \(summary.streakDays) day\(summary.streakDays == 1 ? "" : "s")"
                    } else {
                        finalAttendanceText = attendanceText
                    }
                    // Calculate actual text height for attendance text using boundingRect
                    let attendanceTextBoundingRect = NSString(string: finalAttendanceText).boundingRect(
                        with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: dateAttributes,
                        context: nil
                    )
                    let attendanceTextHeight = ceil(attendanceTextBoundingRect.height)
                    let attendanceTextRect = CGRect(x: sideMargin, y: yPosition, width: contentWidth, height: attendanceTextHeight + 4)
                    let attendanceTextAttributedString = NSAttributedString(string: finalAttendanceText, attributes: dateAttributes)
                    attendanceTextAttributedString.draw(in: attendanceTextRect)
                    // Move down by actual height plus spacing
                    yPosition += attendanceTextHeight + 20
                }
                
                // Add spacing before next student
                yPosition += 20
            }
        }
        
        return data
    }
}

private struct AttendanceSummaryRow: View {
    let records: [AttendanceRecordDTO]
    
    private var summary: AttendanceSummary {
        AttendanceSummary.from(records: records)
    }
    
    private var attendancePercentage: Double {
        summary.average
    }
    
    private var attendancePercentageString: String {
        NumberFormatter.percentFormatter.string(from: NSNumber(value: attendancePercentage)) ?? "0%"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Attendance")
                    .font(.headline)
                    .foregroundColor(.hatchEdText)
                HStack(spacing: 12) {
                    Text("Present: \(summary.classesAttended)")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                    Text("•")
                        .foregroundColor(.hatchEdSecondaryText)
                    Text("Absent: \(summary.classesMissed)")
                        .font(.subheadline)
                        .foregroundColor(.hatchEdSecondaryText)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(attendancePercentageString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(attendanceColor)
                if summary.streakDays > 0 {
                    Text("\(summary.streakDays) day streak")
                        .font(.caption)
                        .foregroundColor(.hatchEdSecondaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(attendanceColor.opacity(0.15))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdSecondaryBackground)
        )
    }
    
    private var attendanceColor: Color {
        if attendancePercentage >= 0.95 {
            return .hatchEdSuccess
        } else if attendancePercentage >= 0.90 {
            return .hatchEdWarning
        } else {
            return .hatchEdCoralAccent
        }
    }
}

private struct AttendanceSummary {
    let classesAttended: Int
    let classesMissed: Int
    let streakDays: Int
    
    var totalClasses: Int { classesAttended + classesMissed }
    
    var average: Double {
        guard totalClasses > 0 else { return 0 }
        return Double(classesAttended) / Double(totalClasses)
    }
    
    static func from(records: [AttendanceRecordDTO]) -> AttendanceSummary {
        guard !records.isEmpty else {
            return AttendanceSummary(classesAttended: 0, classesMissed: 0, streakDays: 0)
        }
        
        let attended = records.filter { $0.isPresent }.count
        let missed = records.filter { !$0.isPresent }.count
        
        let sortedRecords = records.sorted { $0.date > $1.date }
        var streak = 0
        for record in sortedRecords {
            if record.isPresent {
                streak += 1
            } else {
                break
            }
        }
        
        return AttendanceSummary(classesAttended: attended, classesMissed: missed, streakDays: streak)
    }
}

private extension NumberFormatter {
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private struct CourseGradeRow: View {
    let course: Course
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.hatchEdText)
            }
            
            Spacer()
            
            if let grade = course.grade {
                Text(String(format: "%.1f%%", grade))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(gradeColor(for: grade))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gradeColor(for: grade).opacity(0.15))
                    )
            } else {
                Text("No Grade")
                    .font(.subheadline)
                    .foregroundColor(.hatchEdSecondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.hatchEdSecondaryBackground)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hatchEdSecondaryBackground)
        )
    }
    
    private func gradeColor(for grade: Double) -> Color {
        if grade >= 90 {
            return .hatchEdSuccess
        } else if grade >= 70 {
            return .hatchEdWarning
        } else {
            return .hatchEdCoralAccent
        }
    }
}

