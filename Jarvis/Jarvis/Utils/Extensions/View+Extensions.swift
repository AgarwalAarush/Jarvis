import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

extension View {
    // MARK: - Conditional Modifiers
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
    
    // MARK: - Frame Modifiers
    func frame(size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
    
    func frame(square: CGFloat) -> some View {
        frame(width: square, height: square)
    }
    
    func maxFrame(maxWidth: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View {
        return self.frame(maxWidth: maxWidth, maxHeight: maxHeight)
    }
    
    func minFrame(minWidth: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        return self.frame(minWidth: minWidth, minHeight: minHeight)
    }
    
    // MARK: - Padding Modifiers
    func paddingAll(_ length: CGFloat) -> some View {
        return self.padding(.all, length)
    }
    
    func paddingHorizontal(_ length: CGFloat) -> some View {
        return self.padding(.horizontal, length)
    }
    
    func paddingVertical(_ length: CGFloat) -> some View {
        return self.padding(.vertical, length)
    }
    
    func paddingLeading(_ length: CGFloat) -> some View {
        return self.padding(.leading, length)
    }
    
    func paddingTrailing(_ length: CGFloat) -> some View {
        return self.padding(.trailing, length)
    }
    
    func paddingTop(_ length: CGFloat) -> some View {
        return self.padding(.top, length)
    }
    
    func paddingBottom(_ length: CGFloat) -> some View {
        return self.padding(.bottom, length)
    }
    
    // MARK: - Background Modifiers
    func backgroundGradient(_ colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> some View {
        background(
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
        )
    }
    
    func backgroundRadialGradient(_ colors: [Color], center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat = 1) -> some View {
        background(
            RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
        )
    }
    
    // MARK: - Border Modifiers
    func border(_ color: Color, width: CGFloat = 1, cornerRadius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
    }
    
    func borderGradient(_ colors: [Color], width: CGFloat = 1, cornerRadius: CGFloat = 0) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: width
                )
        )
    }
    
    // MARK: - Shadow Modifiers
    func shadowDefaultColor(radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        shadow(color: .black.opacity(0.1), radius: radius, x: x, y: y)
    }
    
    // MARK: - Custom Modifiers
    func cardStyle(backgroundColor: Color = .white, cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 8) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadowDefaultColor(radius: shadowRadius)
    }
    
    func glassEffect(blurRadius: CGFloat = 10, opacity: Double = 0.1) -> some View {
        self
            .background(.ultraThinMaterial)
            .blur(radius: blurRadius)
            .opacity(opacity)
    }
    
    func gradientBorder(colors: [Color], lineWidth: CGFloat = 2) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: lineWidth
                )
        )
    }
    
    func pulseAnimation(duration: Double = 1.0, scale: CGFloat = 1.1) -> some View {
        self.scaleEffect(1.0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: UUID()
            )
    }
    
    func shakeAnimation(duration: Double = 0.5, intensity: CGFloat = 10) -> some View {
        self.offset(x: 0)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatCount(3, autoreverses: true),
                value: UUID()
            )
    }
    
    func fadeInAnimation(duration: Double = 0.5) -> some View {
        self.opacity(0)
            .animation(.easeIn(duration: duration), value: UUID())
    }
    
    func slideInAnimation(duration: Double = 0.5, from edge: Edge = .trailing) -> some View {
        #if canImport(AppKit)
        let screenWidth = NSScreen.main?.frame.width ?? 1000
        #else
        let screenWidth: CGFloat = 1000
        #endif
        
        return self.offset(x: edge == .leading ? -screenWidth : screenWidth)
            .animation(.easeInOut(duration: duration), value: UUID())
    }
}

// MARK: - Custom Transitions
extension AnyTransition {
    static var slideUp: AnyTransition {
        AnyTransition.move(edge: .bottom).combined(with: .opacity)
    }
    
    static var slideDown: AnyTransition {
        AnyTransition.move(edge: .top).combined(with: .opacity)
    }
    
    static var slideLeft: AnyTransition {
        AnyTransition.move(edge: .trailing).combined(with: .opacity)
    }
    
    static var slideRight: AnyTransition {
        AnyTransition.move(edge: .leading).combined(with: .opacity)
    }
    
    static var scale: AnyTransition {
        AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    }
    
    static var flip: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.2).combined(with: .opacity)
        )
    }
}

// MARK: - Custom Animations
extension Animation {
    static var springBouncy: Animation {
        Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
    }
    
    static var springSmooth: Animation {
        Animation.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0)
    }
    
    static var easeInOutSlow: Animation {
        Animation.easeInOut(duration: 0.8)
    }
    
    static var easeInOutFast: Animation {
        Animation.easeInOut(duration: 0.2)
    }
}