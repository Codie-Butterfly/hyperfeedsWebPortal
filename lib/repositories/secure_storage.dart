import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserRole = 'user_role';
  static const _keyCustomerId = 'customer_id';
  static const _keySelectedBranchId = 'selected_branch_id';
  static const _keySelectedBranchName = 'selected_branch_name';

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  Future<void> saveCustomerId(String customerId) async {
    await _storage.write(key: _keyCustomerId, value: customerId);
  }

  Future<String?> getCustomerId() async {
    return await _storage.read(key: _keyCustomerId);
  }

  Future<void> saveSelectedBranch(String branchId, String branchName) async {
    await _storage.write(key: _keySelectedBranchId, value: branchId);
    await _storage.write(key: _keySelectedBranchName, value: branchName);
  }

  Future<String?> getSelectedBranchId() async {
    return await _storage.read(key: _keySelectedBranchId);
  }

  Future<String?> getSelectedBranchName() async {
    return await _storage.read(key: _keySelectedBranchName);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserRole);
    await _storage.delete(key: _keyCustomerId);
    await _storage.delete(key: _keySelectedBranchId);
    await _storage.delete(key: _keySelectedBranchName);
  }
}
