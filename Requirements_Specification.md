# HatchEd Requirements Specification

**Version:** 1.0  
**Date:** November 7, 2025  
**Project:** HatchEd - Educational Management Platform

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional and non-functional requirements for HatchEd, an educational management platform designed to facilitate communication and organization between parents and students in a homeschooling environment.

### 1.2 Scope
HatchEd is a full-stack application consisting of:
- **iOS Client Application** (SwiftUI)
- **Backend API Server** (Node.js/Express)
- **Database** (MongoDB)

The platform supports two primary user roles: Parents and Students, with role-based access control and family-based organization.

### 1.3 Definitions and Acronyms
- **API**: Application Programming Interface
- **APNs**: Apple Push Notification service
- **JWT**: JSON Web Token
- **MVC**: Model-View-Controller
- **REST**: Representational State Transfer

---

## 2. System Overview

### 2.1 Architecture
HatchEd follows a client-server architecture:
- **Client**: Native iOS application built with SwiftUI
- **Server**: RESTful API built with Node.js and Express
- **Database**: MongoDB for persistent data storage
- **Authentication**: Apple Sign In with JWT-based session management

### 2.2 User Roles
1. **Parent**: Full access to curriculum management, assignment creation, grading, and student oversight
2. **Student**: Access to assignments, planner, report cards, and ability to request help

---

## 3. Functional Requirements

### 3.1 Authentication and User Management

#### 3.1.1 Apple Sign In
- **REQ-AUTH-001**: The system shall support authentication via Apple Sign In
- **REQ-AUTH-002**: Upon first sign in, users must select a role (Parent or Student)
- **REQ-AUTH-003**: Students must join a family before accessing the application
- **REQ-AUTH-004**: The system shall maintain user sessions using JWT tokens
- **REQ-AUTH-005**: The system shall support offline authentication state caching

#### 3.1.2 User Profile
- **REQ-USER-001**: Users shall have profiles containing: name, email, role, and family association
- **REQ-USER-002**: The system shall support multiple students per family
- **REQ-USER-003**: Parents can view a list of all students in their family

### 3.2 Family Management

#### 3.2.1 Family Organization
- **REQ-FAM-001**: The system shall support family-based organization of users
- **REQ-FAM-002**: Parents can create families
- **REQ-FAM-003**: Students can join existing families using a family code or invitation
- **REQ-FAM-004**: All family members share access to family-specific data (assignments, courses, notifications)

### 3.3 Curriculum Management

#### 3.3.1 Subjects
- **REQ-CURR-001**: Parents can create, view, update, and delete subjects
- **REQ-CURR-002**: Subjects have a name and optional description
- **REQ-CURR-003**: Subjects serve as organizational categories for courses

#### 3.3.2 Courses
- **REQ-CURR-004**: Parents can create, view, update, and delete courses
- **REQ-CURR-005**: Courses must be associated with a subject
- **REQ-CURR-006**: Courses can have a name, description, and optional grade
- **REQ-CURR-007**: Course grades are automatically calculated from assignment grades
- **REQ-CURR-008**: Course grades are calculated as the average percentage of all graded assignments

#### 3.3.3 Assignments
- **REQ-CURR-009**: Parents can create, view, update, and delete assignments
- **REQ-CURR-010**: Assignments must be associated with a student
- **REQ-CURR-011**: Assignments can be associated with a course
- **REQ-CURR-012**: Assignments have: title, student ID, due date (optional), instructions (optional), points possible, points awarded
- **REQ-CURR-013**: Assignments can include multiple questions
- **REQ-CURR-014**: Assignments with due dates appear in the planner view
- **REQ-CURR-015**: The system shall prevent deletion of assignments through the planner interface (assignments can only be deleted from curriculum management)

### 3.4 Planner and Task Management

#### 3.4.1 Weekly Planner View
- **REQ-PLAN-001**: The system shall display a weekly calendar grid view
- **REQ-PLAN-002**: The planner shall show tasks and assignments for each day
- **REQ-PLAN-003**: Assignments with due dates automatically appear in the planner
- **REQ-PLAN-004**: Users can navigate between weeks by swiping left/right
- **REQ-PLAN-005**: Tasks and assignments in the planner are clickable to view details
- **REQ-PLAN-006**: Tasks are color-coded for visual distinction

#### 3.4.2 Task Management
- **REQ-PLAN-007**: Parents can create custom planner tasks
- **REQ-PLAN-008**: Tasks have: title, date, time (optional), color, and notes
- **REQ-PLAN-009**: Tasks can be viewed in a day detail sheet
- **REQ-PLAN-010**: Custom tasks can be deleted from the planner
- **REQ-PLAN-011**: Assignment-based tasks cannot be deleted from the planner

