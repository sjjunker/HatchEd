//
//  MockSignInManager.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/10/25.
//
class MockSignInManager: AppleSignInManager {
    override init() {
        super.init()
        let student1 = Student(name: "Emma")
        let student2 = Student(name: "Liam")
        let mockParent = Parent(name: "Mock Parent", email: "parent@example.com", appleID: "mockID")
        mockParent.students = [student1, student2]
        self.currentParent = mockParent
    }
}

