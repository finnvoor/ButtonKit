//
//  Button+Async.swift
//  ButtonKit
//
//  MIT License
//
//  Copyright (c) 2024 Thomas Durand
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import SwiftUI

public struct AsyncButton<P: TaskProgress, S: View>: View {
    @Environment(\.asyncButtonStyle)
    private var asyncButtonStyle
    @Environment(\.allowsHitTestingWhenLoading)
    private var allowsHitTestingWhenLoading
    @Environment(\.disabledWhenLoading)
    private var disabledWhenLoading
    @Environment(\.isEnabled)
    private var isEnabled
    @Environment(\.throwableButtonStyle)
    private var throwableButtonStyle
    @Environment(\.triggerButton)
    private var triggerButton

    private let role: ButtonRole?
    private let id: AnyHashable?
    private let action: @MainActor (P) async throws -> Void
    private let label: S

    @State private var task: Task<Void, Never>?
    @ObservedObject private var progress: P
    private let isLoading: Binding<Bool>?
    @State private var errorCount = 0

    public var body: some View {
        let throwableLabelConfiguration = ThrowableButtonStyleLabelConfiguration(
            label: AnyView(label),
            errorCount: errorCount
        )
        let label: AnyView
        let asyncLabelConfiguration = AsyncButtonStyleLabelConfiguration(
            label: AnyView(throwableButtonStyle.makeLabel(configuration: throwableLabelConfiguration)),
            isLoading: task != nil,
            fractionCompleted: progress.fractionCompleted,
            cancel: cancel
        )
        label = asyncButtonStyle.makeLabel(configuration: asyncLabelConfiguration)
        let button = Button(role: role, action: perform) {
            label
        }
        let throwableConfiguration = ThrowableButtonStyleButtonConfiguration(
            button: AnyView(button),
            errorCount: errorCount
        )
        let asyncConfiguration = AsyncButtonStyleButtonConfiguration(
            button: AnyView(throwableButtonStyle.makeButton(configuration: throwableConfiguration)),
            isLoading: task != nil,
            fractionCompleted: progress.fractionCompleted,
            cancel: cancel
        )
        return asyncButtonStyle
            .makeButton(configuration: asyncConfiguration)
            .allowsHitTesting(allowsHitTestingWhenLoading || task == nil)
            .disabled(disabledWhenLoading && task != nil)
            .preference(key: AsyncButtonTaskPreferenceKey.self, value: task)
            .onAppear {
                isLoading?.wrappedValue = false
                guard let id else {
                    return
                }
                triggerButton.register(id: id, action: perform)
            }
            .onDisappear {
                guard let id else {
                    return
                }
                triggerButton.unregister(id: id)
            }
    }

    public init(
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        progress: P,
        isLoading: Binding<Bool>? = nil,
        action: @MainActor @escaping (P) async throws -> Void,
        @ViewBuilder label: @escaping () -> S
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: progress)
        self.isLoading = isLoading
        self.action = action
        self.label = label()
    }

    private func perform() {
        guard task == nil, isEnabled else {
            return
        }
        task = Task {
            isLoading?.wrappedValue = true
            defer { isLoading?.wrappedValue = false }
            // Initialize progress
            progress.reset()
            await progress.started()
            do {
                try await action(progress)
            } catch {
                errorCount += 1
            }
            // Reset progress
            await progress.ended()
            task = nil
        }
    }

    private func cancel() {
        task?.cancel()
        task = nil
        isLoading?.wrappedValue = false
    }
}

extension AsyncButton where S == Text {
    public init(
        _ titleKey: LocalizedStringKey,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        progress: P,
        isLoading: Binding<Bool>? = nil,
        action: @MainActor @escaping (P) async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: progress)
        self.isLoading = isLoading
        self.action = action
        self.label = Text(titleKey)
    }

    @_disfavoredOverload
    public init(
        _ title: some StringProtocol,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        progress: P,
        isLoading: Binding<Bool>? = nil,
        action: @MainActor @escaping (P) async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: progress)
        self.isLoading = isLoading
        self.action = action
        self.label = Text(title)
    }
}

