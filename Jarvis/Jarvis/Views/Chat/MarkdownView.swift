import SwiftUI

struct MarkdownView: View {
    let content: String
    
    var body: some View {
        Text(.init(content))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
