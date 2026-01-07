import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var showingDictation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if connectivity.tasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }

                // Dictate button
                Button {
                    showingDictation = true
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Add Task")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .navigationTitle("The Gadfly")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingDictation) {
            DictationView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("No tasks")
                .font(.headline)

            Text("Add one or sync from iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var taskList: some View {
        List {
            ForEach(connectivity.tasks) { task in
                TaskRow(task: task) {
                    connectivity.sendTaskCompleted(taskId: task.id.uuidString)
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.success)
                    #endif
                }
            }
        }
        #if os(watchOS)
        .listStyle(.carousel)
        #else
        .listStyle(.plain)
        #endif
    }
}

struct TaskRow: View {
    let task: WatchTask
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.headline)
                .lineLimit(2)

            if let deadline = task.deadline {
                Text(deadline, style: .relative)
                    .font(.caption)
                    .foregroundStyle(deadline < Date() ? .red : .secondary)
            }

            HStack {
                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)

                Text(task.priority.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onComplete()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var priorityColor: Color {
        switch task.priority {
        case "high": return .red
        case "medium": return .yellow
        default: return .green
        }
    }
}

struct DictationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @State private var dictatedText = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Speak your task")
                .font(.headline)

            // Use TextField with dictation
            TextField("Task...", text: $dictatedText)
                .multilineTextAlignment(.center)

            if isProcessing {
                ProgressView()
                    .tint(.green)
            } else {
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.red)

                    Spacer()

                    Button("Add") {
                        guard !dictatedText.isEmpty else { return }
                        isProcessing = true
                        connectivity.sendNewTask(text: dictatedText)
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.success)
                        #endif
                        dismiss()
                    }
                    .disabled(dictatedText.isEmpty)
                    .foregroundStyle(.green)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
