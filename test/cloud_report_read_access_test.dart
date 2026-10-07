import 'package:calculadora_neps/utils/cloud_report_read_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canReadCloudReportArchive', () {
    test('niega cuando no hay ningún permiso de lectura de informes/nube', () {
      expect(
        canReadCloudReportArchive(
          canViewRecords: false,
          canViewWorkspaceRecords: false,
          canExportReports: false,
          canManageReports: false,
          canViewDashboard: false,
        ),
        isFalse,
      );
    });

    test('permite con viewWorkspaceRecords (sin viewRecords)', () {
      expect(
        canReadCloudReportArchive(
          canViewRecords: false,
          canViewWorkspaceRecords: true,
          canExportReports: false,
          canManageReports: false,
          canViewDashboard: false,
        ),
        isTrue,
      );
    });

    test('permite con viewDashboard (Analíticas)', () {
      expect(
        canReadCloudReportArchive(
          canViewRecords: false,
          canViewWorkspaceRecords: false,
          canExportReports: false,
          canManageReports: false,
          canViewDashboard: true,
        ),
        isTrue,
      );
    });

    test('permite con viewRecords / exportReports / manageReports', () {
      expect(
        canReadCloudReportArchive(
          canViewRecords: true,
          canViewWorkspaceRecords: false,
          canExportReports: false,
          canManageReports: false,
          canViewDashboard: false,
        ),
        isTrue,
      );
      expect(
        canReadCloudReportArchive(
          canViewRecords: false,
          canViewWorkspaceRecords: false,
          canExportReports: true,
          canManageReports: false,
          canViewDashboard: false,
        ),
        isTrue,
      );
      expect(
        canReadCloudReportArchive(
          canViewRecords: false,
          canViewWorkspaceRecords: false,
          canExportReports: false,
          canManageReports: true,
          canViewDashboard: false,
        ),
        isTrue,
      );
    });
  });
}
