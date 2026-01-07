import SwiftUI
import Speech

/// Manage morning self-checks - add via voice, reorder, delete
struct ManageSelfChecksView: View {
    @ObservedObject private var checklistService = MorningChecklistService.shared
    @ObservedObject private var themeColors = ThemeColors.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isRecording = false
    @State private var transcribedText = ""
    @State private var showingAddSheet = false
    @State private var editingCheck: MorningChecklistService.SelfCheck?

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    var body: some View {
        NavigationStack {
            List {
                // Settings section
                Section {
                    Toggle("Enable Morning Checklist", isOn: $checklistService.isEnabled)

                    if checklistService.isEnabled {
                        Toggle("Show when app opens", isOn: $checklistService.triggerOnAppOpen)

                        if !checklistService.triggerOnAppOpen {
                            DatePicker(
                                "Start time",
                                selection: $checklistService.triggerTime,
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                } header: {
                    Text("Settings")
                }

                // Self-checks section
                Section {
                    if checklistService.selfChecks.isEmpty {
                        Text("No checks yet. Add your first one!")
                            .foregroundStyle(themeColors.subtext)
                            .italic()
                    } else {
                        ForEach(checklistService.selfChecks) { check in
                            SelfCheckRow(
                                check: check,
                                onToggleActive: {
                                    checklistService.toggleCheckActive(id: check.id)
                                },
                                onEdit: {
                                    editingCheck = check
                                }
                            )
                        }
                        .onDelete(perform: deleteChecks)
                        .onMove(perform: moveChecks)
                    }
                } header: {
                    HStack {
                        Text("Your Morning Checks")
                        Spacer()
                        Text("\(checklistService.selfChecks.count) items")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                } footer: {
                    Text("These are personal checks - not tasks. Things like 'Take medication', 'Check calendar', 'Pack lunch'.")
                }

                // Add button section
                Section {
                    Button {
                        showingAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.themeAccent)

                            Text("Add New Check")
                                .foregroundStyle(themeColors.text)

                            Spacer()

                            Image(systemName: "mic.fill")
                                .foregroundStyle(themeColors.subtext)
                        }
                    }
                }

                // Sample checks section
                if checklistService.selfChecks.isEmpty {
                    Section {
                        Button {
                            checklistService.addSampleChecks()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.orange)
                                Text("Add sample checks to get started")
                                    .foregroundStyle(themeColors.text)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Morning Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddSelfCheckSheet(onAdd: { title in
                    checklistService.addSelfCheck(title)
                })
            }
            .sheet(item: $editingCheck) { check in
                EditSelfCheckSheet(
                    check: check,
                    onSave: { newTitle in
                        checklistService.updateCheckTitle(id: check.id, newTitle: newTitle)
                    },
                    onDelete: {
                        checklistService.removeSelfCheck(id: check.id)
                    }
                )
            }
        }
    }

    private func deleteChecks(at offsets: IndexSet) {
        for index in offsets {
            checklistService.removeSelfCheck(at: index)
        }
    }

    private func moveChecks(from source: IndexSet, to destination: Int) {
        checklistService.moveCheck(from: source, to: destination)
    }
}

// MARK: - Self Check Row

struct SelfCheckRow: View {
    let check: MorningChecklistService.SelfCheck
    let onToggleActive: () -> Void
    let onEdit: () -> Void

    @ObservedObject private var themeColors = ThemeColors.shared

    var body: some View {
        HStack(spacing: 12) {
            // Active toggle
            Button(action: onToggleActive) {
                Image(systemName: check.isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(check.isActive ? themeColors.accent : themeColors.subtext)
            }
            .buttonStyle(.plain)

            // Title
            Text(check.title)
                .foregroundStyle(check.isActive ? themeColors.text : themeColors.subtext)
                .strikethrough(!check.isActive)

            Spacer()

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(themeColors.subtext)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Self Check Sheet

struct AddSelfCheckSheet: View {
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared

    @State private var title = ""
    @State private var isRecording = false

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("What do you need to check each morning?")
                    .font(.headline)
                    .foregroundStyle(themeColors.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                // Text field (for typed input)
                TextField("e.g., Take my medication", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                // OR divider
                HStack {
                    Rectangle()
                        .fill(themeColors.subtext.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundStyle(themeColors.subtext)
                    Rectangle()
                        .fill(themeColors.subtext.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal)

                // Voice input button
                Button {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color.themeAccent)
                                .frame(width: 80, height: 80)

                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(isRecording ? .white : .black)
                        }

                        Text(isRecording ? "Listening..." : "Tap to speak")
                            .font(.caption)
                            .foregroundStyle(themeColors.subtext)
                    }
                }

                Spacer()

                // Add button
                Button {
                    if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        onAdd(title.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                } label: {
                    Text("Add Check")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(title.isEmpty ? Color.gray : Color.themeAccent)
                        .cornerRadius(12)
                }
                .disabled(title.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Add Morning Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else { return }

            DispatchQueue.main.async {
                self.isRecording = true
                self.startSpeechRecognition()
            }
        }
    }

    private func startSpeechRecognition() {
        let request = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                self.title = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}

// MARK: - Edit Self Check Sheet

struct EditSelfCheckSheet: View {
    let check: MorningChecklistService.SelfCheck
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeColors = ThemeColors.shared

    @State private var title: String

    init(check: MorningChecklistService.SelfCheck, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.check = check
        self.onSave = onSave
        self.onDelete = onDelete
        self._title = State(initialValue: check.title)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Check title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top, 24)

                Spacer()

                // Delete button
                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete this check")
                    }
                    .foregroundStyle(.red)
                }

                // Save button
                Button {
                    if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        onSave(title.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.themeAccent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Edit Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ManageSelfChecksView()
}
