const https = require('https');
const fs = require('fs');

function fetchPage(page) {
  return new Promise((resolve, reject) => {
    const query = 'minecraft launcher in:name,description';
    const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(query)}&sort=stars&order=desc&per_page=100&page=${page}`;
    
    https.get(url, { 
      headers: { 'User-Agent': 'TapMC', 'Accept': 'application/vnd.github.v3+json' } 
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve(json.items || []);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function main() {
  const allItems = [];
  
  // 获取第一页（100个结果）
  try {
    const items = await fetchPage(1);
    allItems.push(...items);
    console.log(`获取到 ${items.length} 个结果`);
    
    // 如果还有更多，继续获取
    if (allItems.length < 100 && items.length === 100) {
      const moreItems = await fetchPage(2);
      allItems.push(...moreItems);
      console.log(`获取到第2页 ${moreItems.length} 个结果`);
    }
    
    // 保存前100条
    const top100 = allItems.slice(0, 100).map((item, i) => ({
      rank: i + 1,
      name: item.name,
      description: item.description || '',
      html_url: item.html_url,
      stars: item.stargazers_count,
      forks: item.forks_count,
      language: item.language,
      created_at: item.created_at
    }));
    
    fs.writeFileSync('github_100_launchers.json', JSON.stringify(top100, null, 2));
    console.log(`\n已保存前 ${top100.length} 条结果到 github_100_launchers.json`);
    
    // 显示前20条
    console.log('\n前20条结果:');
    top100.slice(0, 20).forEach(r => {
      console.log(`${r.rank}. ${r.name} [${r.language}] - Stars: ${r.stars}`);
    });
  } catch (e) {
    console.error('Error:', e.message);
  }
}

main();
