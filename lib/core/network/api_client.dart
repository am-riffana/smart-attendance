import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import 'mock_api_interceptor.dart';
import 'network_exceptions.dart';

/// Reusable Dio HTTP Client configured for Smart Attendance REST endpoints.
/// Integrates [MockApiInterceptor] for seamless local mock API testing and development.
class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio, bool enableMock = true})
      : _dio = dio ?? _createDefaultDio(enableMock: enableMock);

  Dio get dio => _dio;

  static Dio _createDefaultDio({bool enableMock = true}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1. Mock API Interceptor (intercepts /v1 endpoints with simulated mock data)
    if (enableMock) {
      dio.interceptors.add(MockApiInterceptor());
    }

    // 2. Development Logging Interceptor with sensitive token & password masking
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (kDebugMode) {
            // Mask authorization tokens in log output
            final sanitizedHeaders = Map<String, dynamic>.from(options.headers);
            if (sanitizedHeaders.containsKey('Authorization')) {
              sanitizedHeaders['Authorization'] = 'Bearer [PROTECTED]';
            }

            // Mask sensitive fields in body data
            dynamic sanitizedData = options.data;
            if (sanitizedData is Map) {
              final map = Map<String, dynamic>.from(sanitizedData);
              if (map.containsKey('password')) {
                map['password'] = '******';
              }
              sanitizedData = map;
            }

            debugPrint('[ApiClient -> ${options.method}] ${options.uri}');
            debugPrint('[ApiClient Headers] $sanitizedHeaders');
            if (sanitizedData != null) {
              debugPrint('[ApiClient Data] $sanitizedData');
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ApiClient <- ${response.statusCode}] ${response.requestOptions.method} ${response.requestOptions.uri}',
            );
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          if (kDebugMode) {
            debugPrint(
              '[ApiClient Error] ${error.type} on ${error.requestOptions.uri}: '
              'Status: ${error.response?.statusCode}, Message: ${error.message}',
            );
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  /// Sets authorization bearer token dynamically
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clears authorization bearer token on logout
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Reusable GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioException(e);
    }
  }

  /// Reusable POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioException(e);
    }
  }

  /// Reusable PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioException(e);
    }
  }

  /// Reusable DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDioException(e);
    }
  }
}
