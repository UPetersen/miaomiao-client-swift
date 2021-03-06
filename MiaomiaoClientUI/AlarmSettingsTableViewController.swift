//
//  AlarmsClientSettingsViewController.swift
//  MiaomiaoClientUI
//
//  Created by Bjørn Inge Berg on 11/04/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//
import UIKit
import LoopKitUI
import LoopKit

import HealthKit

public protocol AlarmSettingsTableViewControllerDelegate: class {
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBasalRatePerHour(_ vc: DeliveryLimitSettingsTableViewController)
    
    func deliveryLimitSettingsTableViewControllerDidUpdateMaximumBolus(_ vc: DeliveryLimitSettingsTableViewController)
}


public enum DeliveryLimitSettingsResult {
    case success(maximumBasalRatePerHour: Double, maximumBolus: Double)
    case failure(Error)
}


public protocol AlarmSettingsTableViewControllerSyncSource: class {
    func syncDeliveryLimitSettings(for viewController: AlarmSettingsTableViewController, completion: @escaping (_ result: DeliveryLimitSettingsResult) -> Void)
    
    func syncButtonTitle(for viewController: AlarmSettingsTableViewController) -> String
    
    func syncButtonDetailText(for viewController: AlarmSettingsTableViewController) -> String?
    
    func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: AlarmSettingsTableViewController) -> Bool
}


public class AlarmSettingsTableViewController: UITableViewController, AlarmTimeInputCellDelegate, LFTimePickerDelegate {
    func AlarmTimeInputRangeCellWasDisabled(_ cell: AlarmTimeInputRangeCell) {
        NSLog("this schedule was disabled")
    }
    
    public func didPickTime(_ start: String, end: String) {
        NSLog("YES, TIME WAS PICKED")
    }
    
    
    
    
    private var datepickerSender : AlarmTimeInputRangeCell?
    public func didPickTime(_ start: String, end: String, startComponents: DateComponents?, endComponents: DateComponents?) {
        NSLog("YES, TIME WAS PICKED")
        print(startComponents)
        print(endComponents)
        
        //datepickerSender?.minValue = start
        //datepickerSender?.maxValue = end
        datepickerSender?.minComponents = startComponents
        datepickerSender?.maxComponents = endComponents
    }
    
    private var glucoseUnit : HKUnit
    public weak var delegate: AlarmSettingsTableViewControllerDelegate?
    
    func AlarmTimeInputRangeCellDidTouch(_ cell: AlarmTimeInputRangeCell) {
        //1. Create a LFTimePickerController
        let timePicker = LFTimePickerController()
        
        //2. Present the timePicker
        //self.navigationController?.pushViewController(timePicker, animated: true)
        self.navigationController?.show(timePicker, sender: cell)
        timePicker.delegate = self
        self.datepickerSender = cell
    }
    
    public var maximumBasalRatePerHour: Double? {
        didSet {
            /*if isViewLoaded, let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.basalRate.rawValue)) as? TextFieldTableViewCell {
             if let maximumBasalRatePerHour = maximumBasalRatePerHour {
             cell.textField.text = valueNumberFormatter.string(from:  maximumBasalRatePerHour)
             } else {
             cell.textField.text = nil
             }
             }*/
        }
    }
    
    public var maximumBolus: Double? {
        didSet {
            /*if isViewLoaded, let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.bolus.rawValue)) as? TextFieldTableViewCell {
             if let maximumBolus = maximumBolus {
             cell.textField.text = valueNumberFormatter.string(from: maximumBolus)
             } else {
             cell.textField.text = nil
             }
             }*/
        }
    }
    
