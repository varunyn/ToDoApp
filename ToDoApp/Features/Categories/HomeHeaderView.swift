//
//  HomeHeaderView.swift
//  ToDoApp
//

import SwiftUI

struct HomeHeaderView: View {
    let displayName: String
    let totalTaskCount: Int
    let completedTaskCount: Int

    private var pendingTaskCount: Int {
        max(totalTaskCount - completedTaskCount, 0)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning, \(displayName)"
        case 12..<18: "Good afternoon, \(displayName)"
        default: "Good evening, \(displayName)"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.1)
                Text(greeting)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                headerStat(value: pendingTaskCount, label: "to do", tint: AppAppearance.accent)
                headerStat(value: completedTaskCount, label: "done", tint: .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray6), AppAppearance.accent.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(AppAppearance.accent.opacity(0.1))
                    .frame(width: 90, height: 90)
                    .offset(x: 30, y: -42)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). \(pendingTaskCount) to do, \(completedTaskCount) done.")
    }

    private func headerStat(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 34)
    }
}
