import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';

/// Saves a remote attachment to the device's public Downloads folder,
/// mirroring the working implementation in DealsAttachmentCubit.
class AttachmentDownloader {
  AttachmentDownloader._();

  static const MethodChannel _downloadsChannel =
      MethodChannel('crm/downloads');

  static Future<String> saveToDownloads({
    required Dio dio,
    required String url,
    required String fileName,
  }) async {
    final lastDot = fileName.lastIndexOf('.');
    final baseName = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    final ext = lastDot > 0 ? fileName.substring(lastDot + 1) : '';

    if (Platform.isAndroid) {
      final response = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
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
          'mimeType': _mimeStringForExt(ext),
        },
      );

      if (savedPath == null || savedPath.isEmpty) {
        throw Exception('Failed to save file');
      }

      return savedPath;
    }

    final authHeader = dio.options.headers['Authorization']?.toString();

    final savedPath = await FileSaver.instance.saveFile(
      name: baseName,
      ext: ext,
      mimeType: _mimeTypeForExt(ext),
      link: LinkDetails(
        link: url,
        headers: {
          if (authHeader != null && authHeader.isNotEmpty)
            'Authorization': authHeader,
        },
      ),
    );

    return savedPath;
  }

  static MimeType _mimeTypeForExt(String ext) {
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

  static String _mimeStringForExt(String ext) {
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
}
