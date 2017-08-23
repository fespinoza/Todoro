//
//  DetailViewController.swift
//  Todoro
//
//  Created by Felipe Espinoza Castillo on 13/07/2017.
//  Copyright © 2017 Felipe Espinoza Castillo. All rights reserved.
//

import UIKit
import AVKit
import AudioToolbox
import UserNotifications

private extension String {
  static let showCompletedPomodoros = "showCompletedPomodoros"
  static let lastTimerTimeInSecondsKey = "lastTimerTimeInSecondsKey"
  static let taskIDKey = "taskIDKey"
  static let timerStateKey = "timerStateKey"
}

class DetailViewController: UIViewController {
  private struct Default {
    static let oneMinute: Double = 60.0
    static let testTimerInSeconds = oneMinute
    static let pomodoroTimerInSeconds = 25 * oneMinute
    static let breakTimerInSecords = 5 * oneMinute
  }

  enum State: String {
    case waiting
    case pomodoroRunning
    case breakRunning
    case taskCompleted
  }

  // MARK: - Properties

  var task: Task?
  var sortedPomodoros: [Pomodoro] {
    return (task?.pomodoros?.allObjects as! [Pomodoro]).sorted(by: { (first, second) -> Bool in
      return first.completionTime! >= second.completionTime!
    })
  }

  var currentState: State = .waiting {
    didSet { configureView() }
  }

  let defaultPomodoroTimeInSeconds = Default.pomodoroTimerInSeconds
  let defaultBreakTimeInSeconds = Default.breakTimerInSecords

  var currentTimeInSeconds: Double = Default.pomodoroTimerInSeconds {
    didSet {
      self.updateTimerLabel()
    }
  }
  var timer: Timer?

  var lastTimerTimeInSeconds: Double?

  var player = AVAudioPlayer()

  // temp
  var pomodoroCount = 0 {
    didSet {
      updateCompletedPomodorosLabel()
    }
  }

  // MARK: - IBOutlets
  @IBOutlet weak var completedPomodorosLabel: UILabel!
  @IBOutlet weak var timerLabel: UILabel!

  @IBOutlet weak var addMinutesButton: UIButton!
  @IBOutlet weak var removeMinutesButton: UIButton!

  @IBOutlet weak var startPomodoroButton: UIButton!
  @IBOutlet weak var forcePomodoroCompletionButton: UIButton!
  @IBOutlet weak var finishBreakButton: UIButton!
  @IBOutlet weak var cancelPomodoroButton: UIButton!
  @IBOutlet weak var markTaskAsCompletedButton: UIButton!
  @IBOutlet weak var deleteTaskButton: UIButton!
  @IBOutlet weak var showCompletedPomodorosButton: UIButton!
  
  // MARK: - View Cycle

