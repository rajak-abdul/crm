import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'deals_attachment_state.dart';

class DealsAttachmentCubit extends Cubit<DealsAttachmentState> {
  DealsAttachmentCubit() : super(const DealsAttachmentState());

  static const MethodChannel _downloadsChannel =
    MethodChannel('crm/downloads');



    

  final Dio _dio = Dio();

  //=========================================================
  // Preview Attachment
  //=========================================================

  Future<void> previewAttachment(String rawPath) async {
    emit(state.copyWith(status: DealsAttachmentStatus.loading));

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';
      final tenantSlug = prefs.getString('tenant_slug') ?? '';

      if (token.isEmpty || tenantSlug.isEmpty) {
        throw Exception('Login required');
      }

      final cleanPath =
          rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;

      final url = Uri.https(
        'crm-backend-api.techzarinfo.cloud',
        '/$tenantSlug/api/files/preview',
        {
          'filePath': cleanPath,
        },
      ).toString();

      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Authorization': 'Bearer $token',
          },
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 20),
        ),
      );

      final bytes = response.data;

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty response from server');
      }

      final tempDir = await getTemporaryDirectory();

      final fileName = rawPath.split('/').last;

      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }

      emit(
        state.copyWith(
          status: DealsAttachmentStatus.previewSuccess,
          filePath: file.path,
        ),
      );
    } on DioException catch (e) {
      emit(
        state.copyWith(
          status: DealsAttachmentStatus.error,
          message: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DealsAttachmentStatus.error,
          message: e.toString(),
        ),
      );
    }
  }

  //=========================================================
  // Mime Type Helpers
  //=========================================================

  MimeType _dealMimeTypeForAttachmentExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return MimeType.pdf;

      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;

      case 'png':
        return MimeType.png;

      case 'gif':
        return MimeType.gif;

      case 'doc':
      case 'docx':
        return MimeType.microsoftWord;

      case 'xls':
      case 'xlsx':
        return MimeType.microsoftExcel;

      case 'ppt':
      case 'pptx':
        return MimeType.microsoftPresentation;

      case 'csv':
        return MimeType.csv;

      case 'txt':
        return MimeType.text;

      case 'json':
        return MimeType.json;

      case 'zip':
        return MimeType.zip;

      default:
        return MimeType.other;
    }
  }

  String _dealMimeStringForAttachmentExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';

      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'gif':
        return 'image/gif';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'xls':
        return 'application/vnd.ms-excel';

      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      case 'ppt':
        return 'application/vnd.ms-powerpoint';

      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      case 'csv':
        return 'text/csv';

      case 'txt':
        return 'text/plain';

      case 'json':
        return 'application/json';

      case 'zip':
        return 'application/zip';

      default:
        return 'application/octet-stream';
    }
  }

  //=========================================================
  // Download Attachment (Part 2)
  //=========================================================

    Future<void> downloadAttachment({
    required String rawPath,
    required String fileName,
  }) async {
    emit(state.copyWith(status: DealsAttachmentStatus.loading));

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';
      final tenantSlug = prefs.getString('tenant_slug') ?? '';

      if (token.isEmpty || tenantSlug.isEmpty) {
        throw Exception('Login required');
      }

      final cleanPath =
          rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;

      final url = Uri.https(
        'crm-backend-api.techzarinfo.cloud',
        '/$tenantSlug/api/files/download',
        {
          'filePath': cleanPath,
        },
      ).toString();

      final lastDot = fileName.lastIndexOf('.');

      final baseName =
          lastDot > 0 ? fileName.substring(0, lastDot) : fileName;

      final ext =
          lastDot > 0 ? fileName.substring(lastDot + 1) : '';

      final mimeType = _dealMimeTypeForAttachmentExt(ext);
      final mimeString = _dealMimeStringForAttachmentExt(ext);

      if (Platform.isAndroid) {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {
              'Authorization': 'Bearer $token',
            },
            receiveTimeout: const Duration(seconds: 60),
            connectTimeout: const Duration(seconds: 30),
          ),
        );

        final bytes = response.data;

        if (bytes == null || bytes.isEmpty) {
          throw Exception('Empty file response from server');
        }

        final savedPath = await _downloadsChannel.invokeMethod<String>(
          'saveToDownloads',
          {
            'fileName': fileName,
            'bytes': Uint8List.fromList(bytes),
            'mimeType': mimeString,
          },
        );

        if (savedPath == null || savedPath.isEmpty) {
          throw Exception('Failed to save file');
        }

        emit(
          state.copyWith(
            status: DealsAttachmentStatus.downloadSuccess,
            message: savedPath,
          ),
        );
      } else {
        final savedPath = await FileSaver.instance.saveFile(
          name: baseName,
          ext: ext,
          mimeType: mimeType,
          link: LinkDetails(
            link: url,
            headers: {
              'Authorization': 'Bearer $token',
            },
          ),
        );

        emit(
          state.copyWith(
            status: DealsAttachmentStatus.downloadSuccess,
            message: savedPath,
          ),
        );
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map)
          ? (e.response!.data['message']?.toString() ?? e.message)
          : e.message;

      emit(
        state.copyWith(
          status: DealsAttachmentStatus.error,
          message: msg ?? 'Download failed',
        ),
      );
    } on PlatformException catch (e) {
      emit(
        state.copyWith(
          status: DealsAttachmentStatus.error,
          message: e.message ?? e.code,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DealsAttachmentStatus.error,
          message: e.toString(),
        ),
      );
    }
  }
}