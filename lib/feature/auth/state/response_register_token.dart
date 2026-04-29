class ResponseRegisterToken {
  final String accessToken;
  final String refreshToken;

  ResponseRegisterToken({
    required this.accessToken,
    required this.refreshToken,
  });

  factory ResponseRegisterToken.fromJson(Map<String, dynamic> json) {
    return ResponseRegisterToken(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };
}