#### 3.4.3 Task Details
- **REQ-PLAN-012**: Clicking a task or assignment opens a detail sheet
- **REQ-PLAN-013**: Task detail sheet displays: title, date, time, color, notes
- **REQ-PLAN-014**: Assignment detail sheet displays: title, due date, instructions, points (if graded), course information
- **REQ-PLAN-015**: Detail sheets support multiple presentation sizes (fraction and large)

### 3.5 Assignment Grading

#### 3.5.1 Grading Interface
- **REQ-GRADE-001**: Parents can grade assignments from the parent dashboard
- **REQ-GRADE-002**: Grading interface displays assignment details
- **REQ-GRADE-003**: Parents enter points possible and points awarded
- **REQ-GRADE-004**: The system calculates and displays percentage grade automatically
- **REQ-GRADE-005**: The system validates that points awarded does not exceed points possible
- **REQ-GRADE-006**: Upon saving a grade, the system updates the assignment and recalculates the course grade

#### 3.5.2 Grade Calculation
- **REQ-GRADE-007**: Assignment percentage = (points awarded / points possible) × 100
- **REQ-GRADE-008**: Course grade = average of all assignment percentages for that course
- **REQ-GRADE-009**: Course grade updates automatically when assignments are graded
- **REQ-GRADE-010**: Course grade calculation runs asynchronously and does not block the UI

### 3.6 Student Dashboard

#### 3.6.1 Daily Assignments
- **REQ-STU-001**: Students can view assignments due today
- **REQ-STU-002**: Students can mark assignments as completed
- **REQ-STU-003**: Completion status is stored locally using UserDefaults
- **REQ-STU-004**: Completed assignments are visually distinguished (strikethrough, reduced opacity)
- **REQ-STU-005**: Students can request help on specific assignments

#### 3.6.2 Help Requests
- **REQ-STU-006**: Students can click "Ask for Help" on any assignment
- **REQ-STU-007**: Help requests create notifications for all parents in the family
- **REQ-STU-008**: Help requests trigger local push notifications
- **REQ-STU-009**: Help request notifications include the assignment title and student name

#### 3.6.3 Inspirational Content
- **REQ-STU-010**: Student dashboard includes a placeholder section for daily inspirational quotes
- **REQ-STU-011**: Quote section is prepared for future content integration

### 3.7 Parent Dashboard

#### 3.7.1 Assignment Management
- **REQ-PAR-001**: Parents can view assignments pending grading
- **REQ-PAR-002**: Assignments are displayed with student name, title, due date, and points format
- **REQ-PAR-003**: Parents can click on assignments to open the grading interface
- **REQ-PAR-004**: Assignments show "X/Y points" format and percentage if graded

#### 3.7.2 Notifications
- **REQ-PAR-005**: Parents receive notifications for help requests from students
- **REQ-PAR-006**: Parents receive notifications for overdue assignments
- **REQ-PAR-007**: Notifications appear in the parent dashboard
- **REQ-PAR-008**: Notifications trigger push notifications to the device

### 3.8 Report Cards

#### 3.8.1 Grade Display
- **REQ-REP-001**: The system shall display report cards for students
- **REQ-REP-002**: Report cards show courses with their calculated grades
- **REQ-REP-003**: Course grades are displayed as "Course Name...Grade%"
- **REQ-REP-004**: Course grades are calculated from assignments if not provided by the server
- **REQ-REP-005**: Report cards show "No graded assignments yet" for courses without grades

### 3.9 Notifications System

#### 3.9.1 Notification Types
- **REQ-NOT-001**: The system supports help request notifications
- **REQ-NOT-002**: The system supports overdue assignment notifications
- **REQ-NOT-003**: Notifications can be sent to specific users or all parents in a family
- **REQ-NOT-004**: Notifications include title, body, and timestamp

#### 3.9.2 Overdue Assignment Detection
- **REQ-NOT-005**: The system checks for overdue assignments hourly
- **REQ-NOT-006**: An assignment is overdue if: due date has passed AND points awarded is null
- **REQ-NOT-007**: Overdue notifications are created for both students and parents
- **REQ-NOT-008**: The system prevents duplicate notifications within 24 hours
- **REQ-NOT-009**: Overdue check runs as a background service on the server

