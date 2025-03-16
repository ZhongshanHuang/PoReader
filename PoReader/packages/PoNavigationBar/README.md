# PoNavigationBar
单独控制每个UIViewController navigationBar的样式

# Environment
xcode: 11.4  
swift: 5.0

<img src="https://github.com/ZhongshanHuang/PoNavigationBar/raw/master/Asset/snapshot.gif" width="30%" height="30%">

# Usage
1、在didFinishLaunchingWithOptions时执行初始化PoNavigationBarConfigInit()</br>
2、让你的UINavigationController遵循PoNavigationBarConfigurable协议即可</br>
PoNavigationBarConfigurable协议有个defaultNavigationBarConfig属性，可以配置navigationBar全局默认的样式</br>
UIViewController，添加了navigationBarConfig属性，可以单独配置每个UIViewController下navigationBar的样式，不会干扰别的UIViewController
