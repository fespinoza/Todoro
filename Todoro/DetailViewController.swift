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

  // 25 min by default
  let defaultPomodoroTimeInSeconds: Double = 30
  var currentPomodoroTimeInSeconds: Double = 30 // seconds for test purposes

  var timer: Timer?

  // temp
  var pomodoroCount = 0

  // MARK: - IBOutlets
  @IBOutlet weak var completedPomodorosLabel: UILabel!
  @IBOutlet weak var timerLabel: UILabel!

  @IBOutlet weak var addMinutesButton: UIButton!
  @IBOutlet weak var removeMinutesButton: UIButton!

  @IBOutlet weak var startPomodoroButton: UIButton!
  @IBOutlet weak var forcePomodoroCompletionButton: UIButton!
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
    currentPomodoroTimeInSeconds += oneMinute
    updateTimerLabel()
  }

  @IBAction func removeAMinuteToPomodoro(_ sender: Any) {
    currentPomodoroTimeInSeconds -= oneMinute
    updateTimerLabel()
  }

  @IBAction func startPomodoro(_ sender: Any) {
    currentState = .pomodoroRunning

    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
      self.currentPomodoroTimeInSeconds -= 1
      self.updateTimerLabel()
      if self.currentPomodoroTimeInSeconds == 0 {
        timer.invalidate()
        self.completePomodoro()
      }
    }
  }

  @IBAction func forcePomodoroCompletion(_ sender: Any) {
    if let timer = timer {
      timer.invalidate()
    }
    completePomodoro()
  }

  @IBAction func cancelPomodoro(_ sender: Any) {
    if let timer = timer {
      timer.invalidate()
    }
    currentPomodoroTimeInSeconds = defaultPomodoroTimeInSeconds
    currentState = .waiting
  }

  @IBAction func markTaskAsCompleted(_ sender: Any) {
  }

  @IBAction func deleteTask(_ sender: Any) {
  }

  // MARK: - Business Logic

  fileprivate func numberOfMinutes() -> Double {
    return floor(currentPomodoroTimeInSeconds / oneMinute)
  }

  fileprivate func numberOfSeconds() -> Double {
    return currentPomodoroTimeInSeconds.truncatingRemainder(dividingBy: oneMinute)
  }

  fileprivate func completePomodoro() {
    pomodoroCount += 1
    currentPomodoroTimeInSeconds = defaultPomodoroTimeInSeconds
    currentState = .waiting
  }

  // MARK: - View Logic

  fileprivate func configureView() {
    updateCompletedPomodorosLabel()
    updateTimerLabel()

    switch currentState {
    case .waiting:
      addMinutesButton.isHidden = false
      removeMinutesButton.isHidden = false

      startPomodoroButton.isHidden = false
      forcePomodoroCompletionButton.isHidden = true
      cancelPomodoroButton.isHidden = true
      markTaskAsCompletedButton.isHidden = false
      deleteTaskButton.isHidden = false
    case .pomodoroRunning:
      addMinutesButton.isHidden = true
      removeMinutesButton.isHidden = true

      startPomodoroButton.isHidden = true
      forcePomodoroCompletionButton.isHidden = false
      cancelPomodoroButton.isHidden = false
      markTaskAsCompletedButton.isHidden = true
      deleteTaskButton.isHidden = true
    case .breakRunning:
      break
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
}
