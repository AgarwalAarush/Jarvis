import Foundation
import CoreData
import SwiftUI

class ExportService: ObservableObject {
    // MARK: - Published Properties
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    private let coreDataService: CoreDataService
    
    // MARK: - Initialization
    init(coreDataService: CoreDataService) {
        self.coreDataService = coreDataService
    }
    
    // MARK: - Export Operations
    func exportChat(_ chat: Chat, format: ExportFormatService = .json) async -> URL? {
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil
        successMessage = nil
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        guard let chatExport = coreDataService.exportChat(chat) else {
            errorMessage = "Failed to prepare chat for export"
            return nil
        }
        
        exportProgress = 0.3
        
        do {
            let exportURL = try await performExport(chatExport, format: format)
            exportProgress = 1.0
            
            successMessage = "Chat exported successfully"
            
            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.successMessage = nil
            }
            
            return exportURL
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    func exportAllChats(format: ExportFormatService = .json) async -> URL? {
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil
        successMessage = nil
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        let chatExports = coreDataService.exportAllChats()
        
        guard !chatExports.isEmpty else {
            errorMessage = "No chats to export"
            return nil
        }
        
        exportProgress = 0.2
        
        do {
            let exportURL = try await performBulkExport(chatExports, format: format)
            exportProgress = 1.0
            
            successMessage = "Exported \(chatExports.count) chats successfully"
            
            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.successMessage = nil
            }
            
            return exportURL
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    func exportSelectedChats(_ chats: [Chat], format: ExportFormatService = .json) async -> URL? {
        isExporting = true
        exportProgress = 0.0
        errorMessage = nil
        successMessage = nil
        
        defer {
            isExporting = false
            exportProgress = 0.0
        }
        
        guard !chats.isEmpty else {
            errorMessage = "No chats selected for export"
            return nil
        }
        
        let chatExports = chats.compactMap { coreDataService.exportChat($0) }
        
        guard !chatExports.isEmpty else {
            errorMessage = "Failed to prepare chats for export"
            return nil
        }
        
        exportProgress = 0.2
        
        do {
            let exportURL = try await performBulkExport(chatExports, format: format)
            exportProgress = 1.0
            
            successMessage = "Exported \(chatExports.count) chats successfully"
            
            // Clear success message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.successMessage = nil
            }
            
            return exportURL
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Private Export Methods
    private func performExport(_ chatExport: ChatExport, format: ExportFormatService) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "jarvis_chat_\(chatExport.title.replacingOccurrences(of: " ", with: "_"))_\(timestamp)"
        
        switch format {
        case .json:
            return try await exportToJSON(chatExport, filename: filename, documentsPath: documentsPath)
        case .markdown:
            return try await exportToMarkdown(chatExport, filename: filename, documentsPath: documentsPath)
        case .txt:
            return try await exportToText(chatExport, filename: filename, documentsPath: documentsPath)
        case .csv:
            return try await exportToCSV(chatExport, filename: filename, documentsPath: documentsPath)
        }
    }
    
    private func performBulkExport(_ chatExports: [ChatExport], format: ExportFormatService) async throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "jarvis_chats_\(timestamp)"
        
        switch format {
        case .json:
            return try await exportBulkToJSON(chatExports, filename: filename, documentsPath: documentsPath)
        case .markdown:
            return try await exportBulkToMarkdown(chatExports, filename: filename, documentsPath: documentsPath)
        case .txt:
            return try await exportBulkToText(chatExports, filename: filename, documentsPath: documentsPath)
        case .csv:
            return try await exportBulkToCSV(chatExports, filename: filename, documentsPath: documentsPath)
        }
    }
    
    // MARK: - JSON Export
    private func exportToJSON(_ chatExport: ChatExport, filename: String, documentsPath: URL) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(chatExport)
        let fileURL = documentsPath.appendingPathComponent("\(filename).json")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    private func exportBulkToJSON(_ chatExports: [ChatExport], filename: String, documentsPath: URL) async throws -> URL {
        let bulkExport = BulkChatExport(
            chats: chatExports,
            exportDate: Date(),
            totalChats: chatExports.count,
            totalMessages: chatExports.reduce(0) { $0 + $1.messageCount }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(bulkExport)
        let fileURL = documentsPath.appendingPathComponent("\(filename).json")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Markdown Export
    private func exportToMarkdown(_ chatExport: ChatExport, filename: String, documentsPath: URL) async throws -> URL {
        var markdown = "# \(chatExport.title)\n\n"
        markdown += "**Created:** \(formatDate(chatExport.createdAt))\n"
        markdown += "**Last Updated:** \(formatDate(chatExport.updatedAt))\n"
        markdown += "**Messages:** \(chatExport.messageCount)\n\n"
        markdown += "---\n\n"
        
        for message in chatExport.messages {
            let sender = message.isUser ? "**You**" : "**Jarvis**"
            let timestamp = formatTime(message.timestamp)
            
            markdown += "### \(sender) - \(timestamp)\n\n"
            markdown += "\(message.content)\n\n"
        }
        
        let data = markdown.data(using: .utf8)!
        let fileURL = documentsPath.appendingPathComponent("\(filename).md")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    private func exportBulkToMarkdown(_ chatExports: [ChatExport], filename: String, documentsPath: URL) async throws -> URL {
        var markdown = "# Jarvis Chat Export\n\n"
        markdown += "**Export Date:** \(formatDate(Date()))\n"
        markdown += "**Total Chats:** \(chatExports.count)\n"
        markdown += "**Total Messages:** \(chatExports.reduce(0) { $0 + $1.messageCount })\n\n"
        markdown += "---\n\n"
        
        for (index, chatExport) in chatExports.enumerated() {
            markdown += "## \(index + 1). \(chatExport.title)\n\n"
            markdown += "**Created:** \(formatDate(chatExport.createdAt))\n"
            markdown += "**Last Updated:** \(formatDate(chatExport.updatedAt))\n"
            markdown += "**Messages:** \(chatExport.messageCount)\n\n"
            
            for message in chatExport.messages {
                let sender = message.isUser ? "**You**" : "**Jarvis**"
                let timestamp = formatTime(message.timestamp)
                
                markdown += "### \(sender) - \(timestamp)\n\n"
                markdown += "\(message.content)\n\n"
            }
            
            markdown += "---\n\n"
        }
        
        let data = markdown.data(using: .utf8)!
        let fileURL = documentsPath.appendingPathComponent("\(filename).md")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Text Export
    private func exportToText(_ chatExport: ChatExport, filename: String, documentsPath: URL) async throws -> URL {
        var text = "Chat: \(chatExport.title)\n"
        text += "Created: \(formatDate(chatExport.createdAt))\n"
        text += "Last Updated: \(formatDate(chatExport.updatedAt))\n"
        text += "Messages: \(chatExport.messageCount)\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        
        for message in chatExport.messages {
            let sender = message.isUser ? "You" : "Jarvis"
            let timestamp = formatTime(message.timestamp)
            
            text += "[\(timestamp)] \(sender):\n"
            text += "\(message.content)\n\n"
        }
        
        let data = text.data(using: .utf8)!
        let fileURL = documentsPath.appendingPathComponent("\(filename).txt")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    private func exportBulkToText(_ chatExports: [ChatExport], filename: String, documentsPath: URL) async throws -> URL {
        var text = "Jarvis Chat Export\n"
        text += "Export Date: \(formatDate(Date()))\n"
        text += "Total Chats: \(chatExports.count)\n"
        text += "Total Messages: \(chatExports.reduce(0) { $0 + $1.messageCount })\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        
        for (index, chatExport) in chatExports.enumerated() {
            text += "Chat \(index + 1): \(chatExport.title)\n"
            text += "Created: \(formatDate(chatExport.createdAt))\n"
            text += "Last Updated: \(formatDate(chatExport.updatedAt))\n"
            text += "Messages: \(chatExport.messageCount)\n"
            text += String(repeating: "-", count: 30) + "\n\n"
            
            for message in chatExport.messages {
                let sender = message.isUser ? "You" : "Jarvis"
                let timestamp = formatTime(message.timestamp)
                
                text += "[\(timestamp)] \(sender):\n"
                text += "\(message.content)\n\n"
            }
            
            text += String(repeating: "=", count: 50) + "\n\n"
        }
        
        let data = text.data(using: .utf8)!
        let fileURL = documentsPath.appendingPathComponent("\(filename).txt")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - CSV Export
    private func exportToCSV(_ chatExport: ChatExport, filename: String, documentsPath: URL) async throws -> URL {
        var csv = "Chat Title,Message ID,Sender,Timestamp,Content\n"
        
        for message in chatExport.messages {
            let sender = message.isUser ? "User" : "Assistant"
            let timestamp = formatDate(message.timestamp)
            let content = message.content.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(chatExport.title)\",\"\(message.id)\",\"\(sender)\",\"\(timestamp)\",\"\(content)\"\n"
        }
        
        let data = csv.data(using: .utf8)!
        let fileURL = documentsPath.appendingPathComponent("\(filename).csv")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    private func exportBulkToCSV(_ chatExports: [ChatExport], filename: String, documentsPath: URL) async throws -> URL {
        var csv = "Chat Title,Message ID,Sender,Timestamp,Content\n"
        
        for chatExport in chatExports {
            for message in chatExport.messages {
                let sender = message.isUser ? "User" : "Assistant"
                let timestamp = formatDate(message.timestamp)
                let content = message.content.replacingOccurrences(of: "\"", with: "\"\"")
                
                csv += "\"\(chatExport.title)\",\"\(message.id)\",\"\(sender)\",\"\(timestamp)\",\"\(content)\"\n"
            }
        }
        
        let data = csv.data(using: .utf8)!
        let fileURL = documentsPath.appendingPathComponent("\(filename).csv")
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
    
    func clearSuccess() {
        successMessage = nil
    }
}

// MARK: - Data Models
enum ExportFormatService: String, CaseIterable {
    case json = "JSON"
    case markdown = "Markdown"
    case txt = "Text"
    case csv = "CSV"
    
    var fileExtension: String {
        switch self {
        case .json:
            return "json"
        case .markdown:
            return "md"
        case .txt:
            return "txt"
        case .csv:
            return "csv"
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

struct BulkChatExport: Codable {
    let chats: [ChatExport]
    let exportDate: Date
    let totalChats: Int
    let totalMessages: Int
    let version: String = "1.0"
    
    var formattedExportDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: exportDate)
    }
}

// MARK: - Preview Helper
extension ExportService {
    static var preview: ExportService {
        let coreDataService = CoreDataService.preview
        return ExportService(coreDataService: coreDataService)
    }
} 