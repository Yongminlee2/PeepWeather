import SwiftUI
import WidgetKit

/// 홈 화면 위젯: 기관별 지금 기온을 나란히. 안드로이드 CompareWidget 과 같은 모양.
///
/// 값은 앱(Dart)이 home_widget 으로 앱 그룹 UserDefaults 에 넣고 다시 그리라고 한다
/// (lib/home_widget_sync.dart). 위젯은 스스로 인터넷에 묻지 않는다.
private let appGroup = "group.com.peep.weather"

struct CompareEntry: TimelineEntry {
  let date: Date
  let place: String
  let time: String
  let mid: String
  let range: String
  let rows: [String]

  static func load() -> CompareEntry {
    let d = UserDefaults(suiteName: appGroup)
    func s(_ k: String) -> String { d?.string(forKey: k) ?? "" }
    let place = s("place")
    return CompareEntry(
      date: Date(),
      place: place.isEmpty ? appName : place,
      time: s("time"),
      mid: s("mid").isEmpty ? "—" : s("mid"),
      range: s("range"),
      rows: (0..<4).map { s("row\($0)") }.filter { !$0.isEmpty })
  }

  static let sample = CompareEntry(
    date: Date(), place: korean ? "서울" : "Seoul", time: "09:30", mid: "18°",
    range: korean ? "7곳 16° ~ 20°" : "7 sources 16° ~ 20°",
    rows: ["ECMWF 18°", "GFS 17°", "ICON 19°", korean ? "기상청 18°" : "KMA 18°"])
}

private let korean = Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
private let appName = korean ? "날씨 비교" : "Weather Compare"

struct CompareProvider: TimelineProvider {
  func placeholder(in context: Context) -> CompareEntry { .sample }
  func getSnapshot(in context: Context, completion: @escaping (CompareEntry) -> Void) {
    completion(context.isPreview ? .sample : .load())
  }
  // 앱이 새 값을 넣을 때마다 다시 그리라고 부르므로 스스로 갱신하지 않는다.
  func getTimeline(in context: Context, completion: @escaping (Timeline<CompareEntry>) -> Void) {
    completion(Timeline(entries: [.load()], policy: .never))
  }
}

// 앱 첫 화면의 하늘 카드와 같은 색: 짙은 남색 → 파랑
private let sky = LinearGradient(
  colors: [Color(red: 0x24 / 255, green: 0x50 / 255, blue: 0x8A / 255),
           Color(red: 0x4A / 255, green: 0x80 / 255, blue: 0xB4 / 255)],
  startPoint: .top, endPoint: .bottom)

struct CompareWidgetView: View {
  let e: CompareEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .widgetBackground(sky)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(e.place).font(.system(size: 14, weight: .bold)).lineLimit(1)
      Spacer(minLength: 4)
      Text(e.time).font(.system(size: 12)).opacity(0.78)
    }
  }

  private var headline: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(e.mid).font(.system(size: 40)).lineLimit(1).minimumScaleFactor(0.6)
      Text(e.range).font(.system(size: 12)).opacity(0.9).lineLimit(2)
    }
  }

  private func rows(_ n: Int) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      ForEach(Array(e.rows.prefix(n).enumerated()), id: \.offset) { _, r in
        Text(r).font(.system(size: 12)).opacity(0.85).lineLimit(1)
      }
    }
  }

  @ViewBuilder private var content: some View {
    switch family {
    case .systemSmall:
      VStack(alignment: .leading, spacing: 4) {
        header
        Spacer(minLength: 0)
        headline
      }
    case .systemMedium:
      VStack(alignment: .leading, spacing: 4) {
        header
        HStack(alignment: .bottom, spacing: 12) {
          headline.frame(maxWidth: .infinity, alignment: .leading)
          rows(4).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
      }
    default:
      VStack(alignment: .leading, spacing: 6) {
        header
        headline
        rows(4)
        Spacer(minLength: 0)
      }
    }
  }
}

extension View {
  /// iOS 17 부터는 바탕을 containerBackground 로 줘야 가장자리까지 칠해진다.
  @ViewBuilder func widgetBackground(_ g: LinearGradient) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(g, for: .widget)
    } else {
      padding().background(g)
    }
  }
}

@main
struct CompareWidget: Widget {
  // lib/home_widget_sync.dart 의 iOSName 과 같아야 앱이 다시 그리라고 할 수 있다.
  let kind = "CompareWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CompareProvider()) { e in
      CompareWidgetView(e: e)
    }
    .configurationDisplayName(appName)
    .description(korean ? "여러 기관 기온을 나란히 비교" : "Compare temperatures from several weather sources")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
