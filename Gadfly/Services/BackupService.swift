import Foundation
import SQLite3

class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    // MARK: - Keys
    
    private let allKeys: [String] = [
        "has_completed_onboarding",
        "selected_voice_id",
        "selected_voice_name",
        "selected_theme",
        "selected_color_theme",
        "selected_personality",
        "app_version",
        "user_name",
        "user_phone",
        "is_registered",
        "is_simple_mode",
        "keep_screen_on",
        "custom_voice_id",
        "custom_voice_name",
        "voice_recordings",
        "custom_phrases",
        "blocked_voice_ids",
        "reminders_enabled",
        "nag_interval_minutes",
        "event_reminder_minutes",
        "daily_checkins_enabled",
        "daily_checkin_times_v2",
        "focus_checkin_minutes",
        "focus_grace_period_minutes",
        "time_away_threshold_minutes",
        "focus_time_away_threshold_minutes",
        "idle_threshold_minutes",
        "morning_briefing_enabled",
        "user_task_messages",
        "user_nag_messages",
        "user_focus_messages",
        "focus_session_active",
        "focus_session_interval",
        "focus_session_task_count",
        "break_mode_enabled",
        "break_mode_end_time",
        "reward_breaks_enabled",
        "reward_break_duration",
        "auto_suggest_breaks",
        "morning_checklist_enabled",
        "morning_checklist_time",
        "morning_checklist_on_open",
        "morning_checklist_last_shown",
        "morning_checklist_progress",
        "morning_checklist_progress_date",
        "morning_self_checks",
        "midday_check_enabled",
        "midday_check_time",
        "midday_check_last_shown",
        "morning_routine_completed_today",
        "calendar_review_last_shown",
        "tasks_review_last_shown",
        "checkout_checklists",
        "checkout_progress",
        "checkout_progress_date",
        "energy_level",
        "energy_last_checkin",
        "energy_checkin_history",
        "energy_midday_checkin",
        "momentum_score",
        "momentum_last_active_date",
        "momentum_today_completed",
        "momentum_today_date",
        "momentum_rest_day",
        "saved_locations",
        "medication_window_enabled",
        "medication_window_start",
        "medication_window_config",
        "medication_window_history",
        "parsed_items",
        "current_team",
        "my_points",
        "goals_storage",
        "task_attack_attempts",
        "timesheet_entries",
        "gadfly_session_state",
        "smart_scheduler_history",
        "smart_scheduler_patterns",
        "body_doubling_history",
        "duration_history",
        "notification_history",
        "optimal_windows",
        "quiet_periods",
        "recently_spoken_config",
        "nag_contacts",
        "nagging_level_config",
        "self_care_config",
        "self_check_config",
        "hyperfocus_config",
        "celebration_sounds_enabled",
        "celebration_haptics_enabled",
        "celebration_animations_enabled",
        "vault_secret_names",
        "feature_work",
        "feature_school",
        "feature_health",
        "feature_home",
        "feature_creative",
        "feature_social",
        "gadfly_preset_mode",
        "day_structure_has_completed_setup",
        "custom_dictionary_words",
        "has_prompted_afternoon_checkin",
        "morning_checklist_saved_index",
        "morning_checklist_saved_date"
    ]
    
    // MARK: - Backup
    
    func createBackup() -> URL? {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let dbPath = documentsPath.appendingPathComponent("gadfly_backup_\(timestamp).db")
        
        try? fileManager.removeItem(at: dbPath)
        
        var db: OpaquePointer?
        
        guard sqlite3_open(dbPath.path, &db) == SQLITE_OK else {
            print("BackupService: Failed to open database")
            return nil
        }
        
        defer { sqlite3_close(db) }
        
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS user_defaults (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key TEXT NOT NULL UNIQUE,
                value_type TEXT NOT NULL,
                value_string TEXT,
                value_int INTEGER,
                value_double REAL,
                value_bool INTEGER,
                value_data BLOB,
                value_date REAL,
                created_at REAL NOT NULL
            );
        """
        
        guard sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK else {
            print("BackupService: Failed to create table")
            return nil
        }
        
        let defaults = UserDefaults.standard
        let currentTime = Date().timeIntervalSince1970
        
        for key in allKeys {
            guard let value = defaults.object(forKey: key) else { continue }
            
            let insertSQL: String
            var stmt: OpaquePointer?
            
            switch value {
            case let stringValue as String:
                insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_string, created_at) VALUES (?, 'string', ?, ?)"
                sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, key, -1, nil)
                sqlite3_bind_text(stmt, 2, stringValue, -1, nil)
                sqlite3_bind_double(stmt, 3, currentTime)
                
            case let intValue as Int:
                insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_int, created_at) VALUES (?, 'int', ?, ?)"
                sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, key, -1, nil)
                sqlite3_bind_int64(stmt, 2, Int64(intValue))
                sqlite3_bind_double(stmt, 3, currentTime)
                
            case let doubleValue as Double:
                insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_double, created_at) VALUES (?, 'double', ?, ?)"
                sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, key, -1, nil)
                sqlite3_bind_double(stmt, 2, doubleValue)
                sqlite3_bind_double(stmt, 3, currentTime)
                
            case let boolValue as Bool:
                insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_bool, created_at) VALUES (?, 'bool', ?, ?)"
                sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, key, -1, nil)
                sqlite3_bind_int(stmt, 2, boolValue ? 1 : 0)
                sqlite3_bind_double(stmt, 3, currentTime)
                
            case let dateValue as Date:
                insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_date, created_at) VALUES (?, 'date', ?, ?)"
                sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, key, -1, nil)
                sqlite3_bind_double(stmt, 2, dateValue.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 3, currentTime)
                
            case let dataValue as Data:
                insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_data, created_at) VALUES (?, 'data', ?, ?)"
                sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                sqlite3_bind_text(stmt, 1, key, -1, nil)
                bindBlob(stmt: stmt, index: 2, data: dataValue)
                sqlite3_bind_double(stmt, 3, currentTime)
                
            case let arrayValue as [Any]:
                if let jsonData = try? JSONSerialization.data(withJSONObject: arrayValue) {
                    insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_data, created_at) VALUES (?, 'array', ?, ?)"
                    sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                    sqlite3_bind_text(stmt, 1, key, -1, nil)
                    bindBlob(stmt: stmt, index: 2, data: jsonData)
                    sqlite3_bind_double(stmt, 3, currentTime)
                } else {
                    continue
                }
                
            case let dictValue as [String: Any]:
                if let jsonData = try? JSONSerialization.data(withJSONObject: dictValue) {
                    insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_data, created_at) VALUES (?, 'dictionary', ?, ?)"
                    sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                    sqlite3_bind_text(stmt, 1, key, -1, nil)
                    bindBlob(stmt: stmt, index: 2, data: jsonData)
                    sqlite3_bind_double(stmt, 3, currentTime)
                } else {
                    continue
                }
                
            default:
                if let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false) {
                    insertSQL = "INSERT OR REPLACE INTO user_defaults (key, value_type, value_data, created_at) VALUES (?, 'archived', ?, ?)"
                    sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil)
                    sqlite3_bind_text(stmt, 1, key, -1, nil)
                    bindBlob(stmt: stmt, index: 2, data: archivedData)
                    sqlite3_bind_double(stmt, 3, currentTime)
                } else {
                    continue
                }
            }
            
            if sqlite3_step(stmt) != SQLITE_DONE {
                print("BackupService: Failed to insert key: \(key)")
            }
            sqlite3_finalize(stmt)
        }
        
        print("BackupService: Backup created at \(dbPath.path)")
        return dbPath
    }
    
    private func bindBlob(stmt: OpaquePointer?, index: Int32, data: Data) {
        _ = data.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, index, ptr.baseAddress, Int32(data.count), nil)
        }
    }
    
    // MARK: - Restore
    
    func restoreBackup(from url: URL) -> Bool {
        var db: OpaquePointer?
        
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            print("BackupService: Failed to open database for restore")
            return false
        }
        
        defer { sqlite3_close(db) }
        
        let selectSQL = "SELECT key, value_type, value_string, value_int, value_double, value_bool, value_data, value_date FROM user_defaults"
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, selectSQL, -1, &stmt, nil) == SQLITE_OK else {
            print("BackupService: Failed to prepare select statement")
            return false
        }
        
        defer { sqlite3_finalize(stmt) }
        
        let defaults = UserDefaults.standard
        var restoredCount = 0
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let keyCString = sqlite3_column_text(stmt, 0),
                  let typeCString = sqlite3_column_text(stmt, 1) else { continue }
            
            let key = String(cString: keyCString)
            let valueType = String(cString: typeCString)
            
            switch valueType {
            case "string":
                if let valueCString = sqlite3_column_text(stmt, 2) {
                    defaults.set(String(cString: valueCString), forKey: key)
                    restoredCount += 1
                }
                
            case "int":
                let value = sqlite3_column_int64(stmt, 3)
                defaults.set(Int(value), forKey: key)
                restoredCount += 1
                
            case "double":
                let value = sqlite3_column_double(stmt, 4)
                defaults.set(value, forKey: key)
                restoredCount += 1
                
            case "bool":
                let value = sqlite3_column_int(stmt, 5)
                defaults.set(value != 0, forKey: key)
                restoredCount += 1
                
            case "date":
                let timestamp = sqlite3_column_double(stmt, 7)
                defaults.set(Date(timeIntervalSince1970: timestamp), forKey: key)
                restoredCount += 1
                
            case "data":
                if let blob = sqlite3_column_blob(stmt, 6) {
                    let length = Int(sqlite3_column_bytes(stmt, 6))
                    let data = Data(bytes: blob, count: length)
                    defaults.set(data, forKey: key)
                    restoredCount += 1
                }
                
            case "array":
                if let blob = sqlite3_column_blob(stmt, 6) {
                    let length = Int(sqlite3_column_bytes(stmt, 6))
                    let data = Data(bytes: blob, count: length)
                    if let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                        defaults.set(array, forKey: key)
                        restoredCount += 1
                    }
                }
                
            case "dictionary":
                if let blob = sqlite3_column_blob(stmt, 6) {
                    let length = Int(sqlite3_column_bytes(stmt, 6))
                    let data = Data(bytes: blob, count: length)
                    if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        defaults.set(dict, forKey: key)
                        restoredCount += 1
                    }
                }
                
            case "archived":
                if let blob = sqlite3_column_blob(stmt, 6) {
                    let length = Int(sqlite3_column_bytes(stmt, 6))
                    let data = Data(bytes: blob, count: length)
                    if let value = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSDictionary.self, NSString.self, NSNumber.self, NSDate.self, NSData.self], from: data) {
                        defaults.set(value, forKey: key)
                        restoredCount += 1
                    }
                }
                
            default:
                print("BackupService: Unknown value type: \(valueType) for key: \(key)")
            }
        }
        
        defaults.synchronize()
        print("BackupService: Restored \(restoredCount) values from backup")
        return true
    }
    
    // MARK: - List
    
    func listBackups() -> [URL] {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
            return files
                .filter { $0.pathExtension == "db" && $0.lastPathComponent.hasPrefix("gadfly_backup_") }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("BackupService: Failed to list backups: \(error)")
            return []
        }
    }
    
    // MARK: - Delete
    
    func deleteBackup(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("BackupService: Failed to delete backup: \(error)")
            return false
        }
    }
    
    // MARK: - Share
    
    func getLatestBackupForSharing() -> URL? {
        return listBackups().first
    }
}
