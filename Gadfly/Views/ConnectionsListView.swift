import SwiftUI

struct ConnectionsListView: View {
    @StateObject private var apiService = GadflyAPIService.shared
    @State private var showAddConnection = false
    @State private var isLoading = false

    var body: some View {
        List {
            if apiService.connections.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)
                        Text("No connections yet")
                            .font(.headline)
                        Text("Add family members or friends to share tasks and send reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                ForEach(apiService.connections) { connection in
                    ConnectionRow(connection: connection)
                }
                .onDelete(perform: deleteConnections)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .navigationTitle("Family & Friends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddConnection = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddConnection) {
            AddConnectionView()
        }
        .refreshable {
            await loadConnections()
        }
        .task {
            await loadConnections()
        }
    }

    private func loadConnections() async {
        isLoading = true
        do {
            try await apiService.fetchConnections()
        } catch {
            print("Failed to load connections: \(error)")
        }
        isLoading = false
    }

    private func deleteConnections(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let connection = apiService.connections[index]
                try? await apiService.deleteConnection(connection.id)
            }
        }
    }
}

struct ConnectionRow: View {
    let connection: GadflyConnection

    var body: some View {
        HStack {
            Circle()
                .fill(connection.hasApp ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(connection.nickname.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(connection.hasApp ? .green : .gray)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.nickname)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(connection.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if connection.hasApp {
                        Label("Has App", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("SMS Only", systemImage: "message.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()
        }
    }
}

struct AddConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = GadflyAPIService.shared

    @State private var nickname = ""
    @State private var phone = ""
    @State private var relationship = "Child"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lookupResult: UserLookupResult?

    let relationships = ["Child", "Partner", "Parent", "Friend", "Coworker", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nickname", text: $nickname)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                        .onChange(of: phone) { _, newValue in
                            if newValue.count >= 10 {
                                lookupPhone()
                            } else {
                                lookupResult = nil
                            }
                        }

                    if let result = lookupResult {
                        if result.hasApp {
                            Label("\(result.name ?? "User") has Gadfly!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("They'll receive SMS reminders", systemImage: "message.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Contact Info")
                }

                Section {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { rel in
                            Text(rel).tag(rel)
                        }
                    }
                } header: {
                    Text("Relationship")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addConnection()
                    }
                    .disabled(nickname.isEmpty || phone.isEmpty || isLoading)
                }
            }
        }
    }

    private func lookupPhone() {
        Task {
            do {
                lookupResult = try await apiService.lookupUser(phone: phone)
            } catch {
                lookupResult = nil
            }
        }
    }

    private func addConnection() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await apiService.addConnection(
                    phone: phone,
                    nickname: nickname,
                    relationship: relationship
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct SharedTasksView: View {
    @StateObject private var apiService = GadflyAPIService.shared
    @State private var showAddTask = false
    @State private var isLoading = false

    var body: some View {
        List {
            if apiService.sharedTasks.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)
                        Text("No shared tasks")
                            .font(.headline)
                        Text("Assign tasks to family members and they'll get reminders until it's done!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section("Tasks I Assigned") {
                    ForEach(apiService.sharedTasks.filter { $0.isOwner }) { task in
                        SharedTaskRow(task: task)
                    }
                }

                Section("Tasks Assigned to Me") {
                    ForEach(apiService.sharedTasks.filter { $0.isAssignedToMe }) { task in
                        SharedTaskRow(task: task, showCompleteButton: true)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
        .navigationTitle("Shared Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddSharedTaskView()
        }
        .refreshable {
            await loadTasks()
        }
        .task {
            await loadTasks()
        }
    }

    private func loadTasks() async {
        isLoading = true
        do {
            try await apiService.fetchSharedTasks()
        } catch {
            print("Failed to load shared tasks: \(error)")
        }
        isLoading = false
    }
}

struct SharedTaskRow: View {
    let task: SharedTask
    var showCompleteButton: Bool = false
    @StateObject private var apiService = GadflyAPIService.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)

                HStack(spacing: 8) {
                    if let deadline = task.deadline {
                        Label(deadline.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Nag: every \(task.nagIntervalMinutes) min")
                        .font(.caption)
                        .foregroundStyle(Color.themeAccent)
                }
            }

            Spacer()

            if showCompleteButton && !task.isCompleted {
                Button {
                    Task {
                        try? await apiService.updateSharedTask(task.id, completed: true)
                    }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }

            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

struct AddSharedTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = GadflyAPIService.shared

    @State private var title = ""
    @State private var selectedConnectionId: String?
    @State private var deadline: Date = Date().addingTimeInterval(3600)
    @State private var hasDeadline = false
    @State private var nagInterval = 15
    @State private var priority = "medium"
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task description", text: $title)
                } header: {
                    Text("What needs to be done?")
                }

                Section {
                    if apiService.connections.isEmpty {
                        Text("Add a connection first in Family & Friends")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Assign to", selection: $selectedConnectionId) {
                            Text("Select person").tag(nil as String?)
                            ForEach(apiService.connections) { connection in
                                Text(connection.nickname).tag(connection.id as String?)
                            }
                        }
                    }
                } header: {
                    Text("Who should do it?")
                }

                Section {
                    Toggle("Set Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker("Deadline", selection: $deadline)
                    }

                    Picker("Nag Interval", selection: $nagInterval) {
                        Text("Every 5 min").tag(5)
                        Text("Every 10 min").tag(10)
                        Text("Every 15 min").tag(15)
                        Text("Every 30 min").tag(30)
                        Text("Every hour").tag(60)
                    }

                    Picker("Priority", selection: $priority) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                } header: {
                    Text("Timing")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.themeBackground)
            .navigationTitle("Assign Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Assign") {
                        assignTask()
                    }
                    .disabled(title.isEmpty || selectedConnectionId == nil || isLoading)
                }
            }
            .task {
                try? await apiService.fetchConnections()
            }
        }
    }

    private func assignTask() {
        guard let connectionId = selectedConnectionId,
              let connection = apiService.connections.first(where: { $0.id == connectionId }) else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await apiService.createSharedTask(
                    title: title,
                    assignedPhone: connection.connectedPhone,
                    assignedDeviceId: connection.connectedDeviceId,
                    deadline: hasDeadline ? deadline : nil,
                    priority: priority,
                    nagIntervalMinutes: nagInterval
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        ConnectionsListView()
    }
}
