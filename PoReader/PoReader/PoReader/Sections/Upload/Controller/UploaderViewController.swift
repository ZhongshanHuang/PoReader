//
//  UploaderViewController.swift
//  PoReader
//
//  Created by 黄中山 on 2020/5/21.
//  Copyright © 2020 potato. All rights reserved.
//

import UIKit
import GCDWebServerSPM

class UploaderViewController: BaseViewController {
    
    private var webUploader: PoReaderWebUploader?
    private lazy var hostLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
        startUploadServer()
    }
    
    private func setupUI() {
        title = "书本上传"
        
        view.addSubview(hostLabel)
        hostLabel.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
    }
    
    private func startUploadServer() {
        webUploader = PoReaderWebUploader(uploadDirectory: Constants.localBookDirectory)
        webUploader?.prologue = "请将书本拖至下方方框，或者点击上传按钮，目前只支持txt格式"
        webUploader?.delegate = self
        webUploader?.start(withPort: 80, bonjourName: "Reader Uploader Server")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let attributedStr = NSMutableAttributedString(string: "请确保手机和电脑在同一wifi下，在电脑浏览器上打开如下地址: \n", attributes: [.font: UIFont.systemFont(ofSize: 17)])
        let ipStr = NSAttributedString(string: "\(webUploader?.serverURL?.host ?? "无效地址")", attributes: [.font: UIFont.systemFont(ofSize: 20), .foregroundColor: UIColor.systemBlue])
        attributedStr.append(ipStr)
        hostLabel.attributedText = attributedStr
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        webUploader?.stop()
    }
    
}

// MARK: - GCDWebUploaderDelegate

extension UploaderViewController: GCDWebUploaderDelegate {
    
    /// 将上传的书本信息存入本地数据库
    func webUploader(_ uploader: GCDWebUploader, didUploadFileAtPath path: String) {
        let bookName = (path as NSString).lastPathComponent
        Database.shared.addBook(bookName)
    }
    
    /// 在浏览器端删除书本
    func webUploader(_ uploader: GCDWebUploader, didDeleteItemAtPath path: String) {
        let bookName = (path as NSString).lastPathComponent
        Database.shared.removeBook(bookName)
    }
}


class PoReaderWebUploader: GCDWebUploader {
    /**
     *  This method is called to check if a file upload is allowed to complete.
     *  The uploaded file is available for inspection at "tempPath".
     *
     *  The default implementation returns YES.
     */
    /// 只允许上传txt格式文件
    override func shouldUploadFile(atPath path: String, withTemporaryFile tempPath: String) -> Bool {
        return (path as NSString).pathExtension.uppercased() == "TXT"
    }

    /**
     *  This method is called to check if a file or directory is allowed to be moved.
     *
     *  The default implementation returns YES.
     */
    override func shouldMoveItem(fromPath: String, toPath: String) -> Bool {
        return false
    }

    /**
     *  This method is called to check if a file or directory is allowed to be deleted.
     *
     *  The default implementation returns YES.
     */
//    override func shouldDeleteItem(atPath path: String) -> Bool {
//        return false
//    }

    /**
     *  This method is called to check if a directory is allowed to be created.
     *
     *  The default implementation returns YES.
     */
    override func shouldCreateDirectory(atPath path: String) -> Bool {
        return false
    }

}
