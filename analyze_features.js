const https = require('https');
const fs = require('fs');

// 获取 HMCL 的 README 来分析功能
const repos = [
  'HMCL-dev/HMCL',
  'PrismLauncher/PrismLauncher', 
  'PojavLauncherTeam/PojavLauncher',
  'MultiMC/Launcher'
];

async function fetchRepo(repo) {
  return new Promise((resolve, reject) => {
    https.get(`https://api.github.com/repos/${repo}`, { 
      headers: { 'User-Agent': 'TapMC', 'Accept': 'application/vnd.github.v3+json' } 
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function main() {
  const results = [];
  for (const repo of repos) {
    try {
      const data = await fetchRepo(repo);
      results.push({
        name: data.name,
        description: data.description || '',
        homepage: data.homepage || '',
        topics: data.topics || [],
        language: data.language,
        forks_count: data.forks_count,
        stargazers_count: data.stargazers_count,
        subscribers_count: data.subscribers_count
      });
    } catch (e) {
      console.error(`Error fetching ${repo}:`, e.message);
    }
  }
  
  fs.writeFileSync('github_features.json', JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
}

main();
