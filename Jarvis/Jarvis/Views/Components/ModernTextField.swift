import SwiftUI

struct ModernTextField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?
    var onClear: (() -> Void)?
    var leadingIcon: String?
    var showClearButton: Bool = true
    var isMultiline: Bool = false
    var lineLimit: ClosedRange<Int> = 1...1
    
    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Leading icon
            if let leadingIcon = leadingIcon {
                Image(systemName: leadingIcon)
                    .foregroundColor(isFocused ? .accentColor : .secondary)
                    .font(.system(size: 14, weight: .medium))
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            // Text field
            if isMultiline {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .lineLimit(lineLimit)
                    .onSubmit {
                        onSubmit?()
                    }
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .onSubmit {
                        onSubmit?()
                    }
            }
            
            // Clear button
            if showClearButton && !text.isEmpty {
                Button(action: {
                    text = ""
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(isHovered || isFocused ? 1.0 : 0.7)
                .animation(.easeInOut(duration: 0.2), value: isHovered || isFocused)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isMultiline ? 10 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
    
    private var backgroundColor: Color {
        if isFocused {
            return Color(NSColor.controlBackgroundColor)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.8)
        } else {
            return Color(NSColor.controlBackgroundColor).opacity(0.6)
        }
    }
    
    private var borderColor: Color {
        if isFocused {
            return .accentColor
        } else if isHovered {
            return Color.gray.opacity(0.5)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isFocused ? 1.5 : 1.0
    }
}

// MARK: - ModernSearchField
struct ModernSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)?
    var onClear: (() -> Void)?
    
    var body: some View {
        ModernTextField(
            placeholder: placeholder,
            text: $text,
            onSubmit: onSubmit,
            onClear: onClear,
            leadingIcon: "magnifyingglass",
            showClearButton: true
        )
    }
}

// MARK: - ModernMessageField  
struct ModernMessageField: View {
    @Binding var text: String
    var placeholder: String = "Type a message..."
    var onSubmit: (() -> Void)?
    var lineLimit: ClosedRange<Int> = 1...5
    
    var body: some View {
        ModernTextField(
            placeholder: placeholder,
            text: $text,
            onSubmit: onSubmit,
            leadingIcon: nil,
            showClearButton: false,
            isMultiline: true,
            lineLimit: lineLimit
        )
    }
}

// MARK: - ViewModifier for consistent styling
struct ModernTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.primary)
    }
}

extension View {
    func modernTextFieldStyle() -> some View {
        modifier(ModernTextFieldStyle())
    }
}

// MARK: - Preview
struct ModernTextField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ModernSearchField(text: .constant(""), placeholder: "Search conversations...")
            
            ModernTextField(
                placeholder: "Enter text...",
                text: .constant(""),
                leadingIcon: "person"
            )
            
            ModernMessageField(
                text: .constant(""),
                placeholder: "Type a message..."
            )
        }
        .padding()
        .frame(width: 300)
    }
}