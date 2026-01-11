import SwiftUI
import EventKit

struct DualInputFocusHomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var calendarService = CalendarService()
    @StateObject private var speechService = SpeechService.shared
    
    @State private var reminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var showVoiceInput = false
    @State private var showTextInput = false
    
    private var currentTask: EKReminder? {
        reminders.filter { !$0.isCompleted }.sorted { r1, r2 in
            let p1 = r1.priority == 0 ? 5 : r1.priority
            let p2 = r2.priority == 0 ? 5 : r2.priority
            if p1 != p2 { return p1 < p2 }
            return (r1.dueDateComponents?.date ?? .distantFuture) < (r2.dueDateComponents?.date ?? .distantFuture)
        }.first
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // 90pt voice button + 60pt text button
                HStack(spacing: 20) {
                    Button { 
                        speechService.queueSpeech("What would you like to focus on?")
                        showVoiceInput = true 
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [Color.red, Color.orange], startPoint: .top, endPoint: .bottom))
                            .frame(width: 90, height: 90)
                            .overlay(Image(systemName: "mic.fill").font(.system(size: 36)).foregroundColor(.white))
                    }
                    
                    Button { 
                        showTextInput = true 
                    } label: {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .overlay(Image(systemName: "plus").font(.system(size: 28)).foregroundColor(.white))
                    }
                }
                
                if let task = currentTask {
                    VStack(spacing: 30) {
                        Text(task.title)
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Button("Done") { 
                            Task { await completeTask(task) }
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                } else if !isLoading {
                    Text("No tasks")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
        }
        .onAppear { loadReminders() }
        .sheet(isPresented: $showVoiceInput) {
            SimpleInputView(onConfirm: { text in
                Task { 
                    await addTask(text)
                    speechService.queueSpeech("Got it. \(text) is now your focus.")
                }
                showVoiceInput = false
            })
        }
        .sheet(isPresented: $showTextInput) {
            SimpleInputView(onConfirm: { text in
                Task { 
                    await addTask(text)
                }
                showTextInput = false
            })
        }
    }
    
    private func loadReminders() {
        Task {
            do {
                let loaded = try await calendarService.fetchReminders()
                await MainActor.run { reminders = loaded; isLoading = false }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    private func completeTask(_ task: EKReminder) async {
        try? await calendarService.completeReminder(task)
        await MainActor.run {
            reminders.removeAll { $0.calendarItemIdentifier == task.calendarItemIdentifier }
        }
        // Voice confirmation with ElevenLabs
        speechService.queueSpeech("Nice work! \(task.title) is complete.")
    }
    
    private func addTask(_ text: String) async {
        // TODO: Use OpenAI parsing to create proper reminder
        // For now, just reload to show the task was acknowledged
        await loadReminders()
    }
}

struct SimpleInputView: View {
    let onConfirm: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Task", text: $text)
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { 
                    Button("Add") { onConfirm(text); dismiss() }.disabled(text.isEmpty)
                }
            }
        }
    }
}
