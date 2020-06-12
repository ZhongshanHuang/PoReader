# PoReader
本地小说阅读器，支持Wi-Fi传书，深色模式

###目录
1.首页
2.Wifi传书
3.阅读

#####首页
支持的功能
1.展示本地txt文件的书名、进度，最新看过的排在最前.长按进入编辑模式，可以删除不喜欢的书籍，支持多选<br/>
<img src="https://github.com/ZhongshanHuang/PoReader/raw/master/Snapshots/list.webp" width="30%" height="30%">
<img src="https://github.com/ZhongshanHuang/PoReader/raw/master/Snapshots/edition.webp" width="30%" height="30%">

#####Wifi传书
支持的功能
在电脑浏览器打开提示的地址，可以上传或删除txt文件
<img src="https://github.com/ZhongshanHuang/PoReader/raw/master/Snapshots/upload.webp" width="80%" height="80%">

#####阅读
支持的功能
打开时跳转到之前页码，仿真翻页，调整字体大小，进度跳转，退出页面或者app关闭页面时保存当前页码
PS：没有实现背景颜色自由更改是因为被我删掉了，背景颜色更改对我来说使用频率太低，暗黑模式对我来说体验更好<br/>
<img src="https://github.com/ZhongshanHuang/PoReader/raw/master/Snapshots/reader.webp" width="30%" height="30%">
<img src="https://github.com/ZhongshanHuang/PoReader/raw/master/Snapshots/scheme.webp" width="30%" height="30%">

每个小说阅读器可能有不同的显示样式，但是都无法避免最核心的部分---分页计算，一个txt文件可能会有几M或者十几M，如果直接将分页全部计算出来可能需要耗费十几秒甚至更多，不管你是将分页计算放在主线程还是子线程，都会导致用户等待很长时间才能看到文字显示。
    文字要被一页页地展示给用户，分页计算是无可避免的。既要进行分页计算，又要降低分页计算的耗时，只有采用懒加载，推迟不必要的计算，只计算马上需要展示给用户的分页。这儿的思想其实与计算机的虚拟内存管理类似

1.文本分割
    首先加载txt文件后对其进行切割，分割成一小段一小段的文本，这儿的切割标准有两类：
1）txt文件有章节划分，那我们就按章节来分割。(采用正则表达式分割)
2）有些txt文件就是一大团文字，没有划分标准。那我们按照固定字数来分割，这个固定的字数如何确定呢，需要自己测试，需要保证这段文字的分页计算耗时在用户无法察觉的范围

2.分页计算
    txt文本切割成一段一段后，我们先不进行分页计算，用户看到哪一段我们就对哪一段进行分页计算。