extension AsyncButton where S == Label<Text, Image> {
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        progress: P,
        isLoading: Binding<Bool>? = nil,
        action: @MainActor @escaping (P) async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: progress)
        self.isLoading = isLoading
        self.action = action
        self.label = Label(titleKey, systemImage: systemImage)
    }

    @_disfavoredOverload
    public init(
        _ title: some StringProtocol,
        systemImage: String,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        progress: P,
        isLoading: Binding<Bool>? = nil,
        action: @MainActor @escaping (P) async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: progress)
        self.isLoading = isLoading
        self.action = action
        self.label = Label(title, systemImage: systemImage)
    }
}

extension AsyncButton where P == IndeterminateProgress {
    public init(
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        isLoading: Binding<Bool>? = nil,
        action: @escaping () async throws -> Void,
        @ViewBuilder label: @escaping () -> S
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: .indeterminate)
        self.isLoading = isLoading
        self.action = { _ in try await action()}
        self.label = label()
    }
}

extension AsyncButton where P == IndeterminateProgress, S == Text {
    public init(
        _ titleKey: LocalizedStringKey,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        isLoading: Binding<Bool>? = nil,
        action: @escaping () async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: .indeterminate)
        self.isLoading = isLoading
        self.action = { _ in try await action()}
        self.label = Text(titleKey)
    }

    @_disfavoredOverload
    public init(
        _ title: some StringProtocol,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        isLoading: Binding<Bool>? = nil,
        action: @escaping () async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: .indeterminate)
        self.isLoading = isLoading
        self.action = { _ in try await action()}
        self.label = Text(title)
    }
}

extension AsyncButton where P == IndeterminateProgress, S == Label<Text, Image> {
    public init(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        isLoading: Binding<Bool>? = nil,
        action: @escaping () async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: .indeterminate)
        self.isLoading = isLoading
        self.action = { _ in try await action()}
        self.label = Label(titleKey, systemImage: systemImage)
    }

    @_disfavoredOverload
    public init(
        _ title: some StringProtocol,
        systemImage: String,
        role: ButtonRole? = nil,
        id: AnyHashable? = nil,
        isLoading: Binding<Bool>? = nil,
        action: @escaping () async throws -> Void
    ) {
        self.role = role
        self.id = id
        self._progress = .init(initialValue: .indeterminate)
        self.isLoading = isLoading
        self.action = { _ in try await action()}
        self.label = Label(title, systemImage: systemImage)
    }
}

#Preview("Indeterminate") {
    AsyncButton {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    } label: {
        Text("Process")
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.roundedRectangle)
}

#Preview("Determinate") {
    AsyncButton(progress: .discrete(totalUnitCount: 100)) { progress in
        for _ in 1...100 {
            try await Task.sleep(nanoseconds: 20_000_000)
            progress.completedUnitCount += 1
        }
    } label: {
        Text("Process")
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.roundedRectangle)
}

#Preview("Indeterminate error") {
    AsyncButton {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        throw NSError() as Error
    } label: {
        Text("Process")
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.roundedRectangle)
    .asyncButtonStyle(.overlay)
    .throwableButtonStyle(.shake)
}

#Preview("Determinate error") {
    AsyncButton(progress: .discrete(totalUnitCount: 100)) { progress in
        for _ in 1...42 {
            try await Task.sleep(nanoseconds: 20_000_000)
            progress.completedUnitCount += 1
        }
        throw NSError() as Error
    } label: {
        Text("Process")
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.roundedRectangle)
}

@available(iOS 17.0, *)
#Preview("isLoading") {
    @Previewable @State var isLoading = false
    VStack {
        Text(isLoading ? "Loading..." : "Not Loading")
        AsyncButton(isLoading: $isLoading) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        } label: {
            Text("Process")
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle)
    }
}
