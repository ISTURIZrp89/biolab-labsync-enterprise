import 'package:flutter_test/flutter_test.dart';
import 'package:biolab_labsync/security/permission_service.dart';

void main() {
  group('PermissionService', () {
    late PermissionService service;

    setUp(() {
      service = PermissionService();
    });

    test('ADMIN has all permissions', () {
      expect(service.hasPermission('ADMIN', 'read'), true);
      expect(service.hasPermission('ADMIN', 'write'), true);
      expect(service.hasPermission('ADMIN', 'delete'), true);
      expect(service.hasPermission('ADMIN', 'admin'), true);
      expect(service.hasPermission('ADMIN', 'audit'), true);
      expect(service.hasPermission('ADMIN', 'manage_users'), true);
      expect(service.hasPermission('ADMIN', 'closure'), true);
    });

    test('LABORATORIO has read and write only', () {
      expect(service.hasPermission('LABORATORIO', 'read'), true);
      expect(service.hasPermission('LABORATORIO', 'write'), true);
      expect(service.hasPermission('LABORATORIO', 'delete'), false);
      expect(service.hasPermission('LABORATORIO', 'admin'), false);
      expect(service.hasPermission('LABORATORIO', 'audit'), false);
    });

    test('AUDITOR has read and audit only', () {
      expect(service.hasPermission('AUDITOR', 'read'), true);
      expect(service.hasPermission('AUDITOR', 'audit'), true);
      expect(service.hasPermission('AUDITOR', 'write'), false);
      expect(service.hasPermission('AUDITOR', 'delete'), false);
    });

    test('JEFE has read, write, audit, and closure', () {
      expect(service.hasPermission('JEFE', 'read'), true);
      expect(service.hasPermission('JEFE', 'write'), true);
      expect(service.hasPermission('JEFE', 'audit'), true);
      expect(service.hasPermission('JEFE', 'closure'), true);
      expect(service.hasPermission('JEFE', 'delete'), false);
    });

    test('canManageUsers returns true only for ADMIN and DUENO', () {
      expect(service.canManageUsers('ADMIN'), true);
      expect(service.canManageUsers('DUENO'), true);
      expect(service.canManageUsers('JEFE'), false);
      expect(service.canManageUsers('LABORATORIO'), false);
      expect(service.canManageUsers('AUDITOR'), false);
    });

    test('canCloseDay returns true for ADMIN, JEFE, and DUENO', () {
      expect(service.canCloseDay('ADMIN'), true);
      expect(service.canCloseDay('JEFE'), true);
      expect(service.canCloseDay('DUENO'), true);
      expect(service.canCloseDay('LABORATORIO'), false);
      expect(service.canCloseDay('AUDITOR'), false);
    });

    test('unknown role has no permissions', () {
      expect(service.hasPermission('UNKNOWN', 'read'), false);
      expect(service.getPermissions('UNKNOWN'), isEmpty);
    });
  });
}
