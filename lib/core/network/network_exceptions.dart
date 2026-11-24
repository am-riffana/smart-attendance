import 'package:dio/dio.dart';

/// Exception wrapper translating DioException into domain-friendly network errors
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseData;

  const NetworkException({
    required this.message,
    this.statusCode,
    this.responseData,
  });

  factory NetworkException.fromDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkException(
          message: 'Connection timeout. Server took too long to respond.',
          statusCode: 408,
        );
      case DioExceptionType.sendTimeout:
        return const NetworkException(
          message: 'Request send timeout. Please verify your connection speed.',
          statusCode: 408,
        );
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          message: 'Response receive timeout. Server did not reply in time.',
          statusCode: 408,
        );
      case DioExceptionType.badResponse:
        final status = dioException.response?.statusCode;
        final data = dioException.response?.data;
        String errorMessage = 'Server responded with status $status';

        if (data is Map) {
          if (data.containsKey('message')) {
            errorMessage = data['message'].toString();
          } else if (data.containsKey('error')) {
            errorMessage = data['error'].toString();
          }
        }

        return NetworkException(
          message: errorMessage,
          statusCode: status,
          responseData: data,
        );
      case DioExceptionType.cancel:
        return const NetworkException(
          message: 'The network request was cancelled.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'Cannot reach server. Please check your network connection.',
        );
      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'Untrusted SSL certificate detected.',
          statusCode: 495,
        );
      case DioExceptionType.unknown:
      default:
        return NetworkException(
          message: dioException.message ?? 'An unexpected network error occurred.',
        );
    }
  }

  @override
  String toString() => 'NetworkException: [$statusCode] $message';
}
