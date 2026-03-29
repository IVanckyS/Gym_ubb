// ignore_for_file: do_not_use_environment

class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String apiPrefix = '/api/v1';

  // Auth
  static const String login = '$apiPrefix/auth/login';
  static const String register = '$apiPrefix/auth/register';
  static const String logout = '$apiPrefix/auth/logout';
  static const String refresh = '$apiPrefix/auth/refresh';
  static const String me = '$apiPrefix/auth/me';

  // Exercises
  static const String listExercises = '$apiPrefix/exercises/listExercises';
  static const String byMuscleGroup = '$apiPrefix/exercises/byMuscleGroup';
  static const String createExercise = '$apiPrefix/exercises/createExercise';
  static String getExercise(String id) => '$apiPrefix/exercises/getExercise/$id';
  static String updateExercise(String id) => '$apiPrefix/exercises/updateExercise/$id';
  static String deactivateExercise(String id) =>
      '$apiPrefix/exercises/deactivateExercise/$id';
}
