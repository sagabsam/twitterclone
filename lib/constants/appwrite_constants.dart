class AppwriteConstants {
  static const String databaseId = '642ceeb1513f8125d48a';
  static const String projectId = '6423b863e507ca34da75';
  static const String endPoint = 'https://baas.pasarjepara.com/v1';
  static const String usersCollection = '642ceeb1513f8125d48a';
  static const String tweetCollection = '64aa1a5302af1ef71cf5';
  static const String notificationsCollection = '64aa73cb0888e8509dad';
  static const String imagesBucket = '64aa1b8167146ce07a83';
  static String imageUrl(String imageId) => 
  '$endPoint/storage/buckets/$imagesBucket/files/$imageId/view?project=$projectId&mode=admin';
}