//
//  OptionalDateField.swift
//  PicSea
//

import SwiftUI

struct OptionalDateField: View {
    @Binding var date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date },
                        set: { self.date = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()

                Button("Clear") {
                    self.date = nil
                }
                .font(.caption)
            } else {
                Button {
                    self.date = Date()
                } label: {
                    HStack {
                        Text("Any")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
