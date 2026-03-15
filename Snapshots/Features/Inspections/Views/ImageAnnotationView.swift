import SwiftUI

#if canImport(UIKit)
import PencilKit
import UIKit

struct InventoryImageAnnotationView: View {
    let image: PlatformImage
    @Binding var isPresented: Bool
    var onSave: (Data) -> Void

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.platformSecondarySystemBackground.ignoresSafeArea()

                GeometryReader { geometry in
                    let imgSize = image.size
                    let viewSize = geometry.size
                    let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
                    let scaledWidth = imgSize.width * scale
                    let scaledHeight = imgSize.height * scale

                    ZStack {
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: scaledWidth, height: scaledHeight)
                            .shadow(radius: 10)

                        CanvasRepresentable(canvasView: $canvasView, toolPicker: toolPicker)
                            .frame(width: scaledWidth, height: scaledHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("annotation.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { isPresented = false }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        saveAnnotatedImage()
                        isPresented = false
                    }
                    .fontWeight(.bold)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button(action: { canvasView.undoManager?.undo() }) {
                            Image(systemName: "arrow.uturn.backward.circle")
                        }
                        Button(action: { canvasView.undoManager?.redo() }) {
                            Image(systemName: "arrow.uturn.forward.circle")
                        }
                    }
                }
            }
        }
    }

    private func saveAnnotatedImage() {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let drawing = canvasView.drawing

        let finalImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            let canvasSize = canvasView.bounds.size
            if !drawing.bounds.isEmpty && canvasSize.width > 0 && canvasSize.height > 0 {
                let drawingImage = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: 1.0)
                drawingImage.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }

        if let data = finalImage.jpegData(compressionQuality: 0.8) {
            onSave(data)
        }
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let toolPicker: PKToolPicker

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            canvasView.becomeFirstResponder()
        }

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

#else
struct InventoryImageAnnotationView: View {
    let image: PlatformImage
    @Binding var isPresented: Bool
    var onSave: (Data) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)

                Text("annotation.unavailable_mac")
                    .foregroundStyle(.secondary)

                Button("common.done") {
                    if let data = platformJPEGData(from: image, compressionQuality: 0.8) {
                        onSave(data)
                    }
                    isPresented = false
                }
            }
            .padding(24)
            .navigationTitle("annotation.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { isPresented = false }
                }
            }
        }
    }
}
#endif
