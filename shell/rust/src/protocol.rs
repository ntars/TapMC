use serde::Deserialize;

pub const JSON_RPC_VERSION: &str = "2.0";
pub const PROTOCOL_VERSION: &str = "1.0";

pub mod methods {
    pub const SYSTEM_HELLO: &str = "system.hello";
    pub const SYSTEM_MODS: &str = "system.mods";
    pub const WORLD_SNAPSHOT: &str = "world.snapshot";
    pub const WORLD_PLACE_BLOCK: &str = "world.placeBlock";
    pub const WORLD_BREAK_BLOCK: &str = "world.breakBlock";
    pub const PLAYER_JOIN: &str = "player.join";
    pub const PLAYER_MOVE: &str = "player.move";
}

#[derive(Clone, Copy, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "UPPERCASE")]
pub enum BlockType {
    Air,
    Dirt,
    Stone,
    Water,
    Wood,
}

impl BlockType {
    pub const PLACEABLE: [Self; 4] = [Self::Dirt, Self::Stone, Self::Water, Self::Wood];

    pub fn wire_name(self) -> &'static str {
        match self {
            Self::Air => "AIR",
            Self::Dirt => "DIRT",
            Self::Stone => "STONE",
            Self::Water => "WATER",
            Self::Wood => "WOOD",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Air => "空气",
            Self::Dirt => "泥土",
            Self::Stone => "石头",
            Self::Water => "水",
            Self::Wood => "树干",
        }
    }
}

impl From<&str> for BlockType {
    fn from(value: &str) -> Self {
        match value {
            "DIRT" => Self::Dirt,
            "STONE" => Self::Stone,
            "WATER" => Self::Water,
            "WOOD" => Self::Wood,
            _ => Self::Air,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MoveDirection {
    North,
    South,
    West,
    East,
}

impl MoveDirection {
    pub fn wire_name(self) -> &'static str {
        match self {
            Self::North => "NORTH",
            Self::South => "SOUTH",
            Self::West => "WEST",
            Self::East => "EAST",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::North => "北",
            Self::South => "南",
            Self::West => "西",
            Self::East => "东",
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ServerInfo {
    pub server_name: String,
    pub server_version: String,
    pub protocol_version: String,
    pub world_width: usize,
    pub world_height: usize,
    #[serde(default)]
    pub block_types: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct WorldSnapshot {
    pub width: usize,
    pub height: usize,
    pub blocks: Vec<String>,
}

impl WorldSnapshot {
    pub fn empty() -> Self {
        Self {
            width: 0,
            height: 0,
            blocks: Vec::new(),
        }
    }

    pub fn block_at(&self, x: usize, y: usize) -> BlockType {
        if x >= self.width || y >= self.height {
            return BlockType::Air;
        }
        self.blocks
            .get(y * self.width + x)
            .map(|name| BlockType::from(name.as_str()))
            .unwrap_or(BlockType::Air)
    }

    pub fn set_block(&mut self, x: usize, y: usize, block: BlockType) -> bool {
        if x >= self.width || y >= self.height {
            return false;
        }
        let index = y * self.width + x;
        let Some(slot) = self.blocks.get_mut(index) else {
            return false;
        };
        let changed = slot != block.wire_name();
        *slot = block.wire_name().to_owned();
        changed
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct Position {
    pub x: usize,
    pub y: usize,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct PlayerState {
    pub id: String,
    pub pos: Position,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct WorldChange {
    pub pos: Position,
    pub block: String,
    #[serde(default = "default_actor")]
    pub actor: String,
}

fn default_actor() -> String {
    "system".to_owned()
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq)]
pub struct ModInfo {
    pub id: String,
    pub name: String,
    pub version: String,
    pub state: String,
    #[serde(default)]
    pub reason: String,
}

#[derive(Clone, Debug, Deserialize)]
pub struct RpcErrorBody {
    pub code: i64,
    pub message: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn block_names_match_the_wire_contract() {
        assert_eq!(BlockType::Air.wire_name(), "AIR");
        assert_eq!(BlockType::Dirt.wire_name(), "DIRT");
        assert_eq!(BlockType::Stone.wire_name(), "STONE");
        assert_eq!(BlockType::Water.wire_name(), "WATER");
        assert_eq!(BlockType::Wood.wire_name(), "WOOD");
    }

    #[test]
    fn snapshot_is_row_major_and_bounds_safe() {
        let mut world = WorldSnapshot {
            width: 2,
            height: 2,
            blocks: vec!["AIR".into(), "DIRT".into(), "STONE".into(), "WOOD".into()],
        };
        assert_eq!(world.block_at(1, 1), BlockType::Wood);
        assert_eq!(world.block_at(9, 9), BlockType::Air);
        assert!(world.set_block(0, 1, BlockType::Water));
        assert_eq!(world.block_at(0, 1), BlockType::Water);
        assert!(!world.set_block(4, 4, BlockType::Dirt));
    }

    #[test]
    fn hello_json_deserializes_camel_case_fields() {
        let info: ServerInfo = serde_json::from_str(
            r#"{"serverName":"TapMC","serverVersion":"0.1.0","protocolVersion":"1.0","worldWidth":24,"worldHeight":16,"blockTypes":["AIR"]}"#,
        )
        .unwrap();
        assert_eq!(info.server_name, "TapMC");
        assert_eq!(info.world_width, 24);
    }
}
