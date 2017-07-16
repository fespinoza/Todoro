//
//  MasterViewController.swift
//  Todoro
//
//  Created by Felipe Espinoza Castillo on 13/07/2017.
//  Copyright © 2017 Felipe Espinoza Castillo. All rights reserved.
//

import UIKit
import CoreData

class MasterViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  var detailViewController: DetailViewController? = nil
  var managedObjectContext: NSManagedObjectContext? = nil

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    //    navigationItem.leftBarButtonItem = editButtonItem

    let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(displayNewTaskUI(_:)))
    navigationItem.rightBarButtonItem = addButton
    if let split = splitViewController {
      let controllers = split.viewControllers
      detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }

    if #available(iOS 11.0, *) {
      navigationItem.largeTitleDisplayMode = .always
    } else {
      // Fallback on earlier versions
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
    super.viewWillAppear(animated)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @objc func displayNewTaskUI(_ sender: Any) {
    let alertController = UIAlertController(title: "Create New Task", message: nil, preferredStyle: .alert)

    alertController.addTextField { (textField) in
      textField.placeholder = "Task name"
    }

    alertController.addAction(UIAlertAction(title: "Create", style: .default) { (action) in
      if let title = alertController.textFields?.first?.text {
        self.insertNewObject(taskTitle: title)
      }
    })

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

    present(alertController, animated: true, completion: nil)
  }

  func insertNewObject(taskTitle: String) {
    let context = self.fetchedResultsController.managedObjectContext
    let newTask = Task(context: context)

    // If appropriate, configure the new managed object.
    newTask.createdAt = Date()
    newTask.title = taskTitle
    newTask.id = UUID().uuidString

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

  // MARK: - Segues

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showDetail" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let object = fetchedResultsController.object(at: indexPath)
        let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
        controller.detailItem = object
        controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        controller.navigationItem.leftItemsSupplementBackButton = true
      }
    }
  }

  // MARK: - Table View

  override func numberOfSections(in tableView: UITableView) -> Int {
    return fetchedResultsController.sections?.count ?? 0
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController.sections![section]
    return sectionInfo.numberOfObjects
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    let task = fetchedResultsController.object(at: indexPath)
    configureCell(cell, withTask: task)
    return cell
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return true
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let context = fetchedResultsController.managedObjectContext
      context.delete(fetchedResultsController.object(at: indexPath))

      do {
        try context.save()
      } catch {
        // Replace this implementation with code to handle the error appropriately.
        // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        let nserror = error as NSError
        fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
      }
    }
  }

  func configureCell(_ cell: UITableViewCell, withTask task: Task) {
    if task.isCompleted {
      let mutableAttributedString = NSMutableAttributedString(string: task.title!)
      let fullRange = NSMakeRange(0, mutableAttributedString.string.count)
      mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.gray, range: fullRange)
      mutableAttributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.styleSingle.rawValue, range: fullRange)
      mutableAttributedString.addAttribute(.strikethroughColor, value: UIColor.gray, range: fullRange)
      cell.textLabel?.attributedText = mutableAttributedString
    } else {
      cell.textLabel!.text = task.title
    }

    cell.detailTextLabel?.text = "\(task.pomodoros?.count ?? 0)"
  }

  // MARK: - Fetched results controller

  var fetchedResultsController: NSFetchedResultsController<Task> {
    if _fetchedResultsController != nil {
      return _fetchedResultsController!
    }

    let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()

    // Set the batch size to a suitable number.
    fetchRequest.fetchBatchSize = 20

    // Edit the sort key as appropriate.
    let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)

    fetchRequest.sortDescriptors = [sortDescriptor]

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Master")
    aFetchedResultsController.delegate = self
    _fetchedResultsController = aFetchedResultsController

    do {
      try _fetchedResultsController!.performFetch()
    } catch {
      // Replace this implementation with code to handle the error appropriately.
      // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
      let nserror = error as NSError
      fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
    }

    return _fetchedResultsController!
  }    
  var _fetchedResultsController: NSFetchedResultsController<Task>? = nil

  func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.beginUpdates()
  }

  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
    switch type {
    case .insert:
      tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
    case .delete:
      tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
    default:
      return
    }
  }

  func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
    switch type {
    case .insert:
      tableView.insertRows(at: [newIndexPath!], with: .fade)
    case .delete:
      tableView.deleteRows(at: [indexPath!], with: .fade)
    case .update:
      configureCell(tableView.cellForRow(at: indexPath!)!, withTask: anObject as! Task)
    case .move:
      configureCell(tableView.cellForRow(at: indexPath!)!, withTask: anObject as! Task)
      tableView.moveRow(at: indexPath!, to: newIndexPath!)
    }
  }

  func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
    tableView.endUpdates()
  }

  /*
   // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
   
   func controllerDidChangeContent(controller: NSFetchedResultsController) {
   // In the simplest, most efficient, case, reload the table view.
   tableView.reloadData()
   }
   */

}

