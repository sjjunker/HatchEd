# HatchEd MVVM Architecture

This app follows **Model–View–ViewModel (MVVM)**:

- **Models** (`Models/`) – Data only (e.g. `User`, `Portfolio`, `Course`). No UI or API calls.
- **Views** (`Views/`) – SwiftUI UI only. Bind to ViewModel state and call ViewModel methods for user actions. No direct `APIClient` use.
- **ViewModels** (`ViewModels/`) – `ObservableObject` types that hold screen state (`@Published`), call `APIClient`/services, and expose methods for the View.

## ViewModels

| ViewModel | Purpose | Used by |
|-----------|---------|---------|
| `AuthViewModel` | Sign-in state, user, family, students, notifications, auth API | `ContentView`, `SignInView`, `MenuView`, `Settings`, etc. |
| `ParentDashboardViewModel` | Assignments, courses, attendance, submit attendance | `ParentDashboard` |
| `PortfolioListViewModel` | Portfolio list, load/refresh | `PortfolioView` |
| `AddPortfolioViewModel` | Add-portfolio form state, work files, create portfolio | `AddPortfolioView` |
| `PlannerTaskStore` | Planner tasks, add/remove, refresh | `Planner` |
| `StudentDetailViewModel` | Student detail, attendance, courses, assignments | `StudentDetail` |
| `MenuManager` | Menu items by role | `MenuView` |

## Data flow

1. **App root** (`HatchEdApp`) creates `AuthViewModel` and `MenuManager`, injects them via `.environmentObject()`.
2. **ContentView** reads `authViewModel.signInState` / `authViewModel.userRole` and shows the correct root screen (SignIn, RoleSelection, or dashboard).
3. **Dashboards** (e.g. `ParentDashboard`) create a screen-specific ViewModel (e.g. `ParentDashboardViewModel`), pass `authViewModel` where needed (e.g. for students or submit attendance), and bind the view to the ViewModel.
4. **Views** use `@StateObject` or `@ObservedObject` for the ViewModel and `@EnvironmentObject` for shared auth/session.

## Adding a new screen

1. Add a **ViewModel** in `ViewModels/`: `@MainActor class FooViewModel: ObservableObject` with `@Published` state and methods that call `APIClient` or other services.
2. Add a **View** in `Views/`: use `@StateObject private var viewModel = FooViewModel()` and bind UI to `viewModel`; on user action call `viewModel.someMethod()`.
3. Keep **Models** in `Models/`; use them from both ViewModels and Views.
