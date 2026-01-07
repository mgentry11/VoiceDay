import SwiftUI

// MARK: - Body Doubling View

/// Virtual co-working interface
struct BodyDoublingView: View {
    @ObservedObject var service = BodyDoublingService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: BodyDoublingService.SessionType = .solo
    @State private var taskTitle = ""
    @State private var showingSessionPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeColors.background.ignoresSafeArea()

                if service.isSessionActive {
                    activeSessionView
                } else {
                    startSessionView
                }
            }
            .navigationTitle("Body Doubling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !service.isSessionActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("History") {
                            // Show history
                        }
                    }
                }
            }
        }
    }

    // MARK: - Start Session View

    private var startSessionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Explanation
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(themeColors.accent)

                    Text("Work Together")
                        .font(.title2.bold())
                        .foregroundStyle(themeColors.text)

                    Text("Body doubling helps you stay focused by working alongside others - even virtually.")
                        .font(.subheadline)
                        .foregroundStyle(themeColors.subtext)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Session type picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your style")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    ForEach(BodyDoublingService.SessionType.allCases, id: \.self) { type in
                        SessionTypeButton(
                            type: type,
                            isSelected: selectedType == type,
                            onSelect: { selectedType = type }
                        )
                    }
                }
                .padding(.horizontal)

                // Task input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you working on?")
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    TextField("e.g., Writing report", text: $taskTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)

                // Start button
                Button {
                    service.startSession(
                        type: selectedType,
                        taskTitle: taskTitle.isEmpty ? nil : taskTitle
                    )
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Session")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(themeColors.accent)
                    )
                }
                .padding(.horizontal)

                // Stats
                if service.sessionCount > 0 {
                    statsCard
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Session info
            if let session = service.currentSession {
                VStack(spacing: 16) {
                    // Partner avatar
                    ZStack {
                        Circle()
                            .fill(themeColors.accent.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: session.partner?.avatar ?? "person.2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(themeColors.accent)

                        // Pulse animation
                        Circle()
                            .stroke(themeColors.accent.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: pulseScale
                            )
                    }
                    .onAppear {
                        pulseScale = 1.2
                        pulseOpacity = 0
                    }

                    // Partner name
                    Text(session.partner?.name ?? "Focus Partner")
                        .font(.title2.bold())
                        .foregroundStyle(themeColors.text)

                    // Task
                    if let task = session.taskTitle {
                        Text("Working on: \(task)")
                            .font(.subheadline)
                            .foregroundStyle(themeColors.subtext)
                    }

                    // Duration
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                        Text(session.durationString)
                    }
                    .font(.headline)
                    .foregroundStyle(themeColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(themeColors.accent.opacity(0.15))
                    )

                    // Focus score
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(session.focusScore * 5) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                        Text("Focus")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                }
            }

            Spacer()

            // Other people working (for async mode)
            if service.currentSession?.type == .async {
                othersWorkingCard
            }

            // End button
            Button {
                service.endSession()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("End Session")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange)
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.5

    // MARK: - Others Working Card

    private var othersWorkingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Working right now")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            ForEach(service.availablePartners.prefix(3)) { partner in
                HStack(spacing: 12) {
                    Image(systemName: partner.avatar)
                        .font(.title3)
                        .foregroundStyle(themeColors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(partner.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(themeColors.text)

                        if let task = partner.currentTask {
                            Text(task)
                                .font(.caption)
                                .foregroundStyle(themeColors.subtext)
                        }
                    }

                    Spacer()

                    Text("\(Int(partner.sessionDuration / 60))m")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
        .padding(.horizontal)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Stats")
                .font(.headline)
                .foregroundStyle(themeColors.text)

            HStack(spacing: 24) {
                VStack {
                    Text("\(service.sessionCount)")
                        .font(.title2.bold())
                        .foregroundStyle(themeColors.accent)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }

                VStack {
                    Text("\(Int(service.totalSessionTime / 3600))h")
                        .font(.title2.bold())
                        .foregroundStyle(themeColors.accent)
                    Text("Total Time")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }

                VStack {
                    Text(String(format: "%.0f%%", service.averageFocusScore * 100))
                        .font(.title2.bold())
                        .foregroundStyle(themeColors.accent)
                    Text("Focus")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColors.secondary)
        )
        .padding(.horizontal)
    }
}

// MARK: - Session Type Button

struct SessionTypeButton: View {
    let type: BodyDoublingService.SessionType
    let isSelected: Bool
    let onSelect: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(themeColors.accent.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundStyle(themeColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundStyle(themeColors.text)

                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? themeColors.accent : themeColors.subtext.opacity(0.5))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeColors.secondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? themeColors.accent : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Body Doubling") {
    BodyDoublingView()
}
