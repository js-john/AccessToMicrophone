//
//  ViewController.swift
//  Access
//
//  Created by John Smith on 2020/9/2.
//  Copyright © 2020 John Smith. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var sipStatusLabel: NSTextField!
    @IBOutlet weak var appTableView: NSTableView!
    @IBOutlet weak var applicationIconImageView: NSImageView!
    @IBOutlet weak var applicationNameLabel: NSTextField!
    
    var appList: [[String]] = [];
    let appTableViewCellIdentifier = "AppTableViewCell";
    var selectedIndex = -1;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appList = []
        appTableView.delegate = self;
        appTableView.dataSource = self;
        
        let sipStatusEnable = shell("csrutil status").contains("enabled");
        if (sipStatusEnable) {
            sipStatusLabel.stringValue = NSLocalizedString("SIP enabled description", comment: "")
            sipStatusLabel.textColor = NSColor.init(calibratedRed: 1, green: 0, blue: 0, alpha: 1);
        } else {
            sipStatusLabel.stringValue = NSLocalizedString("SIP disabled description", comment: "");
            sipStatusLabel.textColor = NSColor.init(calibratedRed: 25.0/255, green: 200.0/255, blue: 50.0/255, alpha: 1);
        }
        
        let defaults = UserDefaults.standard;
        let storedArray = defaults.array(forKey: "APPLIST");
        if (storedArray != nil && storedArray?.count != 0) {
            appList = storedArray as! [[String]];
            appTableView.reloadData();
            appTableView.selectRowIndexes(IndexSet.init(integer: 0), byExtendingSelection: false);
            selectedIndex = 0;
            refresh()
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.appList.count;
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var image: NSImage?
        var text: String = ""
        //拿到模型中的数据存到item中
        let item = self.appList[row];
        text = item[0]
        let imagePath = item[1];
        
        image = NSImage.init(byReferencingFile: imagePath)
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: appTableViewCellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            return cell
        }
        return nil
    }
    
    func refresh() {
        let item = self.appList[selectedIndex];
        let appName = item[0];
        let imagePath = item[1];
        let image = NSImage.init(byReferencingFile: imagePath);
        if (image != nil) {
            self.applicationIconImageView.image = image;
        }
        self.applicationNameLabel.stringValue = appName;
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        self.selectedIndex = row;
        refresh();
        return true;
    }
    
    func addAppWithPath(path: String) {
        let fileManager = FileManager.default;
        //check if Info.plist exsist
        let infoPlistPath = "\(path)/Contents/Info.plist";
        let isApp = fileManager.fileExists(atPath: infoPlistPath);
        if (!isApp) {
            alert(msg: NSLocalizedString("No an app", comment: ""), description: NSLocalizedString("Error", comment: ""));
            return;
        }
        guard let infoPlist = NSDictionary.init(contentsOfFile: infoPlistPath) else {
            alert(msg: NSLocalizedString("Info.plist broken", comment: ""), description: NSLocalizedString("Error", comment: ""))
            return;
        };
                
        let bundleId = infoPlist["CFBundleIdentifier"] as? String ?? "unknown";
        let appName = infoPlist["CFBundleName"] as? String ?? infoPlist["CFBundleExecutable"] as? String ?? NSLocalizedString("Unknown App Name", comment: "");
        var iconPath = infoPlist["CFBundleIconFile"] as? String ?? "";
        if !iconPath.contains(".icns") {
            iconPath += ".icns";
        }
        self.appList.append([appName, "\(path)/Contents/Resources/\(iconPath)", bundleId]);
        self.appTableView.reloadData();
        
        let defaults = UserDefaults.standard;
        defaults.setValue(appList, forKey: "APPLIST");
    }
    
    
    func alert(msg: String, description: String) {
        let alert = NSAlert.init();
        alert.addButton(withTitle: "OK");
        alert.alertStyle = .critical;
        alert.informativeText = description;
        alert.messageText = msg;
        alert.runModal();
    }
    
    func shell(_ command: String) -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        return output
    }
    
    
    
    @IBAction func addApplication(_ sender: NSButton) {
        let dialog = NSOpenPanel();
        
        dialog.title                   = NSLocalizedString("Select App dialog title", comment: "");
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false;
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            guard let url = dialog.url else {
                return;
            }
            addAppWithPath(path: url.path);
            return;
        } else {
            return;
        }
    }
    @IBAction func resetMicrophonePermission(_ sender: NSButton) {
        let _ = shell("tccutil reset Microphone");
    }
    @IBAction func forceOpenMicrophonePermission(_ sender: NSButton) {
        if (selectedIndex < 0 || selectedIndex >= appList.count) {
            return;
        }
        let bundleId = self.appList[selectedIndex][2];
        let appName = self.appList[selectedIndex][0];
        let command = "sqlite3 ~/Library/Application\\ Support/com.apple.TCC/TCC.db \"INSERT or REPLACE INTO access VALUES('kTCCServiceMicrophone','\(bundleId)',0,1,1,NULL,NULL,NULL,'UNUSED',NULL,0,1577992126);\"";
        _ = shell(command)
        alert(msg: NSLocalizedString("Success", comment: ""), description: String.init(format: NSLocalizedString("Restart App hint", comment: ""), appName));
    }
}

