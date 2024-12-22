//
//  TaskListsViewController.swift
//  RealmApp
//
//  Created by Alexey Efimov on 02.07.2018.
//  Copyright © 2018 Alexey Efimov. All rights reserved.
//

import UIKit
import RealmSwift

final class TaskListViewController: UITableViewController {
    @IBOutlet weak var sortListSegment: UISegmentedControl!
    
    private var taskLists: Results<TaskList>!
    private let storageManager = StorageManager.shared
    private let dataManager = DataManager.shared
    
    private var sortedTaskLists: Results<TaskList> {
        switch sortListSegment.selectedSegmentIndex {
        case 0:
            return taskLists.sorted(byKeyPath: "date")
        case 1:
            return taskLists.sorted(byKeyPath: "title")
        default:
            return taskLists
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonPressed)
        )
        
        taskLists = storageManager.fetchData(TaskList.self)
        createTempData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
            
    @IBAction func sortingList(_ sender: UISegmentedControl) {
        tableView.reloadData()
    }
    
    @objc private func addButtonPressed() {
        showAlert()
    }
    
    private func createTempData() {
        if !UserDefaults.standard.bool(forKey: "done") {
            dataManager.createTempData { [unowned self] in
                UserDefaults.standard.setValue(true, forKey: "done")
                tableView.reloadData()
            }
        }
    }
}

// MARK: - UITableViewDelegate
extension TaskListViewController {
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let taskList = sortedTaskLists[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [unowned self] _, _, isDone in
            storageManager.delete(taskList)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
        
        let editAction = UIContextualAction(style: .normal, title: "Edit") { [unowned self] _, _, isDone in
            showAlert(with: taskList) {
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
            isDone(true)
        }
        
        let doneAction = UIContextualAction(style: .normal, title: "Done") { [unowned self] _, _, isDone in
            storageManager.done(taskList)
            isDone(true)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        editAction.backgroundColor = .systemOrange
        doneAction.backgroundColor = .systemGreen
        
        // Тут скорее всего лучше если задач нет или все выполнены -
        // вернуть UISwipeActionsConfiguration(actions: [editAction, deleteAction]) без doneAction
        return UISwipeActionsConfiguration(actions: [doneAction, editAction, deleteAction])
    }
}

// MARK: - UITableViewDataSource
extension TaskListViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        taskLists.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskListCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        let taskList = sortedTaskLists[indexPath.row]
        content.text = taskList.title
        
        let incompleteTasks = taskList.tasks.filter("isComplete = false")
        
        // Возможно тут accessoryType можно указать как-то по другому. но при смене состояния остается checkmark
        // и приходится назначать на nil в других кейсах
        if taskList.tasks.isEmpty {
            content.secondaryText = 0.formatted()
            cell.accessoryType = .none
        } else if incompleteTasks.isEmpty {
            content.secondaryText = nil
            cell.accessoryType = .checkmark
        } else {
            content.secondaryText = incompleteTasks.count.formatted()
            cell.accessoryType = .none
        }
           
        cell.contentConfiguration = content
        return cell
    }
}

// MARK: - Navigation
extension TaskListViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = tableView.indexPathForSelectedRow else { return }
        guard let tasksVC = segue.destination as? TasksViewController else { return }

        let taskList = sortedTaskLists[indexPath.row]
        tasksVC.taskList = taskList
    }
}

// MARK: - AlertController
extension TaskListViewController {
    private func showAlert(with taskList: TaskList? = nil, completion: (() -> Void)? = nil) {
        let alertBuilder = AlertControllerBuilder(
            title: taskList != nil ? "Edit List" : "New List",
            message: "Please set title for new task list"
        )
        
        alertBuilder
            .setTextField(withPlaceholder: "List Title", andText: taskList?.title)
            .addAction(title: taskList != nil ? "Update List" : "Save List", style: .default) { [unowned self] newValue, _ in
                if let taskList, let completion {
                    storageManager.edit(taskList, newValue: newValue)
                    completion()
                    return
                }
                
                createTaskList(withTitle: newValue)
            }
            .addAction(title: "Cancel", style: .destructive)
        
        let alertController = alertBuilder.build()
        present(alertController, animated: true)
    }
    
    private func createTaskList(withTitle title: String) {
        storageManager.save(title) { taskList in
            let rowIndex = IndexPath(row: sortedTaskLists.index(of: taskList) ?? 0, section: 0)
            tableView.insertRows(at: [rowIndex], with: .automatic)
        }
    }
}