#### 3.9.3 Push Notifications
- **REQ-NOT-010**: The app requests notification permissions on launch
- **REQ-NOT-011**: The app registers for remote notifications (APNs)
- **REQ-NOT-012**: Local push notifications are sent for help requests
- **REQ-NOT-013**: Notifications display when the app is in the foreground
- **REQ-NOT-014**: Device tokens are captured (ready for server-side push integration)

#### 3.9.4 Notification Management
- **REQ-NOT-015**: Users can view all notifications in a notifications view
- **REQ-NOT-016**: Users can delete notifications (soft delete)
- **REQ-NOT-017**: Notifications are filtered by user and family

### 3.10 Navigation and Menu

#### 3.10.1 Role-Based Navigation
- **REQ-NAV-001**: Navigation menu items vary by user role
- **REQ-NAV-002**: Parent menu includes: Dashboard, Planner, Curriculum, Report Cards, Portfolio, Resources, Settings
- **REQ-NAV-003**: Student menu includes: Dashboard, Planner, Report Cards, Portfolio, Resources, Settings
- **REQ-NAV-004**: Menu items are dynamically generated based on user role

#### 3.10.2 View Navigation
- **REQ-NAV-005**: Users can navigate between views using the menu
- **REQ-NAV-006**: Navigation maintains state and context
- **REQ-NAV-007**: Views support pull-to-refresh functionality

### 3.11 Additional Views

#### 3.11.1 Portfolio
- **REQ-VIEW-001**: Portfolio view exists as a placeholder for future student work display

#### 3.11.2 Resources
- **REQ-VIEW-002**: Resources view exists as a placeholder for educational resources

#### 3.11.3 Settings
- **REQ-VIEW-003**: Settings view exists for application configuration

---

## 4. Non-Functional Requirements

### 4.1 Performance
- **REQ-PERF-001**: API responses should complete within 2 seconds under normal load
- **REQ-PERF-002**: UI interactions should feel responsive (< 100ms feedback)
- **REQ-PERF-003**: Course grade calculations run asynchronously to prevent UI blocking

### 4.2 Reliability
- **REQ-REL-001**: The system shall handle network errors gracefully
- **REQ-REL-002**: The system supports offline authentication state caching
- **REQ-REL-002**: API errors are logged and handled with appropriate user feedback

