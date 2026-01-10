import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._();

  factory GoogleDriveService() => _instance;

  GoogleDriveService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveReadonlyScope,
      'https://www.googleapis.com/auth/drive.metadata.readonly',
    ],
  );

  GoogleSignInAccount? _currentUser;
  String? _lastAuthError;

  String? get currentUserEmail => _currentUser?.email;
  String? get lastAuthError => _lastAuthError;

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _lastAuthError = null;
      _currentUser = await _googleSignIn.signInSilently();
      return _currentUser;
    } catch (error) {
      _lastAuthError = error.toString();
      debugPrint('Silent sign in error: $error');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _lastAuthError = null;
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (error) {
      _lastAuthError = error.toString();
      debugPrint('Sign in error: $error');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInFresh() async {
    try {
      _lastAuthError = null;
      await disconnect();
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (error) {
      _lastAuthError = error.toString();
      debugPrint('Fresh sign in error: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } finally {
      _currentUser = null;
    }
  }

  Future<drive.DriveApi?> getDriveApi() async {
    // Ensure we have a user
    final account = _currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) return null;

    var httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      // Some devices return null when the token is invalid/revoked or scopes changed.
      // Try forcing an interactive re-auth.
      final user = await signIn();
      if (user == null) return null;
      httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) return null;
    }
    return drive.DriveApi(httpClient);
  }

  Future<List<drive.File>> listDriveFiles() async {
    final driveApi = await getDriveApi();
    if (driveApi == null) return [];

    try {
      final fileList = await driveApi.files.list(
        q: "trashed = false and (fileExtension = 'pdf' or fileExtension = 'epub' or fileExtension = 'mobi' or fileExtension = 'azw3' or fileExtension = 'fb2' or fileExtension = 'txt')",
        spaces: 'drive',
        orderBy: 'modifiedTime desc',
        pageSize: 200,
        $fields: 'files(id, name, mimeType, size, fileExtension, modifiedTime)',
      );
      return fileList.files ?? [];
    } catch (e) {
      debugPrint('Error listing files: $e');
      final msg = e.toString();
      // If auth was revoked or scopes missing, force disconnect so UI can prompt reconnection.
      if (msg.contains('401') || msg.contains('403')) {
        await disconnect();
      }
      return [];
    }
  }

  Future<drive.File?> uploadFile(File file, String fileName) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) return null;

    final driveFile = drive.File();
    driveFile.name = fileName;

    final media = drive.Media(
      file.openRead(),
      file.lengthSync(),
      contentType: 'application/octet-stream',
    );

    try {
      // First check if file exists to update it, or create new
      final existingFiles = await driveApi.files.list(
        q: "name = '$fileName' and trashed = false",
        spaces: 'drive',
      );

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        final existingId = existingFiles.files!.first.id!;
        return await driveApi.files.update(
          driveFile,
          existingId,
          uploadMedia: media,
        );
      } else {
        return await driveApi.files.create(driveFile, uploadMedia: media);
      }
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  Future<File?> downloadFile(String fileId, String localPath) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) return null;

    try {
      final response =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final file = File(localPath);
      final ios = file.openWrite();
      await response.stream.pipe(ios);
      await ios.close();
      return file;
    } catch (e) {
      debugPrint('Error downloading file: $e');
      return null;
    }
  }

  Future<drive.File?> getFileByName(String fileName) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) return null;

    try {
      final result = await driveApi.files.list(
        q: "name = '$fileName' and trashed = false",
        spaces: 'drive',
      );
      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first;
      }
    } catch (e) {
      debugPrint('Error getting file by name: $e');
    }
    return null;
  }
}
