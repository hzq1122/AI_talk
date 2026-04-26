import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

// ─── 配置模型 ────────────────────────────────────────────────────────────────────

enum CloudType { webdav, s3 }

abstract class CloudStorageConfig {
  const CloudStorageConfig();
  Map<String, dynamic> toJson();
}

class WebDavConfig extends CloudStorageConfig {
  final String url;
  final String username;
  final String password;

  const WebDavConfig(
      {required this.url, required this.username, required this.password});

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'webdav', 'url': url, 'username': username, 'password': password};

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
        url: json['url'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
      );
}

class S3Config extends CloudStorageConfig {
  final String endpoint;
  final String region;
  final String accessKey;
  final String secretKey;
  final String bucket;

  const S3Config({
    required this.endpoint,
    required this.region,
    required this.accessKey,
    required this.secretKey,
    required this.bucket,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 's3',
        'endpoint': endpoint,
        'region': region,
        'accessKey': accessKey,
        'secretKey': secretKey,
        'bucket': bucket,
      };

  factory S3Config.fromJson(Map<String, dynamic> json) => S3Config(
        endpoint: json['endpoint'] as String,
        region: json['region'] as String,
        accessKey: json['accessKey'] as String,
        secretKey: json['secretKey'] as String,
        bucket: json['bucket'] as String,
      );
}

// ─── 抽象接口 ────────────────────────────────────────────────────────────────────

abstract class CloudStorage {
  Future<bool> testConnection();
  Future<bool> upload(String localPath, String remoteName);
  Future<String?> download(String remoteName, String localPath);
  Future<List<String>> listBackups();

  static CloudStorage fromConfig(CloudStorageConfig config) {
    if (config is WebDavConfig) return WebDavStorage(config);
    if (config is S3Config) return S3Storage(config);
    throw ArgumentError('Unknown config type: ${config.runtimeType}');
  }
}

// ─── WebDAV 实现 ──────────────────────────────────────────────────────────────────

class WebDavStorage implements CloudStorage {
  final WebDavConfig config;
  late final Dio _dio;

  WebDavStorage(this.config) {
    final base = config.url.endsWith('/') ? config.url : '${config.url}/';
    _dio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      },
    ));
  }

  @override
  Future<bool> testConnection() async {
    try {
      final resp = await _dio.request('/',
          options:
              Options(method: 'PROPFIND', headers: {'Depth': '0'}));
      return resp.statusCode != null && resp.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> upload(String localPath, String remoteName) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      await _dio.put(remoteName,
          data: bytes,
          options: Options(
              headers: {'Content-Type': 'application/octet-stream'}));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> download(String remoteName, String localPath) async {
    try {
      await _dio.download(remoteName, localPath);
      return localPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listBackups() async {
    try {
      final resp = await _dio.request('/',
          options:
              Options(method: 'PROPFIND', headers: {'Depth': '1'}));
      final body = resp.data.toString();
      final regex = RegExp(r'<D:href>([^<]+)</D:href>');
      return regex
          .allMatches(body)
          .map((m) => m.group(1)!.split('/').last)
          .where((n) => n.endsWith('.zip'))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ─── S3 兼容实现 (AWS Signature V4) ──────────────────────────────────────────────

class S3Storage implements CloudStorage {
  final S3Config config;
  final Dio _dio;

  S3Storage(this.config)
      : _dio = Dio(BaseOptions(
          baseUrl:
              config.endpoint.endsWith('/') ? config.endpoint : '${config.endpoint}/',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ));

  String _host() => Uri.parse(config.endpoint).host;

  Map<String, String> _signedHeaders(String method, String path,
      {String? body}) {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDateStr(now);
    final dateStamp = amzDate.substring(0, 8);

    final bodyHash =
        sha256.convert(utf8.encode(body ?? '')).toString();

    final headers = <String, String>{
      'Host': _host(),
      'x-amz-date': amzDate,
      'x-amz-content-sha256': bodyHash,
    };

    final signedHeaderKeys = ['host', 'x-amz-content-sha256', 'x-amz-date'];
    final canonicalHeaders =
        signedHeaderKeys.map((k) => '$k:${headers[k]!}').join('\n');
    final signedHeaders = signedHeaderKeys.join(';');

    final canonicalRequest = [
      method,
      '/${config.bucket}$path',
      '',
      canonicalHeaders,
      '',
      signedHeaders,
      bodyHash,
    ].join('\n');

    final algorithm = 'AWS4-HMAC-SHA256';
    final credentialScope =
        '$dateStamp/${config.region}/s3/aws4_request';
    final stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    final kDate = Hmac(sha256, utf8.encode('AWS4${config.secretKey}'))
        .convert(utf8.encode(dateStamp));
    final kRegion =
        Hmac(sha256, kDate.bytes).convert(utf8.encode(config.region));
    final kService =
        Hmac(sha256, kRegion.bytes).convert(utf8.encode('s3'));
    final kSigning = Hmac(sha256, kService.bytes)
        .convert(utf8.encode('aws4_request'));
    final signature = Hmac(sha256, kSigning.bytes)
        .convert(utf8.encode(stringToSign))
        .toString();

    headers['Authorization'] =
        '$algorithm Credential=${config.accessKey}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    return headers;
  }

  String _amzDateStr(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
      'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}${dt.second.toString().padLeft(2, '0')}Z';

  @override
  Future<bool> testConnection() async {
    try {
      final resp = await _dio.head('${config.bucket}',
          options: Options(headers: _signedHeaders('HEAD', '')));
      return resp.statusCode != null && resp.statusCode! < 400;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> upload(String localPath, String remoteName) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final resp = await _dio.put('${config.bucket}/$remoteName',
          data: bytes,
          options:
              Options(headers: _signedHeaders('PUT', '/$remoteName')));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> download(String remoteName, String localPath) async {
    try {
      await _dio.download('${config.bucket}/$remoteName', localPath,
          options:
              Options(headers: _signedHeaders('GET', '/$remoteName')));
      return localPath;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> listBackups() async {
    try {
      final resp = await _dio.get('${config.bucket}',
          options: Options(headers: _signedHeaders('GET', '')));
      final body = resp.data.toString();
      final regex = RegExp(r'<Key>([^<]+)</Key>');
      return regex
          .allMatches(body)
          .map((m) => m.group(1)!)
          .where((n) => n.endsWith('.zip'))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
