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
  }

  var detailItem: Task?

  var currentState: State = .waiting {
    didSet { configureView() }
  }

  let oneMinute: Double = 60.0

  // 25 min by default - 30 for testing purposes
  let defaultPomodoroTimeInSeconds: Double = 30
  var currentTimeInSeconds: Double = 30 {
    didSet {
      updateTimerLabel()
    }
  }
  let defaultBreakTimeInSeconds: Double = 10

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
    configureView()
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
    // TODO
  }

  @IBAction func deleteTask(_ sender: Any) {
    // TODO
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

  // MARK: - View Logic

  fileprivate func configureView() {
    updateCompletedPomodorosLabel()
    updateTimerLabel()

    switch currentState {
    case .waiting:
      currentTimeInSeconds = defaultPomodoroTimeInSeconds

      addMinutesButton.isHidden = false
      removeMinutesButton.isHidden = false

      startPomodoroButton.isHidden = false
      forcePomodoroCompletionButton.isHidden = true
      finishBreakButton.isHidden = true
      cancelPomodoroButton.isHidden = true
      markTaskAsCompletedButton.isHidden = false
      deleteTaskButton.isHidden = false
    case .pomodoroRunning:
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
