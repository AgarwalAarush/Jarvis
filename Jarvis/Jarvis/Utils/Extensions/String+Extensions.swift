import Foundation
import SwiftUI

extension String {
    // MARK: - Truncation
    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }
    
    func truncatedToWords(_ wordCount: Int, trailing: String = "...") -> String {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
        if words.count <= wordCount {
            return self
        }
        return words.prefix(wordCount).joined(separator: " ") + trailing
    }
    
    // MARK: - Validation
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #else
        return url.scheme != nil && url.host != nil
        #endif
    }
    
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
    
    var containsOnlyWhitespace: Bool {
        return trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Formatting
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
    
    var titleCase: String {
        return self.components(separatedBy: " ")
            .map { $0.capitalizedFirst }
            .joined(separator: " ")
    }
    
    var camelCase: String {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
        guard let firstWord = words.first else { return self }
        
        let remainingWords = words.dropFirst().map { $0.capitalizedFirst }
        return firstWord.lowercased() + remainingWords.joined()
    }
    
    var snakeCase: String {
        return self.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased() }
            .joined(separator: "_")
    }
    
    var kebabCase: String {
        return self.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.lowercased() }
            .joined(separator: "-")
    }
    
    // MARK: - Search and Matching
    func contains(_ string: String, caseSensitive: Bool = false) -> Bool {
        if caseSensitive {
            return self.contains(string)
        } else {
            return self.localizedCaseInsensitiveContains(string)
        }
    }
    
    func matches(pattern: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex?.firstMatch(in: self, range: range) != nil
    }
    
    func extractMatches(pattern: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = regex?.matches(in: self, range: range) ?? []
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }
    
    // MARK: - Markdown and Text Processing
    var stripMarkdown: String {
        // Remove markdown formatting
        var text = self
        
        // Remove bold/italic
        text = text.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\*(.*?)\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "__(.*?)__", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "_(.*?)_", with: "$1", options: .regularExpression)
        
        // Remove code blocks
        text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "`(.*?)`", with: "$1", options: .regularExpression)
        
        // Remove links
        text = text.replacingOccurrences(of: "\\[(.*?)\\]\\(.*?\\)", with: "$1", options: .regularExpression)
        
        // Remove headers
        text = text.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var extractCodeBlocks: [String] {
        let pattern = "```(?:\\w+)?\\n([\\s\\S]*?)```"
        return extractMatches(pattern: pattern)
    }
    
    var extractLinks: [String] {
        let pattern = "\\[(.*?)\\]\\((.*?)\\)"
        let matches = extractMatches(pattern: pattern)
        return matches.compactMap { match in
            let components = match.components(separatedBy: "](")
            return components.last?.replacingOccurrences(of: ")", with: "")
        }
    }
    
    // MARK: - File and Path Utilities
    var fileExtension: String {
        return (self as NSString).pathExtension
    }
    
    var fileName: String {
        return (self as NSString).lastPathComponent
    }
    
    var fileNameWithoutExtension: String {
        return (self as NSString).deletingPathExtension
    }
    
    var directoryPath: String {
        return (self as NSString).deletingLastPathComponent
    }
    
    var isAbsolutePath: Bool {
        return (self as NSString).isAbsolutePath
    }
    
    // MARK: - Encoding and Decoding
    var urlEncoded: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
    
    var urlDecoded: String {
        return self.removingPercentEncoding ?? self
    }
    
    var base64Encoded: String {
        return Data(self.utf8).base64EncodedString()
    }
    
    var base64Decoded: String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Hash and Checksum
    @available(*, deprecated, message: "MD5 is cryptographically broken and should not be used for security purposes. Use SHA256 instead.")
    var md5Hash: String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    var sha256Hash: String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // MARK: - Time and Date Parsing
    var asDate: Date? {
        let formatters: [DateFormatter] = [
            createDateFormatter("yyyy-MM-dd HH:mm:ss"),
            createDateFormatter("yyyy-MM-dd"),
            createDateFormatter("MM/dd/yyyy"),
            createDateFormatter("dd/MM/yyyy"),
            createDateFormatter("yyyy-MM-dd'T'HH:mm:ssZ"),
            createDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: self) {
                return date
            }
        }
        
        return nil
    }
    
    private func createDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter
    }
    
    // MARK: - Number Parsing
    var asInt: Int? {
        return Int(self)
    }
    
    var asDouble: Double? {
        return Double(self)
    }
    
    var asFloat: Float? {
        return Float(self)
    }
    
    var asBool: Bool? {
        let lowercased = self.lowercased()
        switch lowercased {
        case "true", "yes", "1", "on":
            return true
        case "false", "no", "0", "off":
            return false
        default:
            return nil
        }
    }
    
    // MARK: - Character and Word Counting
    var wordCount: Int {
        let words = self.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    var characterCount: Int {
        return self.count
    }
    
    var characterCountWithoutSpaces: Int {
        return self.replacingOccurrences(of: " ", with: "").count
    }
    
    var lineCount: Int {
        return self.components(separatedBy: .newlines).count
    }
    
    // MARK: - Text Analysis
    var averageWordLength: Double {
        let words = self.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !words.isEmpty else { return 0.0 }
        
        let totalLength = words.reduce(0) { $0 + $1.count }
        return Double(totalLength) / Double(words.count)
    }
    
    var readingTime: TimeInterval {
        let wordsPerMinute: Double = 200 // Average reading speed
        let words = Double(self.wordCount)
        return (words / wordsPerMinute) * 60
    }
    
    var speakingTime: TimeInterval {
        let wordsPerMinute: Double = 150 // Average speaking speed
        let words = Double(self.wordCount)
        return (words / wordsPerMinute) * 60
    }
    
    // MARK: - Text Cleaning
    var cleaned: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var removeExtraWhitespace: String {
        let components = self.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    var removeSpecialCharacters: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
    }
    
    var removeNumbers: String {
        return self.components(separatedBy: CharacterSet.decimalDigits)
            .joined()
    }
    
    var removeLetters: String {
        return self.components(separatedBy: CharacterSet.letters)
            .joined()
    }
    
    // MARK: - Text Generation
    static func random(length: Int, characters: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") -> String {
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    static func randomWord() -> String {
        let words = ["hello", "world", "swift", "programming", "macos", "development", "computer", "technology", "innovation", "future"]
        return words.randomElement() ?? "word"
    }
    
    static func randomSentence(wordCount: Int = 5) -> String {
        let words = (0..<wordCount).map { _ in randomWord() }
        return words.joined(separator: " ").capitalizedFirst + "."
    }
    
    // MARK: - Localization
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
    
    // MARK: - Comparison
    func similarity(to other: String) -> Double {
        let longer = self.count > other.count ? self : other
        
        if longer.count == 0 {
            return 1.0
        }
        
        let distance = levenshteinDistance(to: other)
        return Double(longer.count - distance) / Double(longer.count)
    }
    
    private func levenshteinDistance(to other: String) -> Int {
        let empty = Array(repeating: 0, count: other.count + 1)
        var last = Array(0...other.count)
        
        for (i, char1) in self.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in other.enumerated() {
                current[j + 1] = char1 == char2 ? last[j] : Swift.min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        return last[other.count]
    }
}

// MARK: - Attributed String Extensions
extension String {
    func attributed(with attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        return NSAttributedString(string: self, attributes: attributes)
    }
    
    func attributedBold() -> NSAttributedString {
        return self.attributed(with: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)])
    }
    
    func attributedItalic() -> NSAttributedString {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        return self.attributed(with: [.font: italicFont])
    }
    
    func attributedColored(_ color: NSColor) -> NSAttributedString {
        return self.attributed(with: [.foregroundColor: color])
    }
    
    func attributedLink(_ url: URL) -> NSAttributedString {
        return self.attributed(with: [.link: url])
    }
}

// MARK: - Regular Expression Extensions
extension String {
    func replacingMatches(of pattern: String, with template: String) -> String {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex?.stringByReplacingMatches(in: self, range: range, withTemplate: template) ?? self
    }
    
    func replacingMatches(of pattern: String, using transform: (String) -> String) -> String {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: self.utf16.count)
        let matches = regex?.matches(in: self, range: range) ?? []
        
        var result = self
        for match in matches.reversed() {
            guard let range = Range(match.range, in: self) else { continue }
            let matchString = String(self[range])
            let replacement = transform(matchString)
            result = result.replacingOccurrences(of: matchString, with: replacement)
        }
        
        return result
    }
}

// MARK: - CommonCrypto Import
import CommonCrypto 