const https = require('https');

// 搜索 Forge 相关的启动器
const query = encodeURIComponent('forge launcher star:>500');
const url = `https://api.github.com/search/repositories?q=${query}&sort=stars&order=desc&per_page=20`;

https.get(url, { headers: { 'User-Agent': 'TapMC' } }, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      if (json.items) {
        json.items.forEach((item, i) => {
          console.log(`${i+1}. ${item.name} - ${item.description}`);
          console.log(`   Stars: ${item.stargazers_count}, Forks: ${item.forks_count}`);
          console.log(`   URL: ${item.html_url}`);
          console.log('');
        });
      } else {
        console.log('No results found');
        console.log(JSON.stringify(json, null, 2).substring(0, 500));
      }
    } catch (e) {
      console.error('Error:', e.message);
    }
  });
}).on('error', (e) => {
  console.error('Request error:', e.message);
});
