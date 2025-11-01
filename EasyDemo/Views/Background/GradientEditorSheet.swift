import SwiftUI

struct GradientEditorSheet: View {
    @Binding var color1: Color
    @Binding var color2: Color
    @Binding var startPoint: UnitPoint
    @Binding var endPoint: UnitPoint
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let directions: [(String, UnitPoint, UnitPoint)] = [
        ("Top to Bottom", .top, .bottom),
        ("Left to Right", .leading, .trailing),
        ("Diagonal", .topLeading, .bottomTrailing),
        ("Diagonal", .topTrailing, .bottomLeading)
    ]

    var body: some View {
        VStack(spacing: UIConstants.Padding.standard) {
            Text("Edit Gradient")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: UIConstants.Padding.small) {
                ColorPicker("Start Color", selection: $color1, supportsOpacity: false)
                ColorPicker("End Color", selection: $color2, supportsOpacity: false)
            }
            .padding()

            VStack(alignment: .leading, spacing: UIConstants.Padding.tight) {
                Text("Direction")
                    .font(.headline)

                HStack(spacing: UIConstants.Padding.tight) {
                    ForEach(directions, id: \.0) { direction in
                        Button(direction.0) {
                            startPoint = direction.1
                            endPoint = direction.2
                        }
                        .buttonStyle(.bordered)
                        .tint(startPoint == direction.1 && endPoint == direction.2 ? .accentColor : .gray)
                    }
                }
            }
            .padding()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color1, color2],
                        startPoint: startPoint,
                        endPoint: endPoint
                    )
                )
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
        .frame(width: 500, height: 500)
    }
}