    private func serializeSettings() -> GlucoseScheduleList {
        var schedules = GlucoseScheduleList()
        var schedule = GlucoseSchedule()
        
        for var cell in tableView.visibleCells {
            let index = tableView.indexPath(for: cell)
            //todo: replace with dynamic check of number of schedules
            if let section = index?.section, section >  glucoseSchedulesCount{
                
                break
            }
            if let cell = cell as? AlarmTimeInputRangeCell {
                schedule = GlucoseSchedule()
                schedules.schedules?.append(schedule)
                
                schedule.enabled = cell.toggleIsSelected.isOn
                schedule.from = cell.minComponents
                schedule.to = cell.maxComponents
                
                schedule.glucoseUnitIsMgdl = (self.glucoseUnit == HKUnit.milligramsPerDeciliter)
                
            } else if let cell = cell as? GlucoseAlarmInputCell {
                if cell.alarmType == GlucoseAlarmType.low {
                    schedule.lowAlarm =  cell.minValue
                } else if cell.alarmType == GlucoseAlarmType.high {
                    schedule.highAlarm = cell.minValue
                }
            }
            
            
            
        }
        return schedules
    }
    
    public var isReadOnly = false
    
    private var isSyncInProgress = false {
        didSet {
            
            for cell in tableView.visibleCells {
                switch cell {
                case let cell as TextButtonTableViewCell:
                    cell.isEnabled = !isSyncInProgress
                    cell.isLoading = isSyncInProgress
                case let cell as TextFieldTableViewCell:
                    cell.textField.isEnabled = !isReadOnly && !isSyncInProgress
                default:
                    break
                }
            }
            
            for item in navigationItem.rightBarButtonItems ?? [] {
                item.isEnabled = !isSyncInProgress
            }
            
            navigationItem.hidesBackButton = isSyncInProgress
        }
    }
    private lazy var glucoseSchedules : GlucoseScheduleList? = UserDefaults.standard.glucoseSchedules
    
