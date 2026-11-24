const https = require('https');

// 检查 GitHub API 状态
const url = 'https://api.github.com/rate_limit';

https.get(url, { headers: { 'User-Agent': 'TapMC' } }, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      console.log(JSON.stringify(json, null, 2));
    } catch (e) {
      console.error('Error:', e.message);
      console.log('Response:', data.substring(0, 200));
    }
  });
}).on('error', (e) => {
  console.error('Request error:', e.message);
});
