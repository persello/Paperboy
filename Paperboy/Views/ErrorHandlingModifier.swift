//
//  ErrorHandlingModifier.swift
//  Paperboy
//
//  Created by Riccardo Persello on 27/12/22.
//

import Foundation
import SwiftUI

struct LocalizedAlertError: LocalizedError {
    let underlyingError: any Error
    
    var errorDescription: String? {
        (underlyingError as? LocalizedError)?.errorDescription ?? underlyingError.localizedDescription
    }
    
    var recoverySuggestion: String? {
        (underlyingError as? LocalizedError)?.recoverySuggestion
    }

    init(error: Error) {
        underlyingError = error
    }
}

class ErrorHandler: ObservableObject {
    @Published var error: LocalizedAlertError?
    
    func handle(error: Error) {
        DispatchQueue.main.async {
            self.error = LocalizedAlertError(error: error)
        }
    }
    
    func tryPerformAsync(
        _ operation: @escaping () async throws -> Void,
        errorCallback: @escaping (Error) async -> Void = { _ in }
    ) async {
        do {
            try await operation()
        } catch {
            handle(error: error)
            await errorCallback(error)
        }
    }

    func tryPerform(
        _ operation: @escaping () throws -> Void,
        errorCallback: @escaping (Error) -> Void = { _ in }
    ) {
        do {
            try operation()
        } catch {
            handle(error: error)
            errorCallback(error)
        }
    }
}

private struct ErrorHandlerEnvironmentKey: EnvironmentKey {
    static let defaultValue = ErrorHandler()
}

extension EnvironmentValues {
    var errorHandler: ErrorHandler {
        get { self[ErrorHandlerEnvironmentKey.self] }
    }
}

struct HandleErrorsByShowingAlertViewModifier: ViewModifier {
    @Environment(\.errorHandler) private var errorHandler

    func body(content: Content) -> some View {
        content
            .background(
                EmptyView()
                    .alert(
                        isPresented: .constant(errorHandler.error != nil),
                        error: errorHandler.error,
                        actions: { error in
                            if let recoverableError = error as? RecoverableError {
                                ForEach(recoverableError.recoveryOptions.indices, id: \.self) { index in
                                    Button {
                                        recoverableError.attemptRecovery(optionIndex: index) { recovered in
                                            if recovered {
                                                self.errorHandler.error = nil
                                            }
                                            // TODO: Fallback.
                                        }
                                    } label: {
                                        Text(recoverableError.recoveryOptions[index])
                                    }
                                }
                            }
                            
                            Button(role: .cancel) {
                                errorHandler.error = nil
                            } label: {
                                Text("Dismiss")
                            }
                            .keyboardShortcut(.defaultAction)
                        },
                        message: { error in
                            if let failureReason = error.failureReason {
                                Text(failureReason)
                            }

                            if let recoverySuggestion = error.recoverySuggestion {
                                Text(recoverySuggestion)
                            }
                        }
                    )
            )
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(HandleErrorsByShowingAlertViewModifier())
    }
}
