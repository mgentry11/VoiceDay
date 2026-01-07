import SwiftUI

/// End-of-Day Self-Check View
/// Full-screen interface with big, easy-to-tap buttons for ADHD users
struct SelfCheckView: View {
    @ObservedObject private var service = SelfCheckService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showLocationInput: String? = nil
    @State private var locationText: String = ""

    var body: some View {
        ZStack {
            // Green gradient background
            LinearGradient(
                colors: [Color(hex: "#1a2e1a"), Color(hex: "#0f1a0f")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                if service.isComplete {
                    // Completion view
                    completionView
                } else {
                    // Items list
                    ScrollView {
                        itemsList
                    }

                    // Progress
                    progressBar
                }
            }
        }
        .onAppear {
            service.resetChecks()
            speakIntro()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding()
            }

            Text("🎉 All Done!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Let's make sure you know where everything is")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 20)
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(service.activeItems) { item in
                itemCard(item)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func itemCard(_ item: SelfCheckService.CheckItem) -> some View {
        let isChecked = service.checkedItems.contains(item.id)
        let savedLocation = service.itemLocations[item.id]

        return VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isChecked ? .green : .white.opacity(0.8))
                    .frame(width: 50)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    if let location = savedLocation, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    // Yes button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            service.checkItem(item.id)
                            showLocationInput = nil
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isChecked ? .white : .green)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(isChecked ? Color.green : Color.green.opacity(0.2))
                            )
                    }

                    // No/Find button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showLocationInput = item.id
                            locationText = savedLocation ?? ""
                        }
                    } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.orange)
                            .frame(width: 50, height: 50)
                            .background(
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isChecked ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isChecked ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )

            // Location input (shown when "?" is tapped)
            if showLocationInput == item.id {
                locationInputView(for: item)
            }
        }
    }

    private func locationInputView(for item: SelfCheckService.CheckItem) -> some View {
        HStack(spacing: 8) {
            TextField("Where did you last see it?", text: $locationText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .foregroundStyle(.white)

            Button("Save") {
                if !locationText.isEmpty {
                    service.setLocation(for: item.id, location: locationText)
                    showLocationInput = nil
                    locationText = ""
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.orange)
            .foregroundStyle(.black)
            .fontWeight(.semibold)
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.green, Color(hex: "#34d399")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * service.progress)
                        .animation(.spring(response: 0.3), value: service.progress)
                }
            }
            .frame(height: 6)

            Text("\(service.checkedItems.count) of \(service.activeItems.count) checked")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("✨")
                .font(.system(size: 80))

            Text("You're all set!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Everything is accounted for.\nHave a great rest of your day!")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(30)
            }
            .padding(.top, 20)

            Spacer()
        }
        .transition(.opacity.combined(with: .scale))
    }

    // MARK: - Helpers

    private func speakIntro() {
        Task { @MainActor in
            await AppDelegate.shared?.speakMessage("Great job finishing your tasks! Let's do a quick check to make sure you know where your important things are.")
        }
    }
}

// MARK: - Settings View for Self-Check

struct SelfCheckSettingsView: View {
    @ObservedObject private var service = SelfCheckService.shared
    @State private var showAddCustomItem = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable End-of-Day Check", isOn: $service.isEnabled)
            } footer: {
                Text("When all tasks are done, remind me to locate important items")
            }

            if service.isEnabled {
                // Custom items section
                if !service.customItems.isEmpty {
                    Section {
                        ForEach(service.customItems) { item in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { service.enabledItems.contains(item.id) },
                                    set: { _ in service.toggleItem(item.id) }
                                )) {
                                    HStack {
                                        Image(systemName: item.icon)
                                            .foregroundStyle(.green)
                                            .frame(width: 24)
                                        VStack(alignment: .leading) {
                                            Text(item.name)
                                            Text(item.question)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    service.removeCustomItem(item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Your Custom Items")
                    }
                }

                // Add custom item button
                Section {
                    Button {
                        showAddCustomItem = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Add Custom Item")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section {
                    ForEach(SelfCheckService.allItems) { item in
                        Toggle(isOn: Binding(
                            get: { service.enabledItems.contains(item.id) },
                            set: { _ in service.toggleItem(item.id) }
                        )) {
                            HStack {
                                Image(systemName: item.icon)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text(item.name)
                            }
                        }
                    }
                } header: {
                    Text("Preset Items")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .navigationTitle("End-of-Day Check")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddCustomItem) {
            AddCustomCheckItemView()
        }
    }
}

// MARK: - Add Custom Item View

struct AddCustomCheckItemView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var question: String = ""
    @State private var selectedIcon: String = "star.fill"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text input section
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Item Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Back Door", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Question to ask")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g., Did you lock the back door?", text: $question)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.sentences)
                    }
                }
                .padding()

                Divider()

                // Icon picker
                IconPickerGrid(selectedIcon: $selectedIcon)
            }
            .background(Color.themeBackground)
            .navigationTitle("Add Custom Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addItem() {
        let finalQuestion = question.isEmpty ? "Did you check \(name.lowercased())?" : question
        // Access service directly only when adding - no observation needed
        SelfCheckService.shared.addCustomItem(name: name, question: finalQuestion, icon: selectedIcon)
        dismiss()
    }
}

// Separate view for icon picker to prevent re-renders when typing
private struct IconPickerGrid: View {
    @Binding var selectedIcon: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 12)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(SelfCheckService.customItemIcons, id: \.icon) { iconInfo in
                        Button {
                            selectedIcon = iconInfo.icon
                        } label: {
                            Image(systemName: iconInfo.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(selectedIcon == iconInfo.icon ? .green : .secondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(selectedIcon == iconInfo.icon ? Color.green.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Self-Check Prompt View (Do Now or Later)

struct SelfCheckPromptView: View {
    let onDoNow: () -> Void
    let onScheduleLater: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("All tasks done!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Time for your end-of-day check.\nMake sure you know where your important things are.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.bottom, 28)

            // Do it now button
            Button {
                onDoNow()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Do it now")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green)
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)

            // Later options
            VStack(spacing: 12) {
                Text("Or remind me later:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                HStack(spacing: 12) {
                    ForEach([1, 2, 3], id: \.self) { hours in
                        Button {
                            onScheduleLater(hours)
                        } label: {
                            Text("In \(hours) hr")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Skip button
            Button {
                onSkip()
            } label: {
                Text("Skip for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Preview

#Preview("Self Check View") {
    SelfCheckView()
}

#Preview("Self Check Settings") {
    NavigationStack {
        SelfCheckSettingsView()
    }
}
