import WidgetKit
import SwiftUI

// MARK: - Daily Blink Widget

struct DailyBlinkEntry: TimelineEntry {
    let date: Date
    let title: String
    let author: String
    let theme: String
    let formattedDuration: String
    let prompt: String
}

struct DailyBlinkTimelineProvider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.blinkist.clone")

    func placeholder(in context: Context) -> DailyBlinkEntry {
        DailyBlinkEntry(
            date: Date(),
            title: "Atomic Habits",
            author: "James Clear",
            theme: "MORNING DIGEST",
            formattedDuration: "15 min",
            prompt: "Audit your environmental cues"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyBlinkEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyBlinkEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> DailyBlinkEntry {
        let title = userDefaults?.string(forKey: "daily_title") ?? "Daily Audio Blink"
        let author = userDefaults?.string(forKey: "daily_author") ?? "Blinkist"
        let theme = userDefaults?.string(forKey: "daily_theme") ?? "Morning Digest"
        let duration = userDefaults?.string(forKey: "daily_formatted_duration") ?? "15 min"
        let prompt = userDefaults?.string(forKey: "daily_first_prompt") ?? "1-tap play morning audio digest"

        return DailyBlinkEntry(
            date: Date(),
            title: title,
            author: author,
            theme: theme.uppercased(),
            formattedDuration: duration,
            prompt: prompt
        )
    }
}

struct DailyBlinkWidgetView: View {
    let entry: DailyBlinkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DAILY BLINK ☕")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.16, green: 0.14, blue: 0.12))
                    .cornerRadius(6)

                Spacer()

                Text(entry.formattedDuration)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.17, green: 0.88, blue: 0.50))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(entry.author)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.58, green: 0.64, blue: 0.72))
                    .lineLimit(1)
            }

            HStack {
                Text(entry.prompt)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.17, green: 0.88, blue: 0.50))
                    .lineLimit(1)

                Spacer()

                Link(destination: URL(string: "blinkist://play-daily-digest")!) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(Color(red: 0.17, green: 0.88, blue: 0.50))
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.13))
        .widgetURL(URL(string: "blinkist://daily-digest"))
    }
}

// MARK: - Streak & Habit Goal Widget

struct StreakGoalEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayMinutes: Int
    let goalMinutes: Int
    let actionPlanTitle: String
    let actionItem: String
}

struct StreakGoalTimelineProvider: TimelineProvider {
    let userDefaults = UserDefaults(suiteName: "group.com.blinkist.clone")

    func placeholder(in context: Context) -> StreakGoalEntry {
        StreakGoalEntry(
            date: Date(),
            streak: 5,
            todayMinutes: 10,
            goalMinutes: 15,
            actionPlanTitle: "TODAY'S HABIT",
            actionItem: "Audit environmental cues"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakGoalEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakGoalEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> StreakGoalEntry {
        let streak = userDefaults?.integer(forKey: "user_streak") ?? 0
        let todayMinutes = userDefaults?.integer(forKey: "today_minutes") ?? 0
        let goalMinutes = max(1, userDefaults?.integer(forKey: "goal_minutes") ?? 15)
        let actionPlanTitle = userDefaults?.string(forKey: "active_action_plan_title") ?? "TODAY'S HABIT"
        let actionItem = userDefaults?.string(forKey: "active_action_item") ?? "Read or listen to today's Blink"

        return StreakGoalEntry(
            date: Date(),
            streak: streak,
            todayMinutes: todayMinutes,
            goalMinutes: goalMinutes,
            actionPlanTitle: actionPlanTitle.uppercased(),
            actionItem: actionItem
        )
    }
}

struct StreakGoalWidgetView: View {
    let entry: StreakGoalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.48, blue: 0.0))
                    Text("\(entry.streak)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(entry.streak == 1 ? "day" : "days")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.todayMinutes) / \(entry.goalMinutes) min")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.17, green: 0.88, blue: 0.50))
                    ProgressView(value: Double(min(entry.todayMinutes, entry.goalMinutes)), total: Double(entry.goalMinutes))
                        .accentColor(Color(red: 0.17, green: 0.88, blue: 0.50))
                        .frame(width: 60)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.actionPlanTitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.58, green: 0.64, blue: 0.72))
                    .lineLimit(1)
                Text(entry.actionItem)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.10, green: 0.13, blue: 0.18))
            .cornerRadius(8)
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.10, blue: 0.13))
        .widgetURL(URL(string: "blinkist://action-plans"))
    }
}
