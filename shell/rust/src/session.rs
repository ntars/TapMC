use crate::protocol::{
    BlockType, ModInfo, MoveDirection, PROTOCOL_VERSION, PlayerState, Position, ServerInfo,
    WorldChange, WorldSnapshot,
};
use crate::rpc::{RpcClient, RpcFailure};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConnectionStage {
    Idle,
    Connecting,
    Ready,
    Failed,
}

impl ConnectionStage {
    pub fn label(self) -> &'static str {
        match self {
            Self::Idle => "未连接",
            Self::Connecting => "连接中",
            Self::Ready => "已连接",
            Self::Failed => "连接失败",
        }
    }
}

#[derive(Clone, Debug)]
pub struct LauncherSession {
    pub stage: ConnectionStage,
    pub info: Option<ServerInfo>,
    pub world: WorldSnapshot,
    pub player: Option<PlayerState>,
    pub mods: Vec<ModInfo>,
    pub selected_block: BlockType,
    pub message: String,
    pub logs: Vec<String>,
}

impl Default for LauncherSession {
    fn default() -> Self {
        Self {
            stage: ConnectionStage::Idle,
            info: None,
            world: WorldSnapshot::empty(),
            player: None,
            mods: Vec::new(),
            selected_block: BlockType::Stone,
            message: "准备连接 TapMC Java 核心".to_owned(),
            logs: Vec::new(),
        }
    }
}

impl LauncherSession {
    pub fn is_ready(&self) -> bool {
        self.stage == ConnectionStage::Ready
    }

    pub fn is_joined(&self) -> bool {
        self.is_ready() && self.player.is_some()
    }

    pub fn append_log(&mut self, line: impl Into<String>) {
        self.logs.push(line.into());
        if self.logs.len() > 200 {
            self.logs.drain(0..self.logs.len() - 200);
        }
    }

    pub fn connect(&mut self, endpoint: &str) -> Result<RpcClient, String> {
        self.stage = ConnectionStage::Connecting;
        self.message = format!("正在连接 {endpoint}");
        let client = RpcClient::connect(endpoint)?;

        let info = client
            .hello()
            .map_err(|error| format!("握手失败：{error}"))?;
        if info.protocol_version != PROTOCOL_VERSION {
            return Err(format!(
                "协议版本不匹配：壳支持 {PROTOCOL_VERSION}，后端为 {}",
                info.protocol_version
            ));
        }
        let world = client
            .snapshot()
            .map_err(|error| format!("读取世界失败：{error}"))?;
        if world.blocks.len() != world.width.saturating_mul(world.height) {
            return Err(format!(
                "世界快照尺寸不一致：{}×{}，收到 {} 格",
                world.width,
                world.height,
                world.blocks.len()
            ));
        }
        let mods = client
            .mods()
            .map_err(|error| format!("读取模组失败：{error}"))?;
        let player = client
            .join()
            .map_err(|error| format!("加入世界失败：{error}"))?;

        self.info = Some(info);
        self.world = world;
        self.mods = mods;
        self.player = Some(player);
        self.stage = ConnectionStage::Ready;
        self.message = format!(
            "已连接 {}，世界 {}x{}",
            self.info
                .as_ref()
                .map_or("TapMC", |info| info.server_name.as_str()),
            self.world.width,
            self.world.height
        );
        self.append_log(self.message.clone());
        Ok(client)
    }

    pub fn mark_failed(&mut self, message: impl Into<String>) {
        self.stage = ConnectionStage::Failed;
        self.message = message.into();
        self.append_log(self.message.clone());
    }

    pub fn select_block(&mut self, block: BlockType) {
        if block != BlockType::Air {
            self.selected_block = block;
        }
    }

    pub fn apply_world_change(&mut self, change: WorldChange) {
        if self.world.set_block(
            change.pos.x,
            change.pos.y,
            BlockType::from(change.block.as_str()),
        ) {
            self.message = format!(
                "({}, {}) 变为 {}",
                change.pos.x,
                change.pos.y,
                BlockType::from(change.block.as_str()).label()
            );
            self.append_log(format!("{}：{}", change.actor, self.message));
        }
    }

    #[cfg_attr(not(test), allow(dead_code))]
    pub fn apply_event_json(&mut self, value: &serde_json::Value) {
        if value.get("method").and_then(serde_json::Value::as_str) != Some("event.worldChanged") {
            return;
        }
        let Some(params) = value.get("params") else {
            return;
        };
        if let Some(change) = params.get("change")
            && let Ok(change) = serde_json::from_value::<WorldChange>(change.clone())
        {
            self.apply_world_change(change);
        }
    }

    pub fn move_player(
        &mut self,
        client: &RpcClient,
        direction: MoveDirection,
    ) -> Result<(), RpcFailure> {
        let value = client.call(
            crate::protocol::methods::PLAYER_MOVE,
            Some(serde_json::json!({"direction": direction.wire_name()})),
        )?;
        let player: PlayerState = serde_json::from_value(value)
            .map_err(|error| RpcFailure::Transport(format!("玩家状态无法解析：{error}")))?;
        self.player = Some(player);
        self.message = format!("向{}移动一格", direction.label());
        self.append_log(self.message.clone());
        Ok(())
    }

