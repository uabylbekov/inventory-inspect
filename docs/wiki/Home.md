# Snapshots Wiki

This wiki is the primary onboarding guide for developers, QA, and product collaborators working on Snapshots. It explains the app by feature area, shows where the code lives, and documents the behaviors testers should verify before release.

## Read this first

- [`Architecture-and-Data-Flow`](Architecture-and-Data-Flow)
- [`QA-Test-Playbook`](QA-Test-Playbook)

## Feature guides

- [`Authentication-and-Profile-Setup`](Authentication-and-Profile-Setup)
- [`Properties-Rooms-and-Inventory`](Properties-Rooms-and-Inventory)
- [`Inspections-and-Reports`](Inspections-and-Reports)
- [`Team-Collaboration-and-Notifications`](Team-Collaboration-and-Notifications)
- [`Subscriptions-Entitlements-and-Branding`](Subscriptions-Entitlements-and-Branding)
- [`Feedback-Alerts-and-Operations`](Feedback-Alerts-and-Operations)

## Product summary

Snapshots helps property operators standardize inspections across properties, rooms, and inventory items. Users define a property, configure its rooms, add expected inventory for each room, and then run inspections that compare reality against that inventory. The output is a structured inspection report with issue tracking and exportable PDFs.

The app supports:

- solo operators on the free tier
- growing teams on Pro
- white-labeled business workflows on Business
- cross-user access inheritance based on property ownership

## How to use this wiki

- Developers should start with architecture, then the feature page they are modifying.
- Testers should start with the QA playbook, then the relevant feature page.
- New product contributors should use the feature pages to understand business rules, edge cases, and premium gating.

## Source of truth

This wiki is based on the code in the main app target, the Supabase migrations and Edge Functions, and the payment docs already stored in the repo. If code and wiki ever disagree, the code wins and the wiki should be updated in the same change.