### 4.3 Security
- **REQ-SEC-001**: All API endpoints require authentication (except health check)
- **REQ-SEC-002**: JWT tokens are used for session management
- **REQ-SEC-003**: User data is scoped to families (users can only access their family's data)
- **REQ-SEC-004**: Apple Sign In credentials are handled securely

### 4.4 Usability
- **REQ-USE-001**: The interface follows iOS Human Interface Guidelines
- **REQ-USE-002**: Color-coded tasks provide visual distinction
- **REQ-USE-003**: Forms include validation with clear error messages
- **REQ-USE-004**: Pull-to-refresh is available on list views

### 4.5 Maintainability
- **REQ-MAIN-001**: Code follows Swift and JavaScript best practices
- **REQ-MAIN-002**: Models are separated from views
- **REQ-MAIN-003**: API client is centralized for easy maintenance
- **REQ-MAIN-004**: Server uses middleware for common concerns (auth, error handling)

---

## 5. Data Models

### 5.1 User
- `id`: String (unique identifier)
- `appleId`: String? (Apple Sign In identifier)
- `name`: String? (user's display name)
- `email`: String? (user's email address)
- `role`: String? ("parent" or "student")
- `familyId`: String? (family association)
- `createdAt`: Date?
- `updatedAt`: Date?

### 5.2 Family
- `id`: String (unique identifier)
- `name`: String? (family name)
- `createdAt`: Date?
- `updatedAt`: Date?

### 5.3 Subject
- `id`: String (unique identifier)
- `name`: String (subject name)
- `description`: String? (optional description)
- `createdAt`: Date?
- `updatedAt`: Date?

### 5.4 Course
- `id`: String (unique identifier)
- `name`: String (course name)
- `description`: String? (optional description)
- `subjectId`: String (associated subject)
- `grade`: Double? (calculated or manually set grade percentage)
- `createdAt`: Date?
- `updatedAt`: Date?

### 5.5 Assignment
- `id`: String (unique identifier)
- `title`: String (assignment title)
- `studentId`: String (required - assigned student)
- `courseId`: String? (optional - associated course)
- `dueDate`: Date? (optional due date)
- `instructions`: String? (optional instructions)
- `pointsPossible`: Double? (total points possible)
- `pointsAwarded`: Double? (points awarded)
- `subject`: Subject? (optional subject reference)
- `questions`: [Question] (array of questions)
- `createdAt`: Date?
- `updatedAt`: Date?

### 5.6 PlannerTask
- `id`: String (unique identifier)
- `title`: String (task title)
- `date`: Date (task date)
- `time`: Date? (optional time)
- `color`: Color (task color)
- `notes`: String? (optional notes)

### 5.7 Notification
- `id`: String (unique identifier)
- `title`: String (notification title)
- `body`: String (notification body)
- `userId`: String (target user)
- `familyId`: String? (target family)
- `readAt`: Date? (read timestamp)
- `deletedAt`: Date? (soft delete timestamp)
- `createdAt`: Date?

---

## 6. API Endpoints

### 6.1 Authentication
- `POST /api/auth/apple` - Authenticate with Apple Sign In

### 6.2 Users
- `GET /api/users/me` - Get current user
- `PATCH /api/users/me` - Update current user
- `GET /api/users/family` - Get users in current user's family

### 6.3 Families
- `POST /api/families` - Create a family
- `GET /api/families/:id` - Get family details
- `POST /api/families/:id/join` - Join a family

### 6.4 Curriculum
- **Subjects:**
  - `POST /api/curriculum/subjects` - Create subject
  - `GET /api/curriculum/subjects` - List subjects
  - `PATCH /api/curriculum/subjects/:id` - Update subject
  - `DELETE /api/curriculum/subjects/:id` - Delete subject

- **Courses:**
  - `POST /api/curriculum/courses` - Create course
  - `GET /api/curriculum/courses` - List courses
  - `PATCH /api/curriculum/courses/:id` - Update course
  - `DELETE /api/curriculum/courses/:id` - Delete course

- **Assignments:**
  - `POST /api/curriculum/assignments` - Create assignment
  - `GET /api/curriculum/assignments` - List assignments
  - `PATCH /api/curriculum/assignments/:id` - Update assignment
  - `DELETE /api/curriculum/assignments/:id` - Delete assignment

### 6.5 Notifications
- `GET /api/notifications` - List notifications for current user
- `POST /api/notifications` - Create notification(s)
- `DELETE /api/notifications/:notificationId` - Delete notification

### 6.6 Health Check
- `GET /health` - Server health check

---

## 7. Technical Stack

### 7.1 Client (iOS)
- **Language**: Swift
- **Framework**: SwiftUI
- **iOS Version**: iOS 14.0+
- **Key Libraries**:
  - AuthenticationServices (Apple Sign In)
  - UserNotifications (Push Notifications)
  - Foundation (Networking, Date handling)

### 7.2 Server
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MongoDB with Mongoose
- **Authentication**: JWT (jsonwebtoken)
- **Security**: Helmet, CORS
- **Key Dependencies**:
  - express
  - mongoose
  - jsonwebtoken
  - cookie-parser
  - dotenv

### 7.3 Database
- **Type**: MongoDB
- **Collections**: users, families, subjects, courses, assignments, notifications, attendance

---

## 8. Future Enhancements (Out of Scope)

The following features are identified for future development but are not included in the current requirements:

1. **Portfolio Management**: Full implementation of student work portfolio
2. **Resources Library**: Educational resources and materials
3. **Attendance Tracking**: Full attendance management system
4. **Remote Push Notifications**: Complete APNs integration with server-side push
5. **Offline Mode**: Full offline data synchronization
6. **Multi-device Sync**: Real-time synchronization across devices
7. **Question Types**: Support for various question types in assignments
8. **File Attachments**: Support for file uploads in assignments
9. **Calendar Integration**: Integration with system calendar
10. **Export Functionality**: Export reports and data

---

## 9. Assumptions and Constraints

### 9.1 Assumptions
- Users have iOS devices (iPhone/iPad)
- Users have Apple IDs for authentication
- Internet connectivity is available for most operations
- Families are small groups (typically 1-10 members)

### 9.2 Constraints
- iOS-only application (no Android support)
- Requires iOS 14.0 or later
- Requires Apple Sign In (no alternative authentication methods)
- Server must be deployed separately (not included in app bundle)

---

## 10. Glossary

- **Assignment**: A task or piece of work assigned to a student
- **Course**: A subject-specific educational unit containing multiple assignments
- **Family**: A group of users (parents and students) sharing educational data
- **Planner Task**: A custom task created in the planner (distinct from assignments)
- **Subject**: A category or discipline (e.g., Mathematics, Science)
- **Overdue Assignment**: An assignment past its due date that has not been graded

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | November 7, 2025 | System Documentation | Initial requirements specification |

---

**End of Document**


