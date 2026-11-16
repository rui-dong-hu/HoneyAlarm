import SwiftUI

/// 底部三 Tab：闹钟 / 定时器 / 铃声库。
@available(iOS 17, *)
struct RootTabView: View {
    var body: some View {
        TabView {
            AlarmListView()
                .tabItem { Label("闹钟", systemImage: "alarm.fill") }
            TimerView()
                .tabItem { Label("定时器", systemImage: "timer") }
            RingLibraryView()
                .tabItem { Label("铃声库", systemImage: "music.note.list") }
        }
    }
}

@available(iOS 17, *)
#Preview {
    RootTabView()
}