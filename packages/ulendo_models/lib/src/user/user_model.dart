import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String role,
    String? profileImageUrl,
    @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime createdAt,
    @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
    required DateTime updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

DateTime _dateTimeFromJson(Object value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.parse(value);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  try {
    final converted = (value as dynamic).toDate();
    if (converted is DateTime) {
      return converted;
    }
  } catch (_) {
    // Not a Timestamp-like object.
  }

  throw FormatException('Unsupported timestamp value: $value');
}

String _dateTimeToJson(DateTime value) => value.toIso8601String();