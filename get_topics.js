const fs = require('fs');

// 读取前100条结果
const top100 = JSON.parse(fs.readFileSync('github_100_launchers.json', 'utf8'));

// 提取话题
const topics = {};
top100.forEach(item => {
  if (item.name === 'PrismLauncher' || item.name === 'HMCL' || item.name === 'PCL') {
    // 获取这些热门项目的详细信息
    console.log(`${item.name}: Stars=${item.stars}, Forks=${item.forks}`);
  }
});

// 热门话题关键词
const keywords = [
  'minecraft', 'launcher', 'mod', 'instance', 'java', 
  'android', 'windows', 'macos', 'linux', 'modrinth',
  'curseforge', 'fabric', 'forge', 'neoforge'
];

console.log('\n=== 热门功能关键词 ===');
keywords.forEach(kw => {
  const count = top100.filter(i => 
    (i.name.toLowerCase().includes(kw) || 
     (i.description && i.description.toLowerCase().includes(kw)))
  ).length;
  if (count > 0) {
    console.log(`${kw}: ${count} 个项目`);
  }
});

// 核心功能列表
console.log('\n=== TapMC 应该支持的核心功能 ===');
const features = [
  { name: '多实例管理', importance: 'P0', desc: '创建/删除/重命名实例' },
  { name: '模组管理', importance: 'P0', desc: '启用/禁用模组、检测加载器' },
  { name: 'Java 运行时管理', importance: 'P0', desc: '自动探测/管理 Java 版本' },
  { name: '模组下载', importance: 'P1', desc: 'Modrinth/CurseForge 集成' },
  { name: '游戏启动', importance: 'P0', desc: 'Java 进程管理、日志流式传输' },
  { name: '实时日志', importance: 'P1', desc: '游戏运行时日志查看' },
  { name: '下载管理器', importance: 'P1', desc: '多线程下载、断点续传' },
  { name: '暗色主题', importance: 'P2', desc: 'Material 3 配色方案' },
  { name: '动画效果', importance: 'P2', desc: '页面过渡、骨架屏' },
  { name: '跨平台支持', importance: 'P0', desc: 'Android/iOS/Windows/macOS/Linux/Web' }
];

features.forEach(f => {
  console.log(`${f.importance}: ${f.name} - ${f.desc}`);
});
