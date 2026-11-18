rootProject.name = "tapmc-backend"

// 后端四个模块，依赖方向单向向下，不允许反向引用：
//   server  -> core -> mod
//   server  -> protocol
//   core    -> protocol
// protocol 与 mod 不依赖任何兄弟模块。
include("protocol")
include("mod")
include("core")
include("server")
