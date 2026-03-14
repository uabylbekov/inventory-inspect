import Foundation
import Testing
@testable import Snapshots

@MainActor
@Suite("Property View Model Validation")
struct PropertyViewModelValidationTests {
    @Test("AddPropertyViewModel validates required and bounded fields")
    func addPropertyValidation() {
        let viewModel = AddPropertyViewModel()
        viewModel.name = "   "
        viewModel.maxGuests = "-2"
        viewModel.postalCode = String(repeating: "1", count: 21)

        #expect(viewModel.nameError == "Property name is required.")
        #expect(viewModel.maxGuestsError == "Max guests must be a positive whole number.")
        #expect(viewModel.postalCodeError == "Postal code is too long.")
        #expect(!viewModel.isFormValid)
        #expect(viewModel.isSaveDisabled)
    }

    @Test("AddPropertyViewModel accepts trimmed valid data")
    func addPropertyAcceptsValidData() {
        let viewModel = AddPropertyViewModel()
        viewModel.name = " Harbor House "
        viewModel.maxGuests = "8"
        viewModel.postalCode = "60601"

        #expect(viewModel.nameError == nil)
        #expect(viewModel.maxGuestsError == nil)
        #expect(viewModel.postalCodeError == nil)
        #expect(viewModel.isFormValid)
        #expect(!viewModel.isSaveDisabled)
    }

    @Test("EditPropertyViewModel disables save while loading or saving")
    func editPropertySaveDisableRules() {
        let viewModel = EditPropertyViewModel(propertyId: UUID())
        viewModel.name = "Property"

        #expect(!viewModel.isSaveDisabled)

        viewModel.isLoading = true
        #expect(viewModel.isSaveDisabled)

        viewModel.isLoading = false
        viewModel.isSaving = true
        #expect(viewModel.isSaveDisabled)
    }

    @Test("EditPropertyViewModel shares validation behavior with add property flow")
    func editPropertyValidation() {
        let viewModel = EditPropertyViewModel(propertyId: UUID())
        viewModel.name = String(repeating: "A", count: 101)
        viewModel.maxGuests = "0"
        viewModel.postalCode = String(repeating: "9", count: 21)

        #expect(viewModel.nameError == "Name must be 100 characters or fewer.")
        #expect(viewModel.maxGuestsError == "Max guests must be a positive whole number.")
        #expect(viewModel.postalCodeError == "Postal code is too long.")
        #expect(!viewModel.isFormValid)
    }

    @Test("Add room and item forms disable save when names are blank")
    func addRoomAndItemValidation() {
        let roomViewModel = AddRoomViewModel(propertyId: UUID())
        let itemViewModel = AddItemViewModel(roomId: UUID())

        roomViewModel.name = "   "
        itemViewModel.name = "   "

        #expect(roomViewModel.isSaveDisabled)
        #expect(itemViewModel.isSaveDisabled)

        roomViewModel.name = "Kitchen"
        itemViewModel.name = "Toaster"

        #expect(!roomViewModel.isSaveDisabled)
        #expect(!itemViewModel.isSaveDisabled)
    }

    @Test("Edit item view model copies initial values and validates blank names")
    func editItemViewModelInitializationAndValidation() {
        let item = makeInventoryItem(roomId: UUID(), name: "Towel")
        let viewModel = EditItemViewModel(item: item)

        #expect(viewModel.name == "Towel")
        #expect(viewModel.description == "")
        #expect(viewModel.expectedQty == 1)
        #expect(!viewModel.isSaveDisabled)

        viewModel.name = "   "
        #expect(viewModel.isSaveDisabled)
    }

    @Test("Edit room view model copies initial values and validates blank names")
    func editRoomViewModelInitializationAndValidation() {
        let room = PropertyRoomModel(
            id: UUID(),
            property_id: UUID(),
            name: "Bedroom",
            description: "Main suite",
            room_type: "Bedroom",
            sort_order: 0,
            created_at: "2026-03-13T00:00:00Z"
        )
        let viewModel = EditRoomViewModel(room: room)

        #expect(viewModel.name == "Bedroom")
        #expect(viewModel.description == "Main suite")
        #expect(viewModel.roomType == "Bedroom")
        #expect(!viewModel.isSaveDisabled)

        viewModel.name = " "
        #expect(viewModel.isSaveDisabled)
    }

    @Test("Room inventory view model starts with expected defaults")
    func roomInventoryDefaults() {
        let room = makeRoom(name: "Kitchen")
        let viewModel = RoomInventoryViewModel(room: room)

        #expect(viewModel.room.id == room.id)
        #expect(viewModel.items.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.showingAddItem)
        #expect(!viewModel.canManageInventory)
    }

    @Test("Inventory item detail view model starts with expected defaults")
    func inventoryItemDetailDefaults() {
        let item = makeInventoryItem(roomId: UUID(), name: "Chair")
        let viewModel = InventoryItemDetailViewModel(item: item)

        #expect(viewModel.item.id == item.id)
        #expect(viewModel.history.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }
}
