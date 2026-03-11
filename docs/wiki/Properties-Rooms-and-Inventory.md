# Properties, Rooms, and Inventory

## Why this feature exists

Properties, rooms, and inventory are the template layer for the rest of the product. If this data is wrong or incomplete, inspections and reports become unreliable. New engineers should view this feature area as the foundation of the app rather than a simple CRUD surface.

## Main files

- [`Snapshots/Views/Tabs/PropertyView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Tabs/PropertyView.swift)
- [`Snapshots/ViewModels/PropertyViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/PropertyViewModel.swift)
- [`Snapshots/Views/Property/PropertyDetailView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Property/PropertyDetailView.swift)
- [`Snapshots/ViewModels/PropertyDetailViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/PropertyDetailViewModel.swift)
- [`Snapshots/Views/Room/RoomInventoryView.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Room/RoomInventoryView.swift)
- [`Snapshots/ViewModels/RoomInventoryViewModel.swift`](/Users/uabylbekov/Projects/snapshots/Snapshots/ViewModels/RoomInventoryViewModel.swift)
- Add and edit sheets under [`Snapshots/Views/Property/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Property), [`Snapshots/Views/Room/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Room), and [`Snapshots/Views/Item/`](/Users/uabylbekov/Projects/snapshots/Snapshots/Views/Item)

## User workflow

1. A user creates a property.
2. Inside the property, the user creates rooms.
3. Inside each room, the user adds expected inventory items.
4. Future inspections use those items as the checklist for that property.

This is why deleting or changing structure here can have downstream effects on inspection usability and reporting completeness.

## Property visibility model

Properties are not only owned records. A user can see a property because:

- they own it
- they are a member on it
- an access-contract RPC returns it as visible

`PropertyViewModel` first tries `get_accessible_properties_with_owner_tier`. If that function is missing or stale in schema cache, it falls back to a join against `property_members`.

This fallback behavior matters during migrations and partial backend rollouts.

## Property gating

Adding properties is limited by `SnapshotsAccessManager.canAddProperty(ownedCount:)`.

- Free: 1 owned property
- Pro: up to 10 owned properties
- Enterprise: unlimited

Only owned properties count toward the limit. Managed properties do not. This is intentional and should not be treated as a bug by QA.

## Property deletion safeguards

Before property deletion, the app checks for active inspections.

- If active inspections exist, the user sees a warning.
- The user must also type `DELETE` to confirm destructive removal.

This is a valuable onboarding detail for testers because deletion is intentionally friction-heavy and should remain that way.

## Room management behavior

Rooms live inside a property and can only be managed by users with the right role on that property. `PropertyDetailView` hides or disables room-management controls for users who are not owners or managers.

Deleting a room also has an active-inspection safeguard because room deletion can affect inspections already in progress.

## Inventory management behavior

Inventory items are expected checkable objects inside a room.

Each item has:

- name
- optional description
- expected quantity

When an inspection runs, the inspector records the observed status of each item against this inventory list.

## Why inventory is central to QA

If inventory creation or editing regresses, these areas often fail next:

- inspection completion percentages
- issue counts
- report grouping by room
- comparison workflows

That makes inventory a good early smoke test for most releases.

## Tester checklist

- Create a property and verify it appears in the property list.
- Edit a property and verify updates persist.
- Delete a property with no active inspections.
- Attempt to delete a property with active inspections and confirm the warning appears.
- Add multiple rooms and verify ordering and display are stable.
- Edit and delete rooms.
- Add inventory items with quantity greater than one.
- Edit and delete inventory items.
- Verify a room with no inventory shows an empty state instead of a broken inspection flow.

## Edge cases to watch

- Access-contract RPC missing in one environment but present in another.
- A managed property appears correctly but does not count toward property creation limits.
- Room deletion while inspections are in progress.
- Inventory item updates after historical inspections already exist.
