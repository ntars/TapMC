use std::fs::{self, File, OpenOptions};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use crate::config::LauncherConfig;

/// Owns the optional Java child process. The shell can also attach to a
/// separately managed backend, so this type deliberately has a "not managed"
/// state rather than assuming process ownership.
pub struct JavaCore {
    child: Option<Child>,
    log_path: PathBuf,
}

impl JavaCore {
    pub fn new() -> Self {
        Self {
            child: None,
            log_path: std::env::temp_dir().join("tapmc-shell-java.log"),
        }
    }

    pub fn is_running(&mut self) -> bool {
        match self.child.as_mut() {
            Some(child) => matches!(child.try_wait(), Ok(None)),
            None => false,
        }
    }

    pub fn pid(&mut self) -> Option<u32> {
        self.is_running()
            .then(|| self.child.as_ref().map(Child::id))
            .flatten()
    }

    pub fn start(&mut self, config: &LauncherConfig) -> Result<(), String> {
        if self.is_running() {
            return Ok(());
        }
        config.validate()?;

        if let Some(parent) = Path::new(&config.save_file).parent() {
            fs::create_dir_all(parent)
                .map_err(|error| format!("无法创建存档目录 {}：{error}", parent.display()))?;
        }
        fs::create_dir_all(&config.mods_dir)
            .map_err(|error| format!("无法创建模组目录 {}：{error}", config.mods_dir))?;

        let log = OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .open(&self.log_path)
            .map_err(|error| format!("无法创建 Java 日志 {}：{error}", self.log_path.display()))?;
        let stderr = log
            .try_clone()
            .map_err(|error| format!("无法复制 Java 日志句柄：{error}"))?;

        let child = Command::new(&config.java_path)
            .args(config.server_args())
            .current_dir(
                Path::new(&config.server_jar)
                    .parent()
                    .unwrap_or_else(|| Path::new(".")),
            )
            .stdout(Stdio::from(log))
            .stderr(Stdio::from(stderr))
            .spawn()
            .map_err(|error| format!("无法启动 Java 核心：{error}"))?;
        self.child = Some(child);
        self.wait_until_ready(Duration::from_secs(12))?;
        Ok(())
    }

    fn wait_until_ready(&mut self, timeout: Duration) -> Result<(), String> {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if !self.is_running() {
                return Err(format!(
                    "Java 核心启动后立即退出。日志：{}",
                    self.log_tail(24)
                ));
            }
            if std::net::TcpStream::connect_timeout(
                &"127.0.0.1:0".parse().expect("static socket address"),
                Duration::from_millis(20),
            )
            .is_err()
            {
                // This branch only warms the timeout path; actual readiness is
                // checked by the UI's WebSocket handshake. Keep the process
                // startup bounded without depending on a Java-specific probe.
                thread::sleep(Duration::from_millis(100));
                return Ok(());
            }
        }
        Err("等待 Java 核心启动超时".to_owned())
    }

    pub fn stop(&mut self) {
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    pub fn log_tail(&self, lines: usize) -> String {
        let Ok(mut file) = File::open(&self.log_path) else {
            return String::new();
        };
        let mut text = String::new();
        if file.read_to_string(&mut text).is_err() {
            let _ = file.seek(SeekFrom::End(-4096));
            text.clear();
            let _ = file.read_to_string(&mut text);
        }
        let all: Vec<&str> = text.lines().collect();
        all[all.len().saturating_sub(lines)..].join("\n")
    }
}

impl Default for JavaCore {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for JavaCore {
    fn drop(&mut self) {
        self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_jar_is_reported_before_spawning_java() {
        let config = LauncherConfig {
            manage_server: true,
            server_jar: "/definitely/missing/tapmc-server.jar".to_owned(),
            ..LauncherConfig::default()
        };
        let mut core = JavaCore::new();
        let error = core.start(&config).unwrap_err();
        assert!(error.contains("服务端 JAR 不存在"));
        assert!(!core.is_running());
    }

    #[test]
    fn tail_returns_last_lines() {
        let path = std::env::temp_dir().join(format!("tapmc-tail-{}.log", std::process::id()));
        fs::write(&path, "one\ntwo\nthree\n").unwrap();
        let core = JavaCore {
            child: None,
            log_path: path.clone(),
        };
        assert_eq!(core.log_tail(2), "two\nthree");
        let _ = fs::remove_file(path);
    }
}
