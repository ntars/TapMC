const fs = require('fs');
const https = require('https');

// 读取前100条结果
const top100 = JSON.parse(fs.readFileSync('github_100_launchers.json', 'utf8'));

// 提取唯一的语言和话题
const languages = {};
const topics = {};

top100.forEach(item => {
  if (item.language) languages[item.language] = (languages[item.language] || 0) + 1;
  if (item.topics) {
    item.topics.forEach(topic => {
      topics[topic] = (topics[topic] || 0) + 1;
    });
  }
});

// 输出分析结果
console.log('=== 我的世界启动器语言分布 ===');
Object.entries(languages).sort((a, b) => b[1] - a[1]).forEach(([lang, count]) => {
  console.log(`${lang}: ${count} 个项目`);
});

console.log('\n=== 热门话题 Top 20 ===');
Object.entries(topics)
  .sort((a, b) => b[1] - a[1])
  .slice(0, 20)
  .forEach(([topic, count]) => {
    console.log(`${topic}: ${count}`);
  });

// 分析热门启动器的核心功能
console.log('\n=== 热门启动器核心功能分析 ===');
const popularLaunchers = [
  { rank: 1, name: 'PrismLauncher', keyFeatures: ['MultiMC fork', 'Qt GUI', 'Mod support'] },
  { rank: 2, name: 'HMCL', keyFeatures: ['Cross-platform', 'Modpack support', 'Java version manager'] },
  { rank: 3, name: 'PCL', keyFeatures: ['Chinese UI', 'Instance management', 'Mod download'] },
  { rank: 4, name: 'PojavLauncher', keyFeatures: ['Android/iOS', 'Boardwalk', 'Java Edition'] },
  { rank: 5, name: 'FoldCraftLauncher', keyFeatures: ['Android only', 'Simple UI'] },
  { rank: 6, name: 'Launcher (MultiMC)', keyFeatures: ['Multiple instances', 'Custom profiles'] },
  { rank: 10, name: 'x-minecraft-launcher', keyFeatures: ['Disk efficient', 'Mod management'] },
  { rank: 15, name: 'HeliosLauncher', keyFeatures: [' Electron', 'Modded support'] }
];

popularLaunchers.forEach(l => {
  console.log(`${l.rank}. ${l.name}`);
  l.keyFeatures.forEach(f => console.log(`   - ${f}`));
});
