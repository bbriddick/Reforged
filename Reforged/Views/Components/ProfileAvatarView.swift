import SwiftUI

// MARK: - Profile Avatar View (Reusable)

struct ProfileAvatarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    let size: CGFloat
    var showEditBadge: Bool = false

    private var profileImage: UIImage? {
        guard let path = appState.user.profileImagePath, !path.isEmpty else { return nil }
        return ProfileImageService.shared.loadImage(named: path)
    }

    private var profileBorderColor: Color {
        switch appState.user.activeProfileBorder {
        case "border-gold": return Color.reforgedGold
        case "border-flame": return Color.reforgedCoral
        case "border-crown": return Color.purple
        case "border-diamond": return Color.cyan
        default: return Color.reforgedGold
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(profileBorderColor, lineWidth: size > 60 ? 4 : 2)
                    )
            } else {
                Text(appState.user.avatar.isEmpty ? "🦁" : appState.user.avatar)
                    .font(.system(size: size * 0.6))
                    .frame(width: size, height: size)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(profileBorderColor, lineWidth: size > 60 ? 4 : 2)
                    )
            }

            if showEditBadge {
                ZStack {
                    Circle()
                        .fill(Color.reforgedNavy)
                        .frame(width: size * 0.3, height: size * 0.3)

                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.14))
                        .foregroundStyle(.white)
                }
                .offset(x: size * 0.02, y: size * 0.02)
            }
        }
    }
}

// MARK: - Standalone Profile Avatar (no EnvironmentObject, for share cards)

struct StandaloneProfileAvatar: View {
    let avatar: String
    let profileImagePath: String?
    let size: CGFloat
    var borderColor: Color = .reforgedGold

    private var profileImage: UIImage? {
        guard let path = profileImagePath, !path.isEmpty else { return nil }
        return ProfileImageService.shared.loadImage(named: path)
    }

    var body: some View {
        if let image = profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(borderColor, lineWidth: size > 60 ? 3 : 2)
                )
        } else {
            Text(avatar.isEmpty ? "🔥" : avatar)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(borderColor, lineWidth: size > 60 ? 3 : 2)
                )
        }
    }
}

// MARK: - Camera Picker (UIImagePickerController Wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
