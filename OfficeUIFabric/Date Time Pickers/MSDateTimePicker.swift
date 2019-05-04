//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

// MARK: MSDateTimePickerMode

@objc public enum MSDateTimePickerMode: Int {
    case date
    case dateTime
    case dateRange
    case dateTimeRange

    public var includesTime: Bool { return self == .dateTime || self == .dateTimeRange }
    public var singleSelection: Bool { return self == .date || self == .dateTime }
}

// MARK: - MSDateTimePickerDelegate

@objc public protocol MSDateTimePickerDelegate: class {
    /// Allows a class to be notified when a user confirms their selected date
    func dateTimePicker(_ dateTimePicker: MSDateTimePicker, didPickStartDate startDate: Date, endDate: Date)
    /// Allows for some validation and cancellation of picking behavior, including the dismissal of DateTimePicker classes when Done is pressed. If false is returned, the dismissal and `didPickStartDate` delegate calls will not occur. This is not called when dismissing the modal without selection, such as when tapping outside to dismiss.
    @objc optional func dateTimePicker(_ dateTimePicker: MSDateTimePicker, shouldEndPickingStartDate startDate: Date, endDate: Date) -> Bool
}

// MARK: - MSDateTimePicker

/// Manages the presentation and coordination of different date and time pickers
public class MSDateTimePicker: NSObject {
    private struct Constants {
        static let defaultDateDaysRange: Int = 1
        static let defaultDateTimeHoursRange: Int = 1
    }

    public private(set) var mode: MSDateTimePickerMode?
    @objc public weak var delegate: MSDateTimePickerDelegate?

    private var presentingController: UIViewController?
    private var presentedPickers: [DateTimePicker]?

    /// Presents a picker or set of pickers from a `presentingController` depending on the mode selected. Also handles accessibility replacement presentation.
    ///
    /// - Parameters:
    ///   - presentingController: The view controller that is presenting these pickers
    ///   - mode: Enum describing which mode of pickers should be presented
    ///   - startDate: The initial date selected on the presented pickers
    ///   - endDate: An optional end date to pick a range of dates. Ignored if mode is `.date` or `.dateTime`. If the mode selected is either `.dateRange` or `.dateTimeRange`, and this is omitted, it will be set to a default 1 day or 1 hour range, respectively.
    @objc public func present(from presentingController: UIViewController, with mode: MSDateTimePickerMode, startDate: Date = Date(), endDate: Date? = nil) {
        self.presentingController = presentingController
        self.mode = mode
        if UIAccessibility.isVoiceOverRunning {
            presentDateTimePickerForAccessibility(startDate: startDate, endDate: endDate ?? startDate)
            return
        }
        switch mode {
        case .date:
            presentDatePicker(startDate: startDate, endDate: startDate)
        case .dateTime:
            presentDateTimePicker(startDate: startDate, endDate: startDate)
        case .dateRange:
            presentDatePicker(startDate: startDate, endDate: endDate ?? startDate.adding(days: Constants.defaultDateDaysRange))
        case .dateTimeRange:
            presentDateTimePicker(startDate: startDate, endDate: endDate ?? startDate.adding(hours: Constants.defaultDateTimeHoursRange))
        }
    }

    @objc public func dismiss() {
        presentingController?.dismiss(animated: true)
        mode = nil
        presentedPickers = nil
        presentingController = nil
    }

    private func presentDatePicker(startDate: Date, endDate: Date) {
        guard let mode = mode else {
            fatalError("Mode not set when presenting date picker")
        }
        let startDate = startDate.startOfDay
        let endDate = endDate.startOfDay
        if mode == .dateRange {
            let startDatePicker = MSDatePickerController(startDate: startDate, endDate: endDate, mode: mode, selectionMode: .start, subtitle: "MSDateTimePicker.StartDate".localized)
            let endDatePicker = MSDatePickerController(startDate: startDate, endDate: endDate, mode: mode, selectionMode: .end, subtitle: "MSDateTimePicker.EndDate".localized)
            present([startDatePicker, endDatePicker])
        } else {
            let datePicker = MSDatePickerController(startDate: startDate, endDate: startDate, mode: mode)
            present([datePicker])
        }
    }

    private func presentDateTimePicker(startDate: Date, endDate: Date) {
        guard let mode = mode else {
            fatalError("Mode not set when presenting date time picker")
        }
        // If we are not presenting a range, or if we have a range, but it is within the same calendar day, present both dateTimePicker and datePicker. Otherwise, present just a dateTimePicker
        if mode == .dateTime || Calendar.current.isDate(startDate, inSameDayAs: endDate) {
            let dateTimePicker = MSDateTimePickerController(startDate: startDate, endDate: endDate, mode: mode)
            // Create datePicker second to pick up the time that dateTimePicker rounded to the nearest minute interval
            let datePicker = MSDatePickerController(startDate: dateTimePicker.startDate, endDate: dateTimePicker.endDate, mode: mode)
            present([datePicker, dateTimePicker])
        } else {
            let dateTimePicker = MSDateTimePickerController(startDate: startDate, endDate: endDate, mode: mode)
            present([dateTimePicker])
        }
    }

    private func presentDateTimePickerForAccessibility(startDate: Date, endDate: Date) {
        guard let mode = mode else {
            fatalError("Mode not set when presenting date time picker for accessibility")
        }
        let dateTimePicker = MSDateTimePickerController(startDate: startDate, endDate: endDate, mode: mode)
        present([dateTimePicker])
    }

    private func present(_ pickers: [DateTimePicker]) {
        pickers.forEach { $0.delegate = self }
        presentedPickers = pickers

        let viewControllers = pickers.map { MSCardPresenterNavigationController(rootViewController: $0 as! UIViewController) }
        let pageCardPresenter = MSPageCardPresenterController(viewControllers: viewControllers, startingIndex: 0)
        pageCardPresenter.onDismiss = {
            self.dismiss()
        }
        presentingController?.present(pageCardPresenter, animated: true)
    }
}

// MARK: - MSDateTimePicker: DateTimePickerDelegate

extension MSDateTimePicker: DateTimePickerDelegate {
    func dateTimePicker(_ dateTimePicker: DateTimePicker, didPickStartDate startDate: Date, endDate: Date) {
        delegate?.dateTimePicker(self, didPickStartDate: startDate, endDate: endDate)
    }

    func dateTimePicker(_ dateTimePicker: DateTimePicker, didSelectStartDate startDate: Date, endDate: Date) {
        guard let presentedPickers = presentedPickers else {
            return
        }
        for picker in presentedPickers where picker !== dateTimePicker {
            picker.startDate = startDate
            picker.endDate = endDate
        }
    }

    func dateTimePicker(_ dateTimePicker: DateTimePicker, shouldEndPickingStartDate startDate: Date, endDate: Date) -> Bool {
        return delegate?.dateTimePicker?(self, shouldEndPickingStartDate: startDate, endDate: endDate) ?? true
    }
}
