import CloudKit
import SwiftUI
import UIKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let title: String
    let onChange: () -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let sheet: CloudSharingSheet
        init(_ sheet: CloudSharingSheet) { self.sheet = sheet }
        func itemTitle(for csc: UICloudSharingController) -> String? { sheet.title }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            sheet.onError(error)
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { sheet.onChange() }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { sheet.onChange() }
    }
}
