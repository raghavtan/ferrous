import SwiftUI

/// A button used for tabs in the main menu
struct TabButton: View {
    /// The title of the tab
    let title: String

    /// Whether the tab is selected
    let isSelected: Bool

    /// The action to perform when the tab is tapped
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                )
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack {
        TabButton(title: "Selected", isSelected: true) {}
        TabButton(title: "Not Selected", isSelected: false) {}
    }
    .padding()
}
