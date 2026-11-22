import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        AppearanceView()
                    } label: {
                        Label("外观", systemImage: "textformat.size")
                    }

                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("备份与恢复", systemImage: "externaldrive")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("我的")
        }
    }
}