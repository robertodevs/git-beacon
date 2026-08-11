import SwiftUI

/// Token + watched-repo editor. Reads current values from the Keychain
/// and UserDefaults on open, writes them back on Save, then hands off to
/// `onSave` so the caller can kick a fresh poll with the new config.
struct SettingsView: View {
    @State private var token: String
    @State private var repos: [String]
    @State private var newRepo = ""
    private let onSave: () -> Void

    init(onSave: @escaping () -> Void) {
        _token = State(initialValue: KeychainTokenStore.load() ?? "")
        _repos = State(initialValue: WatchedReposConfig.repos)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("GitHub Token").font(.headline)
                SecureField("ghp_...", text: $token)
                    .textFieldStyle(.roundedBorder)
                Text("Needs `repo` read scope. Stored in the Keychain, never written to disk in plain text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Watched Repos").font(.headline)
                List {
                    ForEach(repos, id: \.self) { repo in
                        Text(repo)
                    }
                    .onDelete { repos.remove(atOffsets: $0) }
                }
                .frame(height: 140)
                .listStyle(.bordered)

                HStack {
                    TextField("owner/name", text: $newRepo)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addRepo)
                    Button("Add", action: addRepo)
                        .disabled(!isValidRepo(newRepo))
                }
            }

            HStack {
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func addRepo() {
        let trimmed = newRepo.trimmingCharacters(in: .whitespaces)
        guard isValidRepo(trimmed), !repos.contains(trimmed) else { return }
        repos.append(trimmed)
        newRepo = ""
    }

    private func isValidRepo(_ value: String) -> Bool {
        let parts = value.split(separator: "/")
        return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
    }

    private func save() {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            KeychainTokenStore.save(trimmedToken)
        }
        WatchedReposConfig.repos = repos
        onSave()
    }
}
