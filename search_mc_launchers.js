const https = require('https');

// 使用 search 端点
const query = 'minecraft launcher in:name,description';
const url = `https://api.github.com/search/repositories?q=${encodeURIComponent(query)}&sort=stars&order=desc&per_page=10`;

https.get(url, { headers: { 'User-Agent': 'TapMC', 'Accept': 'application/vnd.github.v3+json' } }, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      console.log(`Total count: ${json.total_count}`);
      if (json.items) {
        json.items.forEach((item, i) => {
          console.log(`${i+1}. ${item.name}`);
          console.log(`   Description: ${item.description || 'N/A'}`);
          console.log(`   Stars: ${item.stargazers_count}, Forks: ${item.forks_count}`);
          console.log(`   URL: ${item.html_url}`);
          console.log('');
        });
      }
    } catch (e) {
      console.error('Error:', e.message);
      console.log('Response:', data.substring(0, 300));
    }
  });
}).on('error', (e) => {
  console.error('Request error:', e.message);
});
