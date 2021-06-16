import 'dart:convert';
import 'dart:typed_data';

import 'package:fimber/fimber.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class LoggingHttpClient extends http.BaseClient {
  Duration? requestTimeout;

  final IOClient _client = IOClient();

  LoggingHttpClient({this.requestTimeout});

  Future<Response> head(url, {Map<String, String>? headers}) => _sendUnstreamed("HEAD", url, headers);

  Future<Response> get(url, {Map<String, String>? headers}) => _sendUnstreamed("GET", url, headers);

  Future<Response> post(url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _sendUnstreamed("POST", url, headers, body, encoding);

  Future<Response> put(url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _sendUnstreamed("PUT", url, headers, body, encoding);

  Future<Response> patch(url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _sendUnstreamed("PATCH", url, headers, body, encoding);

  Future<Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _sendUnstreamed("DELETE", url, headers);

  Future<String> read(url, {Map<String, String>? headers}) {
    return get(url, headers: headers).then((response) {
      _checkResponseSuccess(url, response);
      return response.body;
    });
  }

  Future<Uint8List> readBytes(url, {Map<String, String>? headers}) {
    return get(url, headers: headers).then((response) {
      _checkResponseSuccess(url, response);
      return response.bodyBytes;
    });
  }

  Future<StreamedResponse> send(BaseRequest request) => _client.send(request);

  Future<Response> _sendUnstreamed(String method, url, Map<String, String>? headers, [body, Encoding? encoding]) async {
    if (url is String) url = Uri.parse(url);
    var request = new Request(method, url);

    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List) {
        request.bodyBytes = body.cast();
      } else if (body is Map) {
        request.bodyFields = body.cast();
      } else {
        throw new ArgumentError('Invalid request body "$body".');
      }
    }

    //Send interception
    String curlString = "curl -X $method ";
    for (MapEntry<String, String> entry in headers?.entries ?? {}) {
      curlString += _getHeaderString(entry);
    }
    curlString += "\"$body\" ";
    curlString += url.toString();
    curlString += " -L";
    Fimber.d("Sending request: \n $curlString");

    var stream = requestTimeout == null
        ? await send(request)
        : await send(request).timeout(requestTimeout ?? Duration(seconds: 0));

    return Response.fromStream(stream).then((Response response) {
      // var responseData = ResponseData.fromHttpResponse(response);
      Fimber.d("================================================================");
      Fimber.d("RESPONSE");
      Fimber.d("Status code: ${response.statusCode}");
      // Fimber.d("Headers:");
      // for (MapEntry<String, String> entry in response.headers.entries) {
      //   Fimber.d("${entry.key}: ${entry.value}");
      // }
      Fimber.d("----------------------------------------------------------------");
      Fimber.d("Body: ${response.body}");
      Fimber.d("Body Json: ${json.decode(response.body)}");
      Fimber.d("================================================================");

      return response;
    });
  }

  void _checkResponseSuccess(url, Response response) {
    if (response.statusCode < 400) return;
    var message = "Request to $url failed with status ${response.statusCode}";
    if (response.reasonPhrase != null) {
      message = "$message: ${response.reasonPhrase}";
    }
    if (url is String) url = Uri.parse(url);
    throw new ClientException("$message.", url);
  }

  void close() {
    _client.close();
  }

  String _getHeaderString(MapEntry<String, String> header) {
    return "-H \"${header.key}: ${header.value}\" ";
  }
}
