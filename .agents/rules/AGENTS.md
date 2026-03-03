# Coding Agent Specification

## 1. Identity

- **id:** `coding-agent.property-inspection`
- **name:** Property Inspection Coding Agent
- **version:** 1.0.0
- **owner:** you@example.com
- **environment:** development

## 2. Project Overview

This repo contains an iOS + Supabase app for short-term rental (Airbnb/VRBO) hosts to manage property inspections around guest check-in/check-out.

High-level goals:

- Help hosts and cleaners document the property condition with photos, notes, and signatures.
- Generate clean reports that can be attached to damage/extra-cleaning claims.
- Keep a history of inspections per listing (before/after, turnovers).

Key technologies:

- iOS app in Swift/SwiftUI.
- Supabase (Postgres, Auth, Storage, optional Edge Functions).

## 3. Current User-Facing Features

1. Authentication
   - Email + password sign-up/sign-in for hosts.
   - Optional magic link login.

2. Listings & units
   - Hosts can create and edit properties/listings (name, address, notes).
   - Each listing can have multiple units or rooms if needed.

3. Inspection templates
   - Built-in templates:
     - Checkout damage sweep.
     - Post-cleaning pre-arrival check.
   - Each template consists of sections (e.g., Kitchen, Bathroom, Bedroom) and checklist items.

4. Inspections
   - Start an inspection for a specific listing/unit and template.
   - For each checklist item:
     - Mark condition (OK / issue / urgent).
     - Add free-text notes.
     - Attach one or more photos.
   - Save inspections as drafts and complete later.

5. Signatures
   - Capture a drawn signature (host or cleaner) on a canvas.
   - Store the signature image in Supabase Storage and link to the inspection.

6. Reports
   - Summary view with listing info, timestamps, and counts of issues/urgent items.
   - Per-section details with thumbnails.
   - Export/share the report as a PDF or public link.

7. History
   - For each listing/unit, show past inspections with status (draft/completed) and date.

## 4. Planned / Future Features

- Multi-user support (host + multiple cleaners with roles).
- Calendar or Airbnb/VRBO integration to pre-fill inspections from upcoming stays.
- Guest-facing self-inspection link.
- Web dashboard for viewing and exporting reports.

## 5. Responsibilities

The agent can:

- Implement inspection-related features and UI changes.
- Fix bugs in Swift, SQL, or backend functions.
- Refactor for clarity and testability without changing behavior.
- Add or update tests and related documentation.

The agent must not:

- Change the product focus (short-term rental inspections) or pricing flows.
- Introduce new auth/database/storage providers without explicit instruction.
- Remove or significantly alter auth, inspection, signature, or report flows unless requested.

## 6. Codebase Overview

- `ios-app/`
  - `PropertyInspectionApp.swift` – app entry point.
  - `Features/Auth/` – login, sign-up, session handling.
  - `Features/Listings/` – property and unit list/detail screens.
  - `Features/Inspections/` – templates, inspection wizard, photo capture.
  - `Features/Signatures/` – signature canvas and upload logic.
  - `Features/Reports/` – summary views and PDF export.
  - `Shared/` – design system, Supabase client, utilities.

- `backend/`
  - `supabase/migrations/` – SQL migrations defining schema.
  - `functions/` – edge functions for report links or custom logic.

## 7. Tools & Commands

- Build iOS app: open `ios-app/` in Xcode and use the main scheme.
- Run iOS tests: select `PropertyInspectionTests` scheme in Xcode or see `README` for CLI.
- Supabase:
  - Local dev: `supabase start`.
  - Apply migrations: `supabase db push`.

## 8. Data Model (Simplified)

- `profiles`
- `properties`
- `units`
- `templates`
- `template_items`
- `inspections`
- `inspection_items`
- `media`
- `signatures`

Any schema change must include a migration and matching model updates.

## 9. Coding Guidelines

- Follow Swift style guide in `CODESTYLE.md` (see separate file).
- Keep network/DB logic out of SwiftUI views; use view models/services.
- Prefer small, composable views and types.
- Name Swift files and types consistently with existing patterns.

## 10. Testing

- For new features, add tests where practical (view-model logic, helpers, backend functions).
- For bug fixes, add at least one regression test reproducing the issue.

## 11. Security & Privacy

- Do not log access tokens, emails, or other sensitive data.
- Keep Supabase keys in config/secrets; do not hard-code secrets.
- Be careful when changing RLS policies; prefer least privilege.

## 12. When to Ask for Help

Ask for human guidance when:

- Requirements are unclear or conflicting.
- A change impacts auth, payments, or data deletion.
- A change requires new 3rd-party integrations or major architectural changes.
