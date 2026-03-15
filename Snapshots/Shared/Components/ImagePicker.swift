import SwiftUI

#if canImport(UIKit)
import UIKit

typealias PlatformImagePickerSourceType = UIImagePickerController.SourceType

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: PlatformImage?
    var sourceType: PlatformImagePickerSourceType = .camera
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? PlatformImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#else
enum PlatformImagePickerSourceType {
    case camera
    case photoLibrary
}

struct ImagePicker: View {
    @Binding var image: PlatformImage?
    var sourceType: PlatformImagePickerSourceType = .camera

    var body: some View {
        ContentUnavailableView(
            "image_picker.camera_unavailable_title",
            systemImage: "camera",
            description: Text("image_picker.camera_unavailable_description")
        )
    }
}
#endif
