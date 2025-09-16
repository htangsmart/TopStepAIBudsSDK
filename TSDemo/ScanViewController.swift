//
//  ScanViewController.swift
//  TSDemo
//
//  Created by luigi on 2025/9/12.
//

import UIKit
import CoreBluetooth
import TopStepAIBudsSDK

final class ScanViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var devices: [TSDeviceBaseInfo] = []
    private var peripheralByUUID: [String: CBPeripheral] = [:]

    var onSelect: ((TSDeviceBaseInfo, CBPeripheral?) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Select Device"
        view.backgroundColor = .systemBackground

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Stop", style: .plain, target: self, action: #selector(stopScan))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TopStepAIBuds.stopScan()
    }

    @objc private func stopScan() {
        TopStepAIBuds.stopScan()
    }

    private func startScan() {
        devices.removeAll()
        peripheralByUUID.removeAll()
        tableView.reloadData()

        TopStepAIBuds.scanDevice { [weak self] error, deviceInfo, peripheral in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.showError(error)
                }
                return
            }
            guard let info = deviceInfo else { return }
            if self.devices.contains(where: { $0.uuid == info.uuid }) == false {
                self.devices.append(info)
            } else {
                if let index = self.devices.firstIndex(where: { $0.uuid == info.uuid }) {
                    self.devices[index] = info
                }
            }
            if let p = peripheral { self.peripheralByUUID[info.uuid] = p }
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    private func showError(_ error: NSError) {
        let alert = UIAlertController(title: "Scan Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let info = devices[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = info.name
        content.secondaryText = "UUID: \(info.uuid)"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let info = devices[indexPath.row]
        let peripheral = peripheralByUUID[info.uuid]
        onSelect?(info, peripheral)
        dismiss(animated: true)
    }
}


