//
//  CustomSheet.swift
//  Paperboy
//
//  Created by Riccardo Persello on 29/12/22.
//

import SwiftUI

struct CustomSheet<Content: View, DoneButton: View, CancelButton: View>: View {
    
    @ViewBuilder let content: () -> Content
    @ViewBuilder let cancelButton: () -> CancelButton
    @ViewBuilder let doneButton: () -> DoneButton
    
    var body: some View {
        
#if os(iOS)
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        self.cancelButton()
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        self.doneButton()
                            .bold()
                    }
                }
        }
#elseif os(macOS)
        VStack {
            content()
            
            Spacer()
            
            HStack {
                Spacer()
                
                if let cancelButton {
                    cancelButton()
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.large)
                }
                
                if let doneButton {
                    doneButton()
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                        .tint(.accentColor)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .padding()
#endif
    }
}

extension CustomSheet where DoneButton == EmptyView, CancelButton == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.cancelButton = { EmptyView() }
        self.doneButton = { EmptyView() }
    }
}

extension CustomSheet where DoneButton == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder cancelButton: @escaping () -> CancelButton) {
        self.content = content
        self.cancelButton = cancelButton
        self.doneButton = { EmptyView() }
    }
}

extension CustomSheet where CancelButton == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder doneButton: @escaping () -> DoneButton) {
        self.content = content
        self.cancelButton = { EmptyView() }
        self.doneButton = doneButton
    }
}

struct CustomSheet_Previews: PreviewProvider {
    static var previews: some View {
        Text("Sheet")
            .sheet(isPresented: .constant(true)) {
                CustomSheet {
                    Text("Sheet content")
                } cancelButton: {
                    Button {
                        
                    } label: {
                        Text("Cancel")
                    }
                    
                } doneButton: {
                    Button {
                        
                    } label: {
                        Text("Done")
                    }
                }
            }
    }
}
