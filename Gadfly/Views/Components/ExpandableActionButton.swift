import SwiftUI

struct ExpandableAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
}

struct ExpandableActionButton: View {
    let primaryIcon: String
    let primaryColor: Color
    let actions: [ExpandableAction]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                ForEach(actions.reversed()) { action in
                    actionButton(action)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : primaryIcon)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(isExpanded ? Color.gray : primaryColor)
                    )
                    .shadow(color: primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private func actionButton(_ action: ExpandableAction) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded = false
            }
            action.action()
        } label: {
            HStack(spacing: 8) {
                Text(action.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.themeText)
                    .padding(.leading, 12)
                
                Image(systemName: action.icon)
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(action.color))
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.themeSecondary)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }
}

struct ExpandableHorizontalButtons: View {
    let actions: [ExpandableAction]
    @State private var isExpanded = false
    
    var body: some View {
        HStack(spacing: 8) {
            if isExpanded {
                ForEach(actions) { action in
                    Button {
                        action.action()
                        withAnimation { isExpanded = false }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.title3)
                            Text(action.label)
                                .font(.caption2)
                        }
                        .foregroundStyle(action.color)
                        .frame(width: 60, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(action.color.opacity(0.1))
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.right" : "ellipsis")
                    .font(.title3)
                    .foregroundStyle(Color.themeSubtext)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.themeSecondary)
                    )
            }
        }
    }
}

struct CollapsibleButtonRow: View {
    let title: String
    let buttons: [ExpandableAction]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.themeSubtext)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.themeSubtext)
                }
            }
            
            if isExpanded {
                HStack(spacing: 8) {
                    ForEach(buttons) { button in
                        Button {
                            button.action()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: button.icon)
                                    .font(.title3)
                                Text(button.label)
                                    .font(.caption2)
                            }
                            .foregroundStyle(button.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(button.color.opacity(0.1))
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.themeSecondary)
        .cornerRadius(16)
    }
}

#Preview {
    VStack {
        Spacer()
        HStack {
            Spacer()
            ExpandableActionButton(
                primaryIcon: "plus",
                primaryColor: .orange,
                actions: [
                    ExpandableAction(icon: "mic.fill", label: "Voice", color: .blue) { },
                    ExpandableAction(icon: "keyboard", label: "Type", color: .green) { },
                    ExpandableAction(icon: "camera.fill", label: "Photo", color: .purple) { }
                ]
            )
            .padding()
        }
    }
    .background(Color.themeBackground)
}
