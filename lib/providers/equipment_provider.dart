import 'package:flutter/foundation.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../database/rifle_repository.dart';
import '../database/bullet_repository.dart';

class EquipmentProvider extends ChangeNotifier {
  final _rifleRepo = RifleRepository();
  final _bulletRepo = BulletRepository();

  List<Rifle> _rifles = [];
  List<Bullet> _bullets = [];

  List<Rifle> get rifles => List.unmodifiable(_rifles);
  List<Bullet> get bullets => List.unmodifiable(_bullets);

  Future<void> loadAll() async {
    _rifles = await _rifleRepo.getAll();
    _bullets = await _bulletRepo.getAll();
    notifyListeners();
  }

  Future<Rifle> addRifle(Rifle rifle) async {
    final id = await _rifleRepo.insert(rifle);
    final saved = rifle.copyWith(id: id);
    _rifles = [..._rifles, saved]..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return saved;
  }

  Future<void> updateRifle(Rifle rifle) async {
    await _rifleRepo.update(rifle);
    _rifles = _rifles.map((r) => r.id == rifle.id ? rifle : r).toList();
    notifyListeners();
  }

  Future<void> deleteRifle(int id) async {
    await _rifleRepo.delete(id);
    _rifles = _rifles.where((r) => r.id != id).toList();
    notifyListeners();
  }

  Future<Bullet> addBullet(Bullet bullet) async {
    final id = await _bulletRepo.insert(bullet);
    final saved = bullet.copyWith(id: id);
    _bullets = [..._bullets, saved]..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return saved;
  }

  Future<void> updateBullet(Bullet bullet) async {
    await _bulletRepo.update(bullet);
    _bullets = _bullets.map((b) => b.id == bullet.id ? bullet : b).toList();
    notifyListeners();
  }

  Future<void> deleteBullet(int id) async {
    await _bulletRepo.delete(id);
    _bullets = _bullets.where((b) => b.id != id).toList();
    notifyListeners();
  }
}
