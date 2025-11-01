import SwiftUI

struct ColorPickerSheet: View {
    @Binding var color: Color
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: UIConstants.Padding.standard) {
            Text("Choose Color")
                .font(.title2)
                .fontWeight(.bold)

            ColorPicker("Background Color", selection: $color, supportsOpacity: false)
                .padding()

            Rectangle()
                .fill(color)
                .frame(height: UIConstants.Size.thumbnailHeight)
                .cornerRadius(UIConstants.Size.cornerRadius)
                .padding()

            HStack(spacing: UIConstants.Padding.small) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Apply") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}