    private lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        
        return formatter
    }()
    
    // MARK: -
    public init(glucoseUnit: HKUnit) {
        self.glucoseUnit = glucoseUnit
        
        super.init(style: .grouped)
        print("loaded glucose schedule was \(glucoseSchedules)")
        
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(AlarmTimeInputRangeCell.nib(), forCellReuseIdentifier: AlarmTimeInputRangeCell.className)
        
        tableView.register(GlucoseAlarmInputCell.nib(), forCellReuseIdentifier: GlucoseAlarmInputCell.className)
        
        tableView.register(TextFieldTableViewCell.nib(), forCellReuseIdentifier: TextFieldTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }
    
    // MARK: - Table view data source
    
    
    private let minimumSchedulesCount = 2
   
    
    private var glucoseSchedulesCount : Int{
        let count = glucoseSchedules?.schedules?.count ?? 0
        return count >= minimumSchedulesCount ? count : minimumSchedulesCount
    }
    
    private enum ScheduleRow : Int {
        case timerange
        case lowglucose
        case highglucose
        
        static let count = 3
    }
    
    
    public override func numberOfSections(in tableView: UITableView) -> Int {
        //dynamic number of schedules + sync row
        return glucoseSchedulesCount + 1
        
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        /*switch Section(rawValue: section)! {
         case .schedule1:
         return ScheduleRow.count
         case .schedule2:
         return ScheduleRow.count
         case .sync:
         return 1
         }*/
        
        switch section {
        case let x where x < glucoseSchedulesCount:
            return ScheduleRow.count
        default:
            return 1
        }
        
        
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        switch (indexPath.section) {
            
        case let x where x < glucoseSchedulesCount:
            
            let bundle = Bundle(for: type(of: self))
            
            var savedSchedule = glucoseSchedules?.schedules?[safe: indexPath.section]
            
            switch ScheduleRow(rawValue: indexPath.row)! {
                
            case .timerange:
                let cell = tableView.dequeueReusableCell(withIdentifier: AlarmTimeInputRangeCell.className, for: indexPath) as!  AlarmTimeInputRangeCell
                
                //cell.minValue = "first"
                //cell.maxValue = "second"
                cell.delegate = self
                
                if let schedule = savedSchedule {
                    cell.minComponents = schedule.from
                    cell.maxComponents = schedule.to
                    cell.toggleIsSelected.isOn = schedule.enabled ?? true
                }
                
                
                cell.iconImageView.image = UIImage(named: "icons8-schedule-50", in: bundle, compatibleWith: traitCollection)
                
                return cell
            case .lowglucose:
                let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseAlarmInputCell.className, for: indexPath) as!  GlucoseAlarmInputCell
                cell.alarmType = GlucoseAlarmType.low
                cell.minValueTextField.placeholder = "glucose"
                cell.unitString = self.glucoseUnit.localizedShortUnitString
                cell.minValueTextField.keyboardType = .decimalPad
                cell.iconImageView.image = UIImage(named: "icons8-drop-down-arrow-50", in: bundle, compatibleWith: traitCollection)
                
                if let schedule = savedSchedule,
                    let glucose = schedule.glucose(forUnit: self.glucoseUnit, type: GlucoseAlarmType.low)  {
                    cell.minValue = glucose
                }
                
                return cell
            case .highglucose:
                let cell = tableView.dequeueReusableCell(withIdentifier: GlucoseAlarmInputCell.className, for: indexPath) as!  GlucoseAlarmInputCell
                
                cell.alarmType = GlucoseAlarmType.high
                cell.minValueTextField.keyboardType = .decimalPad
                
                cell.unitString = self.glucoseUnit.localizedShortUnitString
                cell.minValueTextField.placeholder = "glucose"
                cell.iconImageView.image = UIImage(named: "icons8-slide-up-50", in: bundle, compatibleWith: traitCollection)
                
                if let schedule = savedSchedule,
                    let glucose = schedule.glucose(forUnit: self.glucoseUnit, type: GlucoseAlarmType.high)  {
                    cell.minValue = glucose
                }
                
                return cell
            }
            
        default: //case .sync:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            
            cell.textLabel?.text = LocalizedString("Save glucose alarms", comment: "The title for Save glucose alarms")
            cell.isEnabled = !isSyncInProgress
            cell.isLoading = isSyncInProgress
            
            return cell
        }
    }
    
    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case let x where x < glucoseSchedulesCount:
            
            return LocalizedString("Glucose Alarm Schedule", comment: "The title text for the Glucose Alarm Schedule") + " #\(section+1)"
            
        default: //case .sync:
            return nil
        }
    }
    
    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
        /*switch Section(rawValue: section)! {
         case .schedule1:
         return nil
         case .schedule2:
         return nil
         case .sync:
         return nil //LocalizedString("Save alarms", comment: "The title for saving alarms")
         }*/
    }
    
    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case let x where x < glucoseSchedulesCount:
            if let cell = tableView.cellForRow(at: indexPath) as? TextFieldTableViewCell {
                if cell.textField.isFirstResponder {
                    cell.textField.resignFirstResponder()
                } else {
                    cell.textField.becomeFirstResponder()
                }
            }
        default: //case .sync:
            tableView.endEditing(true)
            
            isSyncInProgress = true
            
            
            DispatchQueue.main.async {
                
                
                let settings = self.serializeSettings()
                print("saving glucose schedule: ")
                
                print("saving glucose schedule as: : \(settings)")
                UserDefaults.standard.glucoseSchedules = settings
                UserDefaults.standard.synchronize()
                
                print("saved glucose schedule was \(UserDefaults.standard.glucoseSchedules)")
                
                self.isSyncInProgress = false
                let ok = OKAlertController("Glucose alarms successfully saved", title: "Glucose Alarms")
                self.present(ok, animated: true)
            }
            
            /*syncSource.syncDeliveryLimitSettings(for: self) { (result) in
             DispatchQueue.main.async {
             switch result {
             case .success(maximumBasalRatePerHour: let maxBasal, maximumBolus: let maxBolus):
             self.maximumBasalRatePerHour = maxBasal
             self.maximumBolus = maxBolus
             
             self.delegate?.deliveryLimitSettingsTableViewControllerDidUpdateMaximumBasalRatePerHour(self)
             self.delegate?.deliveryLimitSettingsTableViewControllerDidUpdateMaximumBolus(self)
             
             self.isSyncInProgress = false
             case .failure(let error):
             self.presentAlertController(with: error, animated: true, completion: {
             self.isSyncInProgress = false
             })
             }
             }
             }*/
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


