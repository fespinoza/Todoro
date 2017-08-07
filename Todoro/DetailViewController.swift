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

private extension String {
  static let showCompletedPomodoros = "showCompletedPomodoros"
}

class DetailViewController: UIViewController {
  private struct Default {
    static let oneMinute: Double = 60.0
    static let testTimerInSeconds = oneMinute
    static let pomodoroTimerInSeconds = 25 * oneMinute
    static let breakTimerInSecords = 5 * oneMinute
  }

  enum State {
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
  var currentTimeInSeconds = Default.pomodoroTimerInSeconds {
    didSet {
      updateTimerLabel()
    }
  }
  var lastTimerTimeInSeconds: Int?
  var timer: Timer?
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

  override func viewDidLoad() {
    super.viewDidLoad()

    if let task = task {
      setPomodoroTimeValueInSeconds()
      currentState = task.isCompleted ? .taskCompleted : .waiting
    } else {
      configureView()
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

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
    if currentTimeInSeconds > Default.oneMinute {
      currentTimeInSeconds -= Default.oneMinute
    }
  }

  @IBAction func startPomodoro(_ sender: Any) {
    currentState = .pomodoroRunning
    lastTimerTimeInSeconds = Int(currentTimeInSeconds)
    startTimer()
  }

  @IBAction func forcePomodoroCompletion(_ sender: Any) {
    stopTimer()
    completePomodoro()
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
      self.currentTimeInSeconds = Double(self.lastTimerTimeInSeconds!)
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
}
