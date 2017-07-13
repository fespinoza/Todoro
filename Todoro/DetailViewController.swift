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

  func configureView() {
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

  // MARK: - View Cycle

  override func viewDidLoad() {
    super.viewDidLoad()
    configureView()
  }

  // MARK: - IBActions

  @IBAction func addAMinuteToPomodoro(_ sender: Any) {
    var minutes = numberOfMinutes()
    minutes += 1

    timerLabel.text = "\(minutes):00"
  }

  @IBAction func removeAMinuteToPomodoro(_ sender: Any) {
    var minutes = numberOfMinutes()
    if minutes >= 1 {
      minutes -= 1
    }

    timerLabel.text = "\(minutes):00"
  }

  fileprivate func numberOfMinutes() -> Double {
    let timeParts = (timerLabel.text?.split(separator: ":"))!
    let minutesText = String(timeParts.first!)
    return Double(minutesText)!
  }

  fileprivate func numberOfSeconds() -> Double {
    let timeParts = (timerLabel.text?.split(separator: ":"))!
    let secondsText = String(timeParts.last!)
    return Double(secondsText)!
  }

  func updateTimer(numberOfSeconds: Double) {
    let minutes = Int(floor(numberOfSeconds / 60.0))
    let seconds = Int(numberOfSeconds.truncatingRemainder(dividingBy: 60.0))

    timerLabel.text = "\(minutes):\(seconds)"
  }

  @IBAction func startPomodoro(_ sender: Any) {
    currentState = .pomodoroRunning

    var countDown = numberOfMinutes() * 60 + numberOfSeconds()
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
      countDown -= 1
      self.updateTimer(numberOfSeconds: countDown)
      if countDown == 0 {

        timer.invalidate()
        self.currentState = .waiting
      }
    }
  }

  @IBAction func forcePomodoroCompletion(_ sender: Any) {
  }

  @IBAction func cancelPomodoro(_ sender: Any) {
  }

  @IBAction func markTaskAsCompleted(_ sender: Any) {
  }

  @IBAction func deleteTask(_ sender: Any) {
  }

}
