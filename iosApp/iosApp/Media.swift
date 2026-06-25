import SwiftUI
import UIKit
import PhotosUI

// =====================================================================================
//  Media — on-device photo storage + camera/library pickers + one reusable control.
//  Everything stays on the phone: JPEGs live in Documents, the model only keeps names.
// =====================================================================================

// ---- disk store: dumb, synchronous, swallow-the-error like the rest of the app -------
enum ImageStore {
    static var dir: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    // save a (downscaled) jpeg, return the bare filename to stash in the model
    static func save(_ img: UIImage, q: CGFloat = 0.82, maxDim: CGFloat = 1600) -> String? {
        let scaled = downscale(img, maxDim: maxDim)
        guard let data = scaled.jpegData(compressionQuality: q) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do { try data.write(to: dir.appendingPathComponent(name)); return name }
        catch { return nil }
    }

    static func load(_ name: String?) -> UIImage? {
        guard let n = name, !n.isEmpty else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(n).path)
    }

    static func delete(_ name: String?) {
        guard let n = name, !n.isEmpty else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(n))
    }

    // keep memory + disk sane: cap the longest edge
    private static func downscale(_ img: UIImage, maxDim: CGFloat) -> UIImage {
        let w = img.size.width, h = img.size.height
        let m = max(w, h)
        guard m > maxDim, m > 0 else { return img }
        let k = maxDim / m
        let size = CGSize(width: w * k, height: h * k)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

// ---- camera (UIKit, the only path that actually needs a permission string) -----------
struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onPick(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

// ---- library (PHPicker — no permission prompt on iOS 16, system-sandboxed) ------------
struct LibraryPicker: UIViewControllerRepresentable {
    var onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 1
        let p = PHPickerViewController(configuration: cfg)
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coord { Coord(self) }

    final class Coord: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPicker
        init(_ p: LibraryPicker) { parent = p }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let prov = results.first?.itemProvider, prov.canLoadObject(ofClass: UIImage.self) else {
                parent.dismiss(); return
            }
            prov.loadObject(ofClass: UIImage.self) { obj, _ in
                if let img = obj as? UIImage {
                    DispatchQueue.main.async { self.parent.onPick(img) }
                }
            }
            parent.dismiss()
        }
    }
}

private enum PickSheet: Int, Identifiable { case camera, library; var id: Int { rawValue } }

// ---- reusable control: render any label, handle source choice + present the picker ----
struct PhotoPicker<Label: View>: View {
    var hasImage: Bool
    var onPick: (UIImage) -> Void
    var onRemove: (() -> Void)? = nil
    @ViewBuilder var label: () -> Label

    @State private var askSource = false
    @State private var sheet: PickSheet? = nil

    var body: some View {
        Button { Haptics.tap(); askSource = true } label: { label() }
            .buttonStyle(.plain)
            .confirmationDialog("Add a photo", isPresented: $askSource, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { sheet = .camera }
                }
                Button("Choose from Library") { sheet = .library }
                if hasImage, let onRemove { Button("Remove Photo", role: .destructive) { onRemove() } }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .camera:  CameraPicker(onPick: onPick).ignoresSafeArea()
                case .library: LibraryPicker(onPick: onPick).ignoresSafeArea()
                }
            }
    }
}
