import Foundation
import SwiftUI

class MarkdownParser: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let codeBlockPattern = "```(?:\\w+)?\\n([\\s\\S]*?)```"
    private let inlineCodePattern = "`([^`]+)`"
    private let boldPattern = "\\*\\*([^*]+)\\*\\*"
    private let italicPattern = "\\*([^*]+)\\*"
    private let underlinePattern = "__([^_]+)__"
    private let strikethroughPattern = "~~([^~]+)~~"
    private let linkPattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
    private let imagePattern = "!\\[([^\\]]*)\\]\\(([^)]+)\\)"
    private let headerPattern = "^(#{1,6})\\s+(.+)$"
    private let listPattern = "^[\\s]*[-*+]\\s+(.+)$"
    private let numberedListPattern = "^[\\s]*\\d+\\.\\s+(.+)$"
    private let quotePattern = "^[\\s]*>\\s+(.+)$"
    private let horizontalRulePattern = "^[\\s]*[-*_]{3,}[\\s]*$"
    
    // MARK: - Parsing Methods
    func parse(_ markdown: String) -> AttributedString {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        var processed = markdown
        // Process code blocks first (to avoid conflicts with inline formatting)
        processed = processCodeBlocks(processed)
        // Process headers
        processed = processHeaders(processed)
        // Process inline formatting
        processed = processInlineFormatting(processed)
        // Process links and images
        processed = processLinks(processed)
        processed = processImages(processed)
        // Process lists
        processed = processLists(processed)
        // Process quotes
        processed = processQuotes(processed)
        // Process horizontal rules
        processed = processHorizontalRules(processed)
        return AttributedString(processed)
    }
    
    // MARK: - Code Block Processing
    private func processCodeBlocks(_ text: String) -> String {
        var result = text
        do {
            let regex = try NSRegularExpression(pattern: codeBlockPattern, options: [.anchorsMatchLines])
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                guard let stringRange = Range(match.range, in: result) else { continue }
                let matchString = String(result[stringRange])
                // Extract language and code content
                let lines = matchString.components(separatedBy: CharacterSet.newlines)
                guard lines.count >= 3 else { continue }
                let language = lines[0].replacingOccurrences(of: "```", with: "").trimmingCharacters(in: CharacterSet.whitespaces)
                let codeContent = lines.dropFirst().dropLast().joined(separator: "\n")
                // Create formatted code block
                let formattedCode = createCodeBlock(codeContent, language: language)
                result.replaceSubrange(stringRange, with: formattedCode)
            }
        } catch {
            print("Error processing code blocks: \(error)")
        }
        return result
    }
    
    private func createCodeBlock(_ code: String, language: String) -> String {
        let languageDisplay = language.isEmpty ? "" : " (\(language))"
        return """
        
        ┌─ Code Block\(languageDisplay) ──────────────────────────────────────────
        \(code)
        └─────────────────────────────────────────────────────────────────────────
        
        """
    }
    
    // MARK: - Header Processing
    private func processHeaders(_ text: String) -> String {
        var result = text
        do {
            let regex = try NSRegularExpression(pattern: headerPattern, options: [.anchorsMatchLines])
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                guard let stringRange = Range(match.range, in: result) else { continue }
                let matchString = String(result[stringRange])
                let components = matchString.components(separatedBy: " ")
                guard components.count >= 2 else { continue }
                let level = components[0].count
                let title = components.dropFirst().joined(separator: " ")
                let formattedHeader = createHeader(title, level: level)
                result.replaceSubrange(stringRange, with: formattedHeader)
            }
        } catch {
            print("Error processing headers: \(error)")
        }
        return result
    }
    
    private func createHeader(_ title: String, level: Int) -> String {
        let prefix = String(repeating: "#", count: level)
        let underline = String(repeating: level == 1 ? "=" : "-", count: title.count)
        return "\n\(prefix) \(title)\n\(underline)\n"
    }
    
    // MARK: - Inline Formatting Processing
    private func processInlineFormatting(_ text: String) -> String {
        var result = text
        // Process bold
        result = processPattern(result, pattern: boldPattern) { match in
            return "**\(match)**"
        }
        // Process italic
        result = processPattern(result, pattern: italicPattern) { match in
            return "*\(match)*"
        }
        // Process underline
        result = processPattern(result, pattern: underlinePattern) { match in
            return "__\(match)__"
        }
        // Process strikethrough
        result = processPattern(result, pattern: strikethroughPattern) { match in
            return "~~\(match)~~"
        }
        // Process inline code
        result = processPattern(result, pattern: inlineCodePattern) { match in
            return "`\(match)`"
        }
        return result
    }
    
    private func processPattern(_ text: String, pattern: String, formatter: (String) -> String) -> String {
        var result = text
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                guard let stringRange = Range(match.range, in: result) else { continue }
                let matchString = String(result[stringRange])
                let formatted = formatter(matchString)
                result.replaceSubrange(stringRange, with: formatted)
            }
        } catch {
            print("Error processing pattern \(pattern): \(error)")
        }
        return result
    }
    
    // MARK: - Link Processing
    private func processLinks(_ text: String) -> String {
        var result = text
        do {
            let regex = try NSRegularExpression(pattern: linkPattern)
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                guard let stringRange = Range(match.range, in: result) else { continue }
                let matchString = String(result[stringRange])
                // Extract text and URL
                let linkRegex = try NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)")
                if let linkMatch = linkRegex.firstMatch(in: matchString, range: NSRange(location: 0, length: matchString.utf16.count)) {
                    let textRange = Range(linkMatch.range(at: 1), in: matchString)
                    let urlRange = Range(linkMatch.range(at: 2), in: matchString)
                    if let textRange = textRange, let urlRange = urlRange {
                        let linkText = String(matchString[textRange])
                        let url = String(matchString[urlRange])
                        let formattedLink = "🔗 \(linkText) (\(url))"
                        result.replaceSubrange(stringRange, with: formattedLink)
                    }
                }
            }
        } catch {
            print("Error processing links: \(error)")
        }
        return result
    }
    
    // MARK: - Image Processing
    private func processImages(_ text: String) -> String {
        var result = text
        do {
            let regex = try NSRegularExpression(pattern: imagePattern)
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, range: range)
            for match in matches.reversed() {
                guard let stringRange = Range(match.range, in: result) else { continue }
                let matchString = String(result[stringRange])
                // Extract alt text and URL
                let imageRegex = try NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)")
                if let imageMatch = imageRegex.firstMatch(in: matchString, range: NSRange(location: 0, length: matchString.utf16.count)) {
                    let altRange = Range(imageMatch.range(at: 1), in: matchString)
                    let urlRange = Range(imageMatch.range(at: 2), in: matchString)
                    if let altRange = altRange, let urlRange = urlRange {
                        let altText = String(matchString[altRange])
                        let url = String(matchString[urlRange])
                        let displayText = altText.isEmpty ? "Image" : altText
                        let formattedImage = "🖼️ \(displayText) (\(url))"
                        result.replaceSubrange(stringRange, with: formattedImage)
                    }
                }
            }
        } catch {
            print("Error processing images: \(error)")
        }
        return result
    }
    
    // MARK: - List Processing
    private func processLists(_ text: String) -> String {
        var result = text
        
        // Process bullet lists
        result = processPattern(result, pattern: listPattern) { match in
            return "• \(match)"
        }
        
        // Process numbered lists
        result = processPattern(result, pattern: numberedListPattern) { match in
            return "1. \(match)"
        }
        
        return result
    }
    
    // MARK: - Quote Processing
    private func processQuotes(_ text: String) -> String {
        var result = text
        
        result = processPattern(result, pattern: quotePattern) { match in
            return "💬 \(match)"
        }
        
        return result
    }
    
    // MARK: - Horizontal Rule Processing
    private func processHorizontalRules(_ text: String) -> String {
        var result = text
        
        result = processPattern(result, pattern: horizontalRulePattern) { _ in
            return "────────────────────────────────────────────────────────────────"
        }
        
        return result
    }
    
    // MARK: - Utility Methods
    func stripMarkdown(_ markdown: String) -> String {
        var text = markdown
        
        // Remove code blocks
        text = text.replacingOccurrences(of: codeBlockPattern, with: "", options: .regularExpression)
        
        // Remove inline code
        text = text.replacingOccurrences(of: inlineCodePattern, with: "$1", options: .regularExpression)
        
        // Remove bold/italic
        text = text.replacingOccurrences(of: boldPattern, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: italicPattern, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: underlinePattern, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: strikethroughPattern, with: "$1", options: .regularExpression)
        
        // Remove links (keep text)
        text = text.replacingOccurrences(of: linkPattern, with: "$1", options: .regularExpression)
        
        // Remove images (keep alt text)
        text = text.replacingOccurrences(of: imagePattern, with: "$1", options: .regularExpression)
        
        // Remove headers
        text = text.replacingOccurrences(of: headerPattern, with: "$2", options: [.regularExpression])
        
        // Remove list markers
        text = text.replacingOccurrences(of: listPattern, with: "$1", options: [.regularExpression])
        text = text.replacingOccurrences(of: numberedListPattern, with: "$1", options: [.regularExpression])
        
        // Remove quotes
        text = text.replacingOccurrences(of: quotePattern, with: "$1", options: [.regularExpression])
        
        // Remove horizontal rules
        text = text.replacingOccurrences(of: horizontalRulePattern, with: "", options: [.regularExpression])
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func extractCodeBlocks(_ markdown: String) -> [CodeBlock] {
        var codeBlocks: [CodeBlock] = []
        
        do {
            let regex = try NSRegularExpression(pattern: codeBlockPattern, options: [.anchorsMatchLines])
            let range = NSRange(location: 0, length: markdown.utf16.count)
            let matches = regex.matches(in: markdown, range: range)
            
            for match in matches {
                guard let range = Range(match.range, in: markdown) else { continue }
                let matchString = String(markdown[range])
                
                let lines = matchString.components(separatedBy: .newlines)
                guard lines.count >= 3 else { continue }
                
                let language = lines[0].replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespaces)
                let codeContent = lines.dropFirst().dropLast().joined(separator: "\n")
                
                codeBlocks.append(CodeBlock(language: language, content: codeContent))
            }
        } catch {
            print("Error extracting code blocks: \(error)")
        }
        
        return codeBlocks
    }
    
    func extractLinks(_ markdown: String) -> [MarkdownLink] {
        var links: [MarkdownLink] = []
        
        do {
            let regex = try NSRegularExpression(pattern: linkPattern)
            let range = NSRange(location: 0, length: markdown.utf16.count)
            let matches = regex.matches(in: markdown, range: range)
            
            for match in matches {
                guard let textRange = Range(match.range(at: 1), in: markdown),
                      let urlRange = Range(match.range(at: 2), in: markdown) else { continue }
                
                let text = String(markdown[textRange])
                let url = String(markdown[urlRange])
                
                links.append(MarkdownLink(text: text, url: url))
            }
        } catch {
            print("Error extracting links: \(error)")
        }
        
        return links
    }
    
    // MARK: - Error Handling
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Data Models
struct CodeBlock {
    let language: String
    let content: String
    
    var displayLanguage: String {
        return language.isEmpty ? "text" : language
    }
    
    var isCode: Bool {
        return !language.isEmpty && language != "text"
    }
}

struct MarkdownLink {
    let text: String
    let url: String
    
    var isValidURL: Bool {
        return URL(string: url) != nil
    }
}

// MARK: - Preview Helper
extension MarkdownParser {
    static var preview: MarkdownParser {
        return MarkdownParser()
    }
} 
