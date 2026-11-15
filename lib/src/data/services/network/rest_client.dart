import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'endpoints.dart';

part 'rest_client.g.dart';

@RestApi()
abstract class RestClient {
  factory RestClient(Dio dio, {String? baseUrl}) = _RestClient;

  @POST(Endpoints.token)
  @FormUrlEncoded()
  Future<dynamic> login(
    @Field('username') String username,
    @Field('password') String password,
  );

  /// The list shape is undocumented, so the raw JSON is parsed tolerantly.
  @GET(Endpoints.files)
  Future<dynamic> getFiles();

  @DELETE(Endpoints.delete)
  Future<void> deleteFile(@Query(Endpoints.fileQuery) String name);
}
