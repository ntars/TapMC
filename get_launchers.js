const https = require('https');
const fs = require('fs');

// 获取 20 个我的世界启动器项目
const query = 'minecraft launcher in:name,description';
const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(query)}&sort=stars&order=desc&per_page=20`;

https.get(url, { headers: { 'User-Agent': 'TapMC', 'Accept': 'application/vnd.github.v3+json' } }, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      console.log(`Total count: ${json.total_count}`);
      
      const results = json.items.map((item, i) => ({
        rank: i + 1,
        name: item.name,
        description: item.description || '',
        html_url: item.html_url,
        stars: item.stargazers_count,
        forks: item.forks_count,
        language: item.language,
        created_at: item.created_at
      }));
      
      // 保存到文件
      fs.writeFileSync('github_launchers.json', JSON.stringify(results, null, 2));
      
      results.forEach(r => {
        console.log(`${r.rank}. ${r.name} [${r.language}] - ${r.description}`);
        console.log(`   Stars: ${r.stars}, Forks: ${r.forks}`);
        console.log(`   URL: ${r.html_url}`);
        console.log('');
      });
      
      console.log(`\nSaved to github_launchers.json`);
    } catch (e) {
      console.error('Error:', e.message);
      console.log('Response preview:', data.substring(0, 300));
    }
  });
}).on('error', (e) => {
  console.error('Request error:', e.message);
});
