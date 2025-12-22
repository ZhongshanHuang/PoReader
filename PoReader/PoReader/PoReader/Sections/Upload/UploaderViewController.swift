import UIKit
import GCDWebServerSPM

extension UploaderViewController {
    enum UploadType {
        case txt
        case audio
        
        var supportFormat: String {
            switch self {
            case .txt:
                "txt"
            case .audio:
                "mp3"
            }
        }
    }
}

class UploaderViewController: BaseViewController {
    let uploadType: UploadType
    
    private var webUploader: PoReaderWebUploader?
    private let hostLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    init(uploadType: UploadType) {
        self.uploadType = uploadType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
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
        webUploader?.allowedFileExtensions = [uploadType.supportFormat]
        webUploader?.prologue = "请将文件拖至下方方框，或者点击上传按钮，目前只支持\(uploadType.supportFormat)格式"
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
        do {
            try Database.shared.addBook(bookName)
        } catch {
            print("add book failure: \(error.localizedDescription)")
        }
    }
    
    /// 在浏览器端删除书本
    func webUploader(_ uploader: GCDWebUploader, didDeleteItemAtPath path: String) {
        let bookName = (path as NSString).lastPathComponent
        do {
            try Database.shared.removeBook(bookName)
        } catch {
            print("delete book failure: \(error.localizedDescription)")
        }
    }
}


class PoReaderWebUploader: GCDWebUploader {
    /**
     *  This method is called to check if a file upload is allowed to complete.
     *  The uploaded file is available for inspection at "tempPath".
     *
     *  The default implementation returns YES.
     */
//    override func shouldUploadFile(atPath path: String, withTemporaryFile tempPath: String) -> Bool {
//        return true
//    }

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