  override func viewDidLoad() {
    super.viewDidLoad()

    if let task = task {
      setPomodoroTimeValueInSeconds()
      currentState = task.isCompleted ? .taskCompleted : .waiting
    } else {
      configureView()
    }

    let app = UIApplication.shared

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.applicationWillResignActive(notification:)),
      name: NSNotification.Name.UIApplicationWillResignActive,
      object: app
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.applicationWillBecomeActive(notification:)),
      name: NSNotification.Name.UIApplicationDidBecomeActive,
      object: app
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    print("DetailsViewController", #function)

    if let task = task {
      navigationItem.title = task.title
      pomodoroCount = task.pomodoros?.count ?? 0
    }
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == .showCompletedPomodoros, let pomodoroListVC = segue.destination as? PomodoroListViewController {
      pomodoroListVC.pomodoros = sortedPomodoros
      pomodoroListVC.task = task
    }
  }

  // MARK: - IBActions

  @IBAction func addAMinuteToPomodoro(_ sender: Any) {
    currentTimeInSeconds += Default.oneMinute
  }

  @IBAction func removeAMinuteToPomodoro(_ sender: Any) {
    if currentTimeInSeconds - Default.oneMinute > 0 {
      currentTimeInSeconds -= Default.oneMinute
    }
  }

  @IBAction func startPomodoro(_ sender: Any) {
    currentState = .pomodoroRunning
    lastTimerTimeInSeconds = currentTimeInSeconds
    startTimer()
  }

  @IBAction func forcePomodoroCompletion(_ sender: Any) {
    stopTimer()
  }

  @IBAction func cancelPomodoro(_ sender: Any) {
    stopTimer()
    currentState = .waiting
    setPomodoroTimeValueInSeconds()
  }
  
  @IBAction func finishBreak(_ sender: Any) {
    cancelPomodoro(sender)
  }

  @IBAction func markTaskAsCompleted(_ sender: Any) {
    task?.isCompleted = true
    (UIApplication.shared.delegate as? AppDelegate)!.saveContext()
    currentState = .taskCompleted

    // TODO: go back to the master view controller (only in compact mode i guess)
    if let navigationVC = self.splitViewController?.viewControllers.first as? UINavigationController {
      navigationVC.popToRootViewController(animated: true)
    }
  }

  @IBAction func deleteTask(_ sender: Any) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let task = task else {
        return
    }

    let alertController = UIAlertController(
      title: "Deleting Task",
      message: "Are you sure you want to delete the task?",
      preferredStyle: .alert
    )
    alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
      let context = appDelegate.persistentContainer.viewContext

      context.delete(task)
      appDelegate.saveContext()

      if let navigationVC = self.splitViewController?.viewControllers.first as? UINavigationController {
        navigationVC.popToRootViewController(animated: true)
      }
    }))

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

    present(alertController, animated: true, completion: nil)
  }

  // MARK: - Business Logic

  fileprivate func setPomodoroTimeValueInSeconds() {
    assert(currentState == .waiting)

    if sortedPomodoros.count > 0 {
      let lastPomodoro = sortedPomodoros.first!
      currentTimeInSeconds = Double(lastPomodoro.duration)
    } else {
      currentTimeInSeconds = Default.pomodoroTimerInSeconds
    }
  }

  fileprivate func setBreakTimeValueInSeconds() {
    guard let lastTimerTimeInSeconds = lastTimerTimeInSeconds else {
      preconditionFailure("the last pomodoro never started")
    }

    currentTimeInSeconds = ceil(Double(lastTimerTimeInSeconds) / 5.0)
  }

  fileprivate func numberOfMinutes() -> Double {
    return floor(currentTimeInSeconds / Default.oneMinute)
  }

  fileprivate func numberOfSeconds() -> Double {
    return currentTimeInSeconds.truncatingRemainder(dividingBy: Default.oneMinute)
  }

  fileprivate func completePomodoro() {
    playBell()
    pomodoroCount += 1

    savePomodoro()

    let alertController = UIAlertController(
      title: "Pomodoro Finished",
      message: "Good job completing the pomodoro, what do you want to do next?",
      preferredStyle: .alert
    )

    let breakButton = UIAlertAction(title: "Break", style: .default) { (action) in
      self.currentState = .breakRunning
      self.setBreakTimeValueInSeconds()
      self.startTimer()
    }
    alertController.addAction(breakButton)

    let cancelButton = UIAlertAction(title: "Done", style: .cancel) { (action) in
      self.currentState = .waiting
    }
    alertController.addAction(cancelButton)

    self.present(alertController, animated: true, completion: nil)
  }

  fileprivate func completeBreak() {
    playBell()

    let alertController = UIAlertController(
      title: "Break Finished",
      message: "Do you want to work during another pomodoro?",
      preferredStyle: .alert
    )

    let newPomodoroButton = UIAlertAction(title: "Sure", style: .default) { (action) in
      self.currentState = .pomodoroRunning
      guard let lastTimerTimeInSeconds = self.lastTimerTimeInSeconds else {
        preconditionFailure("this should have been populated")
      }
      self.currentTimeInSeconds = lastTimerTimeInSeconds
      self.startTimer()
    }
    alertController.addAction(newPomodoroButton)

    let cancelButton = UIAlertAction(title: "Done", style: .cancel) { (action) in
      self.currentState = .waiting
    }
    alertController.addAction(cancelButton)

    self.present(alertController, animated: true, completion: nil)
  }

  func savePomodoro() {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let task = task,
      let lastTimerTimeInSeconds = lastTimerTimeInSeconds else {
        return
    }

    let context = appDelegate.persistentContainer.viewContext
    let newPomodoro = Pomodoro(context: context)

    newPomodoro.completionTime = Date()
    newPomodoro.task = task
    newPomodoro.id = UUID().uuidString
    newPomodoro.duration = Float(lastTimerTimeInSeconds)

    // Save the context.
    do {
      try context.save()
    } catch {
      // Replace this implementation with code to handle the error appropriately.
      // fatalError() causes the application to generate a crash log and terminate.
      // You should not use this function in a shipping application, although it may be useful during development.
      let nserror = error as NSError
      fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
    }
  }

  // MARK: - View Logic

  fileprivate func configureView() {
    updateCompletedPomodorosLabel()
    updateTimerLabel()

    switch currentState {
    case .waiting:
      setPomodoroTimeValueInSeconds()
      timerLabel.textColor = UIColor.black
      completedPomodorosLabel.textColor = UIColor.black

      addMinutesButton.isHidden = false
      removeMinutesButton.isHidden = false

      startPomodoroButton.isHidden = false
      forcePomodoroCompletionButton.isHidden = true
      finishBreakButton.isHidden = true
      cancelPomodoroButton.isHidden = true
      markTaskAsCompletedButton.isHidden = false
      deleteTaskButton.isHidden = false
      showCompletedPomodorosButton.isHidden = false
    case .pomodoroRunning:
      timerLabel.textColor = UIColor.black
      completedPomodorosLabel.textColor = UIColor.black

      addMinutesButton.isHidden = true
      removeMinutesButton.isHidden = true

      startPomodoroButton.isHidden = true
      forcePomodoroCompletionButton.isHidden = false
      finishBreakButton.isHidden = true
      cancelPomodoroButton.isHidden = false
      markTaskAsCompletedButton.isHidden = true
      deleteTaskButton.isHidden = true
      showCompletedPomodorosButton.isHidden = true
    case .breakRunning:
      addMinutesButton.isHidden = true
      removeMinutesButton.isHidden = true

      startPomodoroButton.isHidden = true
      forcePomodoroCompletionButton.isHidden = true
      finishBreakButton.isHidden = false
      cancelPomodoroButton.isHidden = true
      markTaskAsCompletedButton.isHidden = true
      deleteTaskButton.isHidden = true
      showCompletedPomodorosButton.isHidden = true

      completedPomodorosLabel.text = "You won a break..."
      completedPomodorosLabel.textColor = UIColor.gray
      timerLabel.textColor = UIColor.blue
    case .taskCompleted:
      timerLabel.textColor = UIColor.gray
      completedPomodorosLabel.textColor = UIColor.gray

      addMinutesButton.isHidden = true
      removeMinutesButton.isHidden = true

      startPomodoroButton.isHidden = true
      forcePomodoroCompletionButton.isHidden = true
      finishBreakButton.isHidden = true
      cancelPomodoroButton.isHidden = true
      markTaskAsCompletedButton.isHidden = true
      deleteTaskButton.isHidden = false
      showCompletedPomodorosButton.isHidden = false
    }
  }

  fileprivate func updateCompletedPomodorosLabel() {
    if pomodoroCount == 0 {
      completedPomodorosLabel.text = ""
    } else {
      let pomodorosText = pomodoroCount > 1 ? "pomodoros" : "pomodoro"
      completedPomodorosLabel.text = "\(pomodoroCount) \(pomodorosText) completed"
    }
  }

  // TODO: what happens when pomodoro finishes on background

  fileprivate func updateTimerLabel() {
    let minutes = Int(numberOfMinutes())
    let seconds = Int(numberOfSeconds())
    let secondsText = String(format: "%02d", seconds)

    DispatchQueue.main.async {
      self.timerLabel.text = "\(minutes):\(secondsText)"
    }
  }

  // MARK: - Timer

  fileprivate func startTimer() {
    print(#function)
    assert(timer == nil)

    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
      self.timerUpdate()
    }
  }

  fileprivate func timerUpdate() {
    currentTimeInSeconds -= 1
    if Int(currentTimeInSeconds) == 0 {
      stopTimer()
      if currentState == .pomodoroRunning {
        completePomodoro()
      } else {
        completeBreak()
      }
    }
  }

  fileprivate func stopTimer() {
    print(#function)
    if let timer = timer {
      timer.invalidate()
    }
    timer = nil
  }

  // MARK: - Sounds

  fileprivate func playBell() {
    guard let path = Bundle.main.path(forResource: "bell", ofType: "mp3") else {
      return
    }
    let url = URL(fileURLWithPath: path)

    do {
      player = try AVAudioPlayer(contentsOf: url)
      player.volume = 1.0
      player.currentTime = 0
      player.prepareToPlay()
      player.play()
      // Vibrate
      AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    } catch let error as NSError {
      print(error.localizedDescription)
    } catch {
      print("AVAudioPlayer init failed")
    }
  }

  // MARK: - Observers

  @objc func applicationWillResignActive(notification: Any) {
    // when app goes to background:
    //  - schedule local notification
    //    - break or pomodoro?
    //  - if pomodoro
    //    - store pomodoro completion for task in "UserDefaults"
    guard timer != nil else {
      return
    }

    print("")
    print(#function, "scheduling local notifications")

    let content = UNMutableNotificationContent()

    switch currentState {
    case .pomodoroRunning:
      content.title = "Pomodoro Done"
      content.body = "Good job"

      temporarilySavePomodoroForBackground()

    case .breakRunning:
      content.title = "Break Done"
      content.body = "Let's back to work"
    default:
      preconditionFailure("i should not try to schedule a notification for no timer")
    }

    content.sound = UNNotificationSound.default()
    let date = Date(timeIntervalSinceNow: currentTimeInSeconds)
    let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

    // Schedule the notification.
    let request = UNNotificationRequest(identifier: "pomodoro", content: content, trigger: trigger)
    let center = UNUserNotificationCenter.current()
    center.add(request, withCompletionHandler: nil)
  }

  @objc func applicationWillBecomeActive(notification: Any) {
    print(#function)
    // when the app goes to foreground
    //   Are there local notifications to be triggered?
    //     if so,
    //        cancel the local notification
    //        restore the timer with the remaining time
    //        remove the pending pomodoro completion for task in "UserDefaults"
    //        restore "break" or "pomodoro" mode.
    //   Are there pending completions for a pomodoro?
    //      if so, (it should be max there just 1)
    //        cancel the local timer
    //        execute the savePomodoro routine
    UNUserNotificationCenter.current().getPendingNotificationRequests { (notificationRequests) in
      assert(notificationRequests.count == 0 || notificationRequests.count == 1)

      if notificationRequests.count == 0 {
        self.checkForBackgroundSavedPomodoros()
      } else {
        self.cancelPendingTimerNotifications(withRequests: notificationRequests)
      }
    }

    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro"])
  }

  fileprivate func checkForBackgroundSavedPomodoros() {
    guard let tempSavedPomodoroData = temporarilySavedPomodorValue() else {
      return
    }

    assert(self.task != nil)

    DispatchQueue.main.async {
      print("saved pomodoro")
      self.stopTimer()
      self.lastTimerTimeInSeconds = tempSavedPomodoroData.remainingTime
      self.savePomodoro()
      self.pomodoroCount += 1
      self.currentState = .waiting
      self.cleanTemporarilySavedPomodoro()
    }
  }

  fileprivate func cancelPendingTimerNotifications(withRequests notificationRequests: [UNNotificationRequest]) {
    print("cancel pending notifications")
    notificationRequests.forEach({ (notification) in
      let trigger = notification.trigger as? UNCalendarNotificationTrigger
      if let trigger = trigger, let notificationDate = trigger.nextTriggerDate() {
        DispatchQueue.main.async {
          self.stopTimer()
          let secondsLeft = notificationDate.timeIntervalSinceNow
          self.currentTimeInSeconds = secondsLeft
          self.startTimer()
        }
        self.cleanTemporarilySavedPomodoro()
      }
    })
  }

  // MARK: - UserData temporal pomodoro storage

  fileprivate func temporarilySavedPomodorValue() -> (remainingTime: Double, taskID: String, currentState: String)? {
    let _currentTimeInSeconds = UserDefaults.standard.double(forKey: .lastTimerTimeInSecondsKey)

    guard let _timerState = UserDefaults.standard.string(forKey: .timerStateKey),
      let _taskID = UserDefaults.standard.string(forKey: .taskIDKey) else {
        print("no pomodoros completed")
        return nil
    }

    return (remainingTime: _currentTimeInSeconds, taskID: _taskID, currentState: _timerState)
  }

  // when the app goes to background I save the current pomodoro in a temporary way, so then when the app is active
  // again, the app will see if the pomodoro finished while the app was in background or not
  fileprivate func temporarilySavePomodoroForBackground() {
    guard let taskID = task?.id else {
      preconditionFailure("this value should be set if i am doing this")
    }
    UserDefaults.standard.set(lastTimerTimeInSeconds, forKey: .lastTimerTimeInSecondsKey)
    UserDefaults.standard.set(taskID, forKey: .taskIDKey)
    UserDefaults.standard.set(currentState.rawValue, forKey: .timerStateKey)
  }

  fileprivate func cleanTemporarilySavedPomodoro() {
    UserDefaults.standard.removeObject(forKey: .lastTimerTimeInSecondsKey)
    UserDefaults.standard.removeObject(forKey: .taskIDKey)
    UserDefaults.standard.removeObject(forKey: .timerStateKey)
  }
}
