import Foundation

@MainActor
class CustomDictionaryService: ObservableObject {
    static let shared = CustomDictionaryService()
    
    @Published var customWords: [String: String] = [:]
    
    private let storageKey = "custom_dictionary"
    
    private init() {
        load()
    }
    
    func addWord(_ word: String, pronunciation: String) {
        customWords[word.lowercased()] = pronunciation
        save()
    }
    
    func removeWord(_ word: String) {
        customWords.removeValue(forKey: word.lowercased())
        save()
    }
    
    func pronunciation(for word: String) -> String? {
        customWords[word.lowercased()]
    }
    
    private func save() {
        UserDefaults.standard.set(customWords, forKey: storageKey)
    }
    
    private func load() {
        if let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] {
            customWords = saved
        }
    }
}
