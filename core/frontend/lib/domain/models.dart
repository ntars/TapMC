import 'package:flutter/foundation.dart';

import 'block_type.dart';
import 'geometry.dart';

/// 服务端信息，对应 `system.hello` 的返回。
@immutable
class ServerInfo {
  const ServerInfo({
    required this.serverName,
    required this.serverVersion,
    required this.protocolVersion,
    required this.worldWidth,
    required this.worldHeight,
  });

  final String serverName;
  final String serverVersion;
  final String protocolVersion;
  final int worldWidth;
  final int worldHeight;

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        serverName: json['serverName'] as String? ?? '未知',
        serverVersion: json['serverVersion'] as String? ?? '0.0.0',
        protocolVersion: json['protocolVersion'] as String? ?? '',
        worldWidth: (json['worldWidth'] as num?)?.toInt() ?? 0,
        worldHeight: (json['worldHeight'] as num?)?.toInt() ?? 0,
      );
}

/// 整张地图快照，对应 `world.snapshot` 的返回。
///
/// [blocks] 按行优先存储：索引 `y * width + x`。用一维列表而非二维，
/// 与后端序列化格式一致，也省掉一层越界判断。
@immutable
class WorldSnapshot {
  const WorldSnapshot({
    required this.width,
    required this.height,
    required this.blocks,
  });

  final int width;
  final int height;
  final List<BlockType> blocks;

  /// 读一格。越界返回 [BlockType.air]，调用方不必判边界。
  BlockType at(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return BlockType.air;
    final index = y * width + x;
    if (index >= blocks.length) return BlockType.air;
    return blocks[index];
  }

  /// 返回替换了某格的新快照。不可变更新，让 UI 层能靠引用比较判断要不要重绘。
  WorldSnapshot withBlock(BlockPos pos, BlockType block) {
    if (pos.x < 0 || pos.y < 0 || pos.x >= width || pos.y >= height) {
      return this;
    }
    final next = List<BlockType>.of(blocks);
    next[pos.y * width + pos.x] = block;
    return WorldSnapshot(width: width, height: height, blocks: next);
  }

  factory WorldSnapshot.fromJson(Map<String, dynamic> json) {
    final width = (json['width'] as num?)?.toInt() ?? 0;
    final height = (json['height'] as num?)?.toInt() ?? 0;
    final raw = (json['blocks'] as List<dynamic>?) ?? const <dynamic>[];
    final blocks = raw
        .map((name) => BlockType.fromWire(name as String?))
        .toList(growable: false);
    return WorldSnapshot(width: width, height: height, blocks: blocks);
  }

  /// 空世界。用于「还没连上」的占位，避免 UI 层到处判空。
  static const WorldSnapshot empty =
      WorldSnapshot(width: 0, height: 0, blocks: <BlockType>[]);
}

/// 一个玩家的可见状态。
@immutable
class PlayerState {
  const PlayerState({required this.id, required this.pos});

  final String id;
  final BlockPos pos;

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        id: json['id'] as String? ?? '',
        pos: BlockPos.fromJson(
            (json['pos'] as Map<String, dynamic>?) ?? const {'x': 0, 'y': 0}),
      );

  PlayerState movedTo(BlockPos newPos) => PlayerState(id: id, pos: newPos);
}

/// 一次世界变化。自己改的与别人改的都用这个结构，UI 可统一处理。
@immutable
class WorldChange {
  const WorldChange({
    required this.pos,
    required this.block,
    required this.actor,
  });

  final BlockPos pos;
  final BlockType block;

  /// 触发者 id，系统/模组改动时为 `system`。
  final String actor;

  factory WorldChange.fromJson(Map<String, dynamic> json) => WorldChange(
        pos: BlockPos.fromJson(
            (json['pos'] as Map<String, dynamic>?) ?? const {'x': 0, 'y': 0}),
        block: BlockType.fromWire(json['block'] as String?),
        actor: json['actor'] as String? ?? 'system',
      );
}

/// 模组状态。与后端 `ModInfo.State` 对齐。
enum ModState {
  active('ACTIVE'),
  disabled('DISABLED'),
  failed('FAILED');

  const ModState(this.wireName);

  final String wireName;

  static ModState fromWire(String? name) {
    for (final state in ModState.values) {
      if (state.wireName == name) return state;
    }
    return ModState.failed;
  }
}

/// 一份模组信息。
@immutable
class ModInfo {
  const ModInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.state,
    required this.reason,
  });

  final String id;
  final String name;
  final String version;
  final ModState state;

  /// 失败或禁用原因。正常时为空串。
  final String reason;

  factory ModInfo.fromJson(Map<String, dynamic> json) => ModInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '0.0.0',
        state: ModState.fromWire(json['state'] as String?),
        reason: json['reason'] as String? ?? '',
      );
}
