# Swift Code Style Guide

This file defines how Swift and project code should look so the coding agent can keep the style consistent.

## 1. Language & Frameworks

- Swift 5+.
- SwiftUI for UI.
- Combine or async/await for async work (match existing code).

## 2. Project Structure

- Group code by feature where possible (Auth, Listings, Inspections, etc.).
- Keep view, view model, and service types in separate files when they grow beyond ~200 lines.

## 3. Naming

- Types: `PascalCase` (e.g., `InspectionDetailView`).
- Methods and variables: `camelCase`.
- Use descriptive names: prefer `inspectionItems` over `items`.
- Prefix view models with `ViewModel` where it improves clarity (e.g., `InspectionDetailViewModel`).

## 4. SwiftUI Guidelines

- Keep views small and focused.
- Derive state from models/view models rather than duplicating data.
- Use `@State`, `@Binding`, `@ObservedObject`, and `@StateObject` appropriately.
- Extract reusable components into `Shared/`.

## 5. Async & Networking

- Prefer async/await APIs when available.
- Centralize Supabase access in a small number of services/clients.
- Do not call Supabase directly from views; use view models or services.

## 6. Error Handling

- Use `Error` conforming enums for domain errors where appropriate.
- Convert low-level errors (network, decoding) to user-friendly messages at the view model level.

## 7. Formatting

- 2 or 4 spaces for indentation (choose one consistent with current repo; if none, use 4 spaces).
- Max line length target: ~120 characters where practical.
- Place opening braces on the same line as declarations.

Example:

```swift
struct InspectionSummaryView: View {
    @ObservedObject var viewModel: InspectionSummaryViewModel

    var body: some View {
        List(viewModel.items) { item in
            Text(item.title)
        }
        .navigationTitle("Inspection Summary")
    }
}
```

## 8. Comments & Documentation

- Use comments to explain "why", not "what".
- For public APIs or complex types, use Swift documentation comments (`///`).

## 9. Testing Style

- Name test methods to describe behavior (`testSomethingHappens_WhenCondition`).
- Keep Arrange-Act-Assert structure clear in tests.

## 10. Git & Commits

- Keep commits small and focused.
- Use present-tense, descriptive messages (e.g., `Add signature upload to inspection flow`).
