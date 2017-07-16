//
//  DetailViewController.swift
//  Todoro
//
//  Created by Felipe Espinoza Castillo on 13/07/2017.
//  Copyright © 2017 Felipe Espinoza Castillo. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController {
  enum State {
    case waiting
    case pomodoroRunning
    case breakRunning
    case taskCompleted
  }

  var detailItem: Task?

  var currentState: State = .waiting {
    didSet { configureView() }
  }

  let oneMinute: Double = 60.0

  // 25 min by default - 30 for testing purposes
  let defaultPomodoroTimeInSeconds: Double = 25 * 60
  var currentTimeInSeconds: Double = 25 * 60 {
    didSet {
      updateTimerLabel()
    }
  }
  var lastTimerTimeInSeconds: Int?
  let defaultBreakTimeInSeconds: Double = 5 * 60

  var timer: Timer?

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

  // MARK: - View Cycle

  override func viewDidLoad() {
    super.viewDidLoad()

    if let task = detailItem {
      navigationItem.title = task.title

      currentState = task.isCompleted ? .taskCompleted : .waiting
    } else {
      configureView()
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let task = detailItem {
      pomodoroCount = task.pomodoros?.count ?? 0
    }
  }

  // MARK: - IBActions

  @IBAction func addAMinuteToPomodoro(_ sender: Any) {
    currentTimeInSeconds += oneMinute
  }

  @IBAction func removeAMinuteToPomodoro(_ sender: Any) {
    if currentTimeInSeconds >= 1 {
      currentTimeInSeconds -= oneMinute
    }
  }

  @IBAction func startPomodoro(_ sender: Any) {
    currentState = .pomodoroRunning
    startTimer()
  }

  @IBAction func forcePomodoroCompletion(_ sender: Any) {
    stopTimer()
    completePomodoro()
  }

  @IBAction func cancelPomodoro(_ sender: Any) {
    stopTimer()
    currentTimeInSeconds = defaultPomodoroTimeInSeconds
    currentState = .waiting
  }
  
  @IBAction func finishBreak(_ sender: Any) {
    cancelPomodoro(sender)
  }

  @IBAction func markTaskAsCompleted(_ sender: Any) {
    detailItem?.isCompleted = true
    (UIApplication.shared.delegate as? AppDelegate)!.saveContext()
    currentState = .taskCompleted

    // TODO: go back to the master view controller (only in compact mode i guess)
    if let navigationVC = self.splitViewController?.viewControllers.first as? UINavigationController {
      navigationVC.popToRootViewController(animated: true)
    }
  }

  @IBAction func deleteTask(_ sender: Any) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let task = detailItem else {
      return
    }

    let alertController = UIAlertController(title: "Deleting Task", message: "Are you sure you want to delete the task?", preferredStyle: .alert)
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

  fileprivate func numberOfMinutes() -> Double {
    return floor(currentTimeInSeconds / oneMinute)
  }

  fileprivate func numberOfSeconds() -> Double {
    return currentTimeInSeconds.truncatingRemainder(dividingBy: oneMinute)
  }

  fileprivate func completePomodoro() {
    pomodoroCount += 1

    savePomodoro()

    let alertController = UIAlertController(
      title: "Pomodoro Finished",
      message: "Good job completing the pomodoro, what do you want to do next?",
      preferredStyle: .alert
    )

    let breakButton = UIAlertAction(title: "Break", style: .default) { (action) in
      self.currentState = .breakRunning
      self.currentTimeInSeconds = self.defaultBreakTimeInSeconds
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
    let alertController = UIAlertController(
      title: "Break Finished",
      message: "Do you want to work during another pomodoro?",
      preferredStyle: .alert
    )

    let breakButton = UIAlertAction(title: "Sure", style: .default) { (action) in
      self.currentState = .pomodoroRunning
      self.currentTimeInSeconds = self.defaultPomodoroTimeInSeconds
      self.startTimer()
    }
    alertController.addAction(breakButton)

    let cancelButton = UIAlertAction(title: "Done", style: .cancel) { (action) in
      self.currentState = .waiting
    }
    alertController.addAction(cancelButton)

    self.present(alertController, animated: true, completion: nil)
  }

  func savePomodoro() {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let task = detailItem,
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
      // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
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
      currentTimeInSeconds = defaultPomodoroTimeInSeconds
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
    case .breakRunning:
      addMinutesButton.isHidden = true
      removeMinutesButton.isHidden = true

      startPomodoroButton.isHidden = true
      forcePomodoroCompletionButton.isHidden = true
      finishBreakButton.isHidden = false
      cancelPomodoroButton.isHidden = true
      markTaskAsCompletedButton.isHidden = true
      deleteTaskButton.isHidden = true

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

  fileprivate func updateTimerLabel() {
    let minutes = Int(numberOfMinutes())
    let seconds = Int(numberOfSeconds())
    let secondsText = String(format: "%02d", seconds)

    timerLabel.text = "\(minutes):\(secondsText)"
  }

  // MARK: - Timer

  fileprivate func startTimer() {
    lastTimerTimeInSeconds = Int(currentTimeInSeconds)
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (_) in
      self.timerUpdate()
    }
  }

  fileprivate func timerUpdate() {
    currentTimeInSeconds -= 1
    if currentTimeInSeconds == 0 {
      stopTimer()
      if currentState == .pomodoroRunning {
        completePomodoro()
      } else {
        completeBreak()
      }
    }
  }

  fileprivate func stopTimer() {
    if let timer = timer {
      timer.invalidate()
    }
  }
}
