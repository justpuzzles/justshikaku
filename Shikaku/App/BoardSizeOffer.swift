import UIKit

extension BoardSize {
    /// Which sizes the size picker and Stats show. 15×15 is iPad only: on a
    /// 375pt phone its cells would be 25pt, below the ~27pt that `docs/RULES.md`
    /// set as the phone ceiling at 12×12.
    ///
    /// By device, not by size class: the size picker is a sheet, and a sheet's
    /// size class on iPad is not the window's.
    static func offered(onPad: Bool) -> [BoardSize] {
        onPad ? allCases : allCases.filter { $0 != .fifteen }
    }

    static var offeredOnThisDevice: [BoardSize] {
        offered(onPad: UIDevice.current.userInterfaceIdiom == .pad)
    }
}