    pub fn place_block(
        &mut self,
        client: &RpcClient,
        x: usize,
        y: usize,
    ) -> Result<(), RpcFailure> {
        let value = client.call(
            crate::protocol::methods::WORLD_PLACE_BLOCK,
            Some(serde_json::json!({
                "x": x,
                "y": y,
                "block": self.selected_block.wire_name(),
            })),
        )?;
        let change: WorldChange = serde_json::from_value(value)
            .map_err(|error| RpcFailure::Transport(format!("世界变化无法解析：{error}")))?;
        self.apply_world_change(change);
        Ok(())
    }

    pub fn break_block(
        &mut self,
        client: &RpcClient,
        x: usize,
        y: usize,
    ) -> Result<(), RpcFailure> {
        let value = client.call(
            crate::protocol::methods::WORLD_BREAK_BLOCK,
            Some(serde_json::json!({"x": x, "y": y})),
        )?;
        let change: WorldChange = serde_json::from_value(value)
            .map_err(|error| RpcFailure::Transport(format!("世界变化无法解析：{error}")))?;
        self.apply_world_change(change);
        Ok(())
    }

    pub fn coordinates_at(&self) -> Option<Position> {
        self.player.as_ref().map(|player| player.pos.clone())
    }
}

/// Headless end-to-end probe used by `tapmc-shell --smoke`.
///
/// It deliberately uses the same `LauncherSession::connect` path as the GUI:
/// hello -> snapshot -> mods -> join, then verifies one world mutation and one
/// movement through JSON-RPC. This catches contract drift even on CI machines
/// with no display server.
pub fn run_smoke() -> Result<(), String> {
    let endpoint =
        std::env::var("TAPMC_SMOKE_ENDPOINT").unwrap_or_else(|_| "ws://127.0.0.1:8777/".to_owned());
    let mut session = LauncherSession::default();
    let client = session.connect(&endpoint)?;
    if !session.is_joined() {
        return Err("握手完成但没有玩家身份".to_owned());
    }
    let before = session
        .player
        .as_ref()
        .map(|player| player.pos.clone())
        .ok_or_else(|| "缺少玩家位置".to_owned())?;
    session
        .move_player(&client, MoveDirection::East)
        .map_err(|error| format!("移动验证失败：{error}"))?;
    let after = session
        .player
        .as_ref()
        .map(|player| player.pos.clone())
        .ok_or_else(|| "移动后缺少玩家位置".to_owned())?;
    if after.x <= before.x {
        return Err(format!(
            "向东移动未改变 x：({}, {}) -> ({}, {})",
            before.x, before.y, after.x, after.y
        ));
    }

    let mut changed = None;
    if session.world.width > 0 && session.world.height > 0 {
        let (x, y) = (0, 0);
        let before_block = session.world.block_at(x, y);
        if before_block == BlockType::Air {
            session
                .place_block(&client, x, y)
                .map_err(|error| format!("放置验证失败：{error}"))?;
        } else {
            session
                .break_block(&client, x, y)
                .map_err(|error| format!("破坏验证失败：{error}"))?;
        }
        changed = Some((x, y, before_block));
    }
    let (x, y, before_block) = changed.ok_or_else(|| "世界为空，无法验证方块操作".to_owned())?;
    if session.world.block_at(x, y) == before_block {
        return Err("方块操作没有更新本地世界".to_owned());
    }
    client.close();
    println!(
        "SMOKE_OK player={} world={}x{} move={}->{}, block=({}, {}) {}->{}",
        session
            .player
            .as_ref()
            .map_or("?", |player| player.id.as_str()),
        session.world.width,
        session.world.height,
        before.x,
        after.x,
        x,
        y,
        before_block.wire_name(),
        session.world.block_at(x, y).wire_name()
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn event_updates_world_and_log_without_mutating_player() {
        let mut session = LauncherSession {
            world: WorldSnapshot {
                width: 2,
                height: 1,
                blocks: vec!["AIR".into(), "DIRT".into()],
            },
            player: Some(PlayerState {
                id: "p".into(),
                pos: Position { x: 0, y: 0 },
            }),
            ..LauncherSession::default()
        };
        session.apply_event_json(&serde_json::json!({
            "method": "event.worldChanged",
            "params": {"change": {"pos": {"x": 0, "y": 0}, "block": "STONE", "actor": "other"}}
        }));
        assert_eq!(session.world.block_at(0, 0), BlockType::Stone);
        assert_eq!(session.player.as_ref().unwrap().pos.x, 0);
        assert!(session.message.contains("石头"));
    }

    #[test]
    fn log_is_bounded() {
        let mut session = LauncherSession::default();
        for index in 0..250 {
            session.append_log(index.to_string());
        }
        assert_eq!(session.logs.len(), 200);
        assert_eq!(session.logs.first().unwrap(), "50");
    }
}
