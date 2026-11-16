import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        if #available(iOS 17, *) {
            RootTabView()
                .modelContainer(Store.shared.container)
        } else {
            VStack {
                Text("HoneyAlarm")
                    .font(.largeTitle)
                    .padding()
                Text("需要 iOS 17 或更高版本")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}