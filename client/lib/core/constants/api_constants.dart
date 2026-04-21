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
  static const String registerRequest = '$apiPrefix/auth/register/request';
  static const String registerVerify = '$apiPrefix/auth/register/verify';
  static const String logout = '$apiPrefix/auth/logout';
  static const String refresh = '$apiPrefix/auth/refresh';
  static const String me = '$apiPrefix/auth/me';

  // Exercises
  static const String listExercises = '$apiPrefix/exercises/listExercises';
  static const String byMuscleGroup = '$apiPrefix/exercises/byMuscleGroup';
  static const String createExercise = '$apiPrefix/exercises/createExercise';
  static String getExercise(String id) => '$apiPrefix/exercises/getExercise/$id';
  static String updateExercise(String id) => '$apiPrefix/exercises/updateExercise/$id';
  static const String searchExercises = '$apiPrefix/exercises/search';
  static String deactivateExercise(String id) =>
      '$apiPrefix/exercises/deactivateExercise/$id';

  // Joint exercises
  static const String listJointExercises = '$apiPrefix/joint-exercises/list';
  static const String createJointExercise = '$apiPrefix/joint-exercises/create';
  static String updateJointExercise(String id) => '$apiPrefix/joint-exercises/update/$id';
  static String deactivateJointExercise(String id) => '$apiPrefix/joint-exercises/deactivate/$id';

  // Routines
  static const String listRoutines = '$apiPrefix/routines/listRoutines';
  static const String createRoutine = '$apiPrefix/routines/createRoutine';
  static const String myDefaultRoutine = '$apiPrefix/routines/myDefault';
  static String getRoutine(String id) => '$apiPrefix/routines/getRoutine/$id';
  static String updateRoutine(String id) => '$apiPrefix/routines/updateRoutine/$id';
  static String deleteRoutine(String id) => '$apiPrefix/routines/deleteRoutine/$id';
  static String setDefaultRoutine(String id) => '$apiPrefix/routines/setDefault/$id';
  static String copyRoutine(String id) => '$apiPrefix/routines/copyRoutine/$id';

  // Notifications
  static const String notificationsList = '$apiPrefix/notifications/list';
  static const String notificationsUnreadCount = '$apiPrefix/notifications/unreadCount';
  static const String notificationsReadAll = '$apiPrefix/notifications/readAll';
  static String notificationRead(String id) => '$apiPrefix/notifications/read/$id';
  static const String notificationsCreate = '$apiPrefix/notifications/create';

  // Lift Submissions (nuevo sistema de postulación al ranking)
  static const String liftSubmissions = '$apiPrefix/lift-submissions';
  static String liftSubmission(String id) => '$apiPrefix/lift-submissions/$id';
  static String liftSubmissionApprove(String id) => '$apiPrefix/lift-submissions/$id/approve';
  static String liftSubmissionReject(String id) => '$apiPrefix/lift-submissions/$id/reject';
  static const String liftRankings = '$apiPrefix/lift-submissions/rankings';
  static const String liftRecords = '$apiPrefix/lift-submissions/records';

  // Rankings (legacy)
  static const String rankingsExercises = '$apiPrefix/rankings/exercises';
  static const String rankingsPending = '$apiPrefix/rankings/pending';
  static String rankingsLeaderboard(String exerciseId) => '$apiPrefix/rankings/leaderboard/$exerciseId';
  static String rankingsValidate(String recordId) => '$apiPrefix/rankings/validate/$recordId';
  static String rankingsReject(String recordId) => '$apiPrefix/rankings/reject/$recordId';

  // History
  static const String historyTrainedExercises = '$apiPrefix/history/trainedExercises';
  static const String historyRecords = '$apiPrefix/history/records';
  static const String historyMeasurements = '$apiPrefix/history/measurements';
  static String historyProgress(String exerciseId) => '$apiPrefix/history/progress/$exerciseId';
  static String historyDeleteMeasurement(String id) => '$apiPrefix/history/measurements/$id';

  // Articles
  static const String listArticles = '$apiPrefix/articles/list';
  static const String articleFavorites = '$apiPrefix/articles/favorites';
  static const String createArticle = '$apiPrefix/articles/create';
  static String getArticle(String id) => '$apiPrefix/articles/get/$id';
  static String updateArticle(String id) => '$apiPrefix/articles/update/$id';
  static String deactivateArticle(String id) => '$apiPrefix/articles/deactivate/$id';
  static String toggleArticleFavorite(String id) => '$apiPrefix/articles/$id/favorite';

  // Events
  static const String listEvents = '$apiPrefix/events/list';
  static const String myEventInterests = '$apiPrefix/events/my-interests';
  static const String createEvent = '$apiPrefix/events/create';
  static String getEvent(String id) => '$apiPrefix/events/get/$id';
  static String updateEvent(String id) => '$apiPrefix/events/update/$id';
  static String deactivateEvent(String id) => '$apiPrefix/events/deactivate/$id';
  static String toggleEventInterest(String id) => '$apiPrefix/events/$id/interest';

  // Workout
  static const String workoutStart = '$apiPrefix/workout/start';
  static const String workoutActive = '$apiPrefix/workout/active';
  static const String workoutLogSet = '$apiPrefix/workout/logSet';
  static const String workoutHistory = '$apiPrefix/workout/history';
  static String workoutFinish(String id) => '$apiPrefix/workout/finish/$id';
  static String workoutSession(String id) => '$apiPrefix/workout/session/$id';
  static String workoutCancel(String id) => '$apiPrefix/workout/cancel/$id';
}
