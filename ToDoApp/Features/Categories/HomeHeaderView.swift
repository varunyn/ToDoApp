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

    private var message: String {
        if totalTaskCount == 0 {
            return "A little space for something new."
        }
        if pendingTaskCount == 0 {
            return "Everything is wrapped up for now."
        }
        if completedTaskCount == 0 {
            return "Start with one small thing."
        }
        return "You’re making good progress."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.1)
                    Text(greeting)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 12)

                Image(systemName: pendingTaskCount == 0 ? "sparkles" : "sun.max.fill")
                    .font(.title3)
                    .foregroundStyle(AppAppearance.accent)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.65), in: Circle())
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                headerStat(value: pendingTaskCount, label: "to do", tint: AppAppearance.accent)
                headerStat(value: completedTaskCount, label: "done", tint: .secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray6), AppAppearance.accent.opacity(0.13)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(AppAppearance.accent.opacity(0.12))
                    .frame(width: 130, height: 130)
                    .offset(x: 44, y: -58)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting). \(message) \(pendingTaskCount) to do, \(completedTaskCount) done.")
    }

    private func headerStat(value: Int, label: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.55), in: Capsule())
    }
}
