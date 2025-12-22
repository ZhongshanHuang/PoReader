import UIKit

final class ReversePageReaderDisplayItem: UIViewController {
    /// 章节索引
    var chapterIndex: Int = -1
    /// 章节内部分页索引
    var subrangeIndex: Int = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.readerBackgroundColor
    }
    
}
