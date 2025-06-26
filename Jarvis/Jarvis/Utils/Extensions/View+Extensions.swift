import SwiftUI

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
    func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        return SwiftUI.View.padding(self, edges, length)
    }
    
    func padding(_ length: CGFloat) -> some View {
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
    func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> some View {
        return self.background(background, alignment: alignment)
    }
    
    func background(_ color: Color, alignment: Alignment = .center) -> some View {
        return self.background(color, alignment: alignment)
    }
    
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
    func border(_ color: Color, width: CGFloat = 1) -> some View {
        border(color, width: width)
    }
    
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
    
    // MARK: - Corner Radius Modifiers
    func cornerRadius(_ radius: CGFloat) -> some View {
        return self.cornerRadius(radius)
    }
    
    // MARK: - Shadow Modifiers
    func shadow(color: Color = .black, radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        shadow(color: color, radius: radius, x: x, y: y)
    }
    
    func shadow(radius: CGFloat = 10, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        shadow(color: .black.opacity(0.1), radius: radius, x: x, y: y)
    }
    
    func shadow(color: Color = .black, radius: CGFloat = 10, offset: CGSize = .zero) -> some View {
        shadow(color: color, radius: radius, x: offset.width, y: offset.height)
    }
    
    // MARK: - Opacity and Blur Modifiers
    func opacity(_ opacity: Double) -> some View {
        self.opacity(opacity)
    }
    
    func blur(radius: CGFloat, opaque: Bool = false) -> some View {
        blur(radius: radius, opaque: opaque)
    }
    
    // MARK: - Scale and Rotation Modifiers
    func scaleEffect(_ scale: CGFloat, anchor: UnitPoint = .center) -> some View {
        scaleEffect(scale, anchor: anchor)
    }
    
    func scaleEffect(x: CGFloat = 1.0, y: CGFloat = 1.0, anchor: UnitPoint = .center) -> some View {
        scaleEffect(x: x, y: y, anchor: anchor)
    }
    
    func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        rotationEffect(angle, anchor: anchor)
    }
    
    func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0) -> some View {
        rotation3DEffect(angle, axis: axis, anchor: anchor, anchorZ: anchorZ)
    }
    
    // MARK: - Offset Modifiers
    func offset(_ offset: CGSize) -> some View {
        self.offset(offset)
    }
    
    func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View {
        offset(x: x, y: y)
    }
    
    // MARK: - Animation Modifiers
    func animation(_ animation: Animation?, value: AnyHashable) -> some View {
        self.animation(animation, value: value)
    }
    
    func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self.animation(animation, value: value)
    }
    
    func transition(_ transition: AnyTransition) -> some View {
        self.transition(transition)
    }
    
    // MARK: - Gesture Modifiers
    func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        onTapGesture(count: count, perform: action)
    }
    
    func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, pressing: ((Bool) -> Void)? = nil, perform action: @escaping () -> Void) -> some View {
        onLongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance, pressing: pressing, perform: action)
    }
    
    func onDrag(_ data: @escaping () -> NSItemProvider) -> some View {
        onDrag(data)
    }
    
    func onDrop(of supportedTypes: [UTType], isTargeted: Binding<Bool>?, perform action: @escaping ([NSItemProvider]) -> Bool) -> some View {
        onDrop(of: supportedTypes, isTargeted: isTargeted, perform: action)
    }
    
    // MARK: - Hover Modifiers
    func onHover(perform action: @escaping (Bool) -> Void) -> some View {
        onHover(perform: action)
    }
    
    // MARK: - Focus Modifiers
    func focused<Value>(_ binding: Binding<Value?>, equals value: Value) -> some View where Value: Hashable {
        focused(binding, equals: value)
    }
    
    func focused(_ binding: Binding<Bool>) -> some View {
        focused(binding)
    }
    
    // MARK: - Keyboard Modifiers
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> some View {
        keyboardShortcut(key, modifiers: modifiers)
    }
    
    func keyboardShortcut(_ key: KeyEquivalent, action: KeyEquivalent.Action) -> some View {
        keyboardShortcut(key, action: action)
    }
    
    // MARK: - Context Menu Modifiers
    func contextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View {
        contextMenu(menuItems: menuItems)
    }
    
    func contextMenu<MenuItems: View, Preview: View>(@ViewBuilder menuItems: () -> MenuItems, @ViewBuilder preview: () -> Preview) -> some View {
        contextMenu(menuItems: menuItems, preview: preview)
    }
    
    // MARK: - Toolbar Modifiers
    func toolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        toolbar(content: content)
    }
    
    func toolbar<Content: View>(_ placement: ToolbarItemPlacement, @ViewBuilder content: () -> Content) -> some View {
        toolbar(placement, content: content)
    }
    
    // MARK: - Navigation Modifiers
    func navigationTitle(_ title: String) -> some View {
        navigationTitle(title)
    }
    
    func navigationTitle(_ title: Text) -> some View {
        navigationTitle(title)
    }
    
    func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        navigationBarTitleDisplayMode(displayMode)
    }
    
    func navigationBarHidden(_ hidden: Bool) -> some View {
        navigationBarHidden(hidden)
    }
    
    func navigationBarBackButtonHidden(_ hidden: Bool) -> some View {
        navigationBarBackButtonHidden(hidden)
    }
    
    // MARK: - Sheet and Modal Modifiers
    func sheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
    
    func sheet<Item, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item: Identifiable {
        sheet(item: item, onDismiss: onDismiss, content: content)
    }
    
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
    
    func fullScreenCover<Item, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item: Identifiable {
        fullScreenCover(item: item, onDismiss: onDismiss, content: content)
    }
    
    // MARK: - Alert Modifiers
    func alert<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        alert(title, isPresented: isPresented, actions: actions, message: message)
    }
    
    func alert<A: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        alert(title, isPresented: isPresented, actions: actions)
    }
    
    func alert(_ title: Text, isPresented: Binding<Bool>, actions: [Alert.Button] = [.default(Text("OK"))]) -> some View {
        alert(title, isPresented: isPresented, actions: actions)
    }
    
    // MARK: - Action Sheet Modifiers
    func actionSheet<A: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> A) -> some View {
        actionSheet(isPresented: isPresented, content: content)
    }
    
    func actionSheet(isPresented: Binding<Bool>, title: Text? = nil, message: Text? = nil, buttons: [ActionSheet.Button] = [.cancel()]) -> some View {
        actionSheet(isPresented: isPresented, title: title, message: message, buttons: buttons)
    }
    
    // MARK: - Popover Modifiers
    func popover<Content: View>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.rect), arrowEdge: Edge = .top, @ViewBuilder content: @escaping () -> Content) -> some View {
        popover(isPresented: isPresented, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge, content: content)
    }
    
    func popover<Item, Content: View>(item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.rect), arrowEdge: Edge = .top, @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item: Identifiable {
        popover(item: item, attachmentAnchor: attachmentAnchor, arrowEdge: arrowEdge, content: content)
    }
    
    // MARK: - Custom Modifiers
    func cardStyle(backgroundColor: Color = .white, cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 8) -> some View {
        self
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(radius: shadowRadius)
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
        self.offset(x: edge == .leading ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width)
            .animation(.easeInOut(duration: duration), value: UUID())
    }
    
    // MARK: - Accessibility Modifiers
    func accessibilityLabel(_ label: String) -> some View {
        accessibilityLabel(label)
    }
    
    func accessibilityHint(_ hint: String) -> some View {
        accessibilityHint(hint)
    }
    
    func accessibilityValue(_ value: String) -> some View {
        accessibilityValue(value)
    }
    
    func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        accessibilityAddTraits(traits)
    }
    
    func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        accessibilityRemoveTraits(traits)
    }
    
    func accessibilityAction(_ action: @escaping () -> Void) -> some View {
        accessibilityAction(action)
    }
    
    func accessibilityAction(named name: Text, _ action: @escaping () -> Void) -> some View {
        accessibilityAction(named: name, action)
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
