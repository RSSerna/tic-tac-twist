import 'package:meta/meta.dart';

import '../common/player.dart';

/// A chip on the board. Levels run L1 (smallest) to L4 (largest).
@immutable
class Chip {
  const Chip(this.owner, this.level)
      : assert(level >= 1 && level <= 4, 'Chip level must be 1–4');

  final Player owner;
  final int level;

  Map<String, Object?> toJson() => {'owner': owner.toJson(), 'level': level};

  factory Chip.fromJson(Map<String, Object?> json) {
    final level = json['level'];
    if (level is! int || level < 1 || level > 4) {
      throw FormatException('Invalid chip level: $level');
    }
    return Chip(Player.fromJson(json['owner']), level);
  }

  @override
  bool operator ==(Object other) =>
      other is Chip && other.owner == owner && other.level == level;

  @override
  int get hashCode => Object.hash(owner, level);

  @override
  String toString() => '${owner.name}L$level';
}
