import SwiftUI
import PencilKit

struct InventoryImageAnnotationView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    var onSave: (Data) -> Void
    
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                
                GeometryReader { geometry in
                    let imgSize = image.size
                    let viewSize = geometry.size
                    let scale = min(viewSize.width / imgSize.width, viewSize.height / imgSize.height)
                    let scaledWidth = imgSize.width * scale
                    let scaledHeight = imgSize.height * scale
                    
                    ZStack {
                        Image(uiImage: image)
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
            .navigationTitle("Annotate Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
        
        let finalImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            let canvasSize = canvasView.bounds.size
            if !drawing.bounds.isEmpty && canvasSize.width > 0 && canvasSize.height > 0 {
                // The drawing coordinates are relative to the canvas view's actual on-screen bounds.
                // We extract the drawing over the exact canvas size, then seamlessly stretch it up
                // to the original image bounds.
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
        
        // We need to wait a tiny bit for the view to be ready before making it first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            canvasView.becomeFirstResponder()
        }
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
