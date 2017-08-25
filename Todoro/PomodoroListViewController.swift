//
//  PomodoroListViewController.swift
//  Todoro
//
//  Created by Felipe Espinoza Castillo on 01/08/2017.
//  Copyright © 2017 Felipe Espinoza Castillo. All rights reserved.
//

import UIKit

private extension String {
  static let pomodoroCell = "pomodoroCell"
}

class PomodoroListViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!

  var task: Task?
  var pomodoros: [Pomodoro] = [Pomodoro]()

  lazy var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short
    return dateFormatter
  }()

  // MARK: - View lifecycle

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let task = task {
      navigationItem.title = task.title
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.dataSource = self
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  /*
   // MARK: - Navigation

   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
   // Get the new view controller using segue.destinationViewController.
   // Pass the selected object to the new view controller.
   }
   */

  func formatDuration(forPomodoro pomodoro: Pomodoro) -> String {
    return String(format: "%d min", Int(pomodoro.duration / 60.0))
  }
}

extension PomodoroListViewController: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return pomodoros.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: .pomodoroCell, for: indexPath)

    let pomodoro = pomodoros[indexPath.row]
    guard let completionTime = pomodoro.completionTime else {
      preconditionFailure("there should have been a completion time in here")
    }

    cell.textLabel?.text = dateFormatter.string(from: completionTime)
    cell.detailTextLabel?.text = formatDuration(forPomodoro: pomodoro)

    return cell
  }
}
