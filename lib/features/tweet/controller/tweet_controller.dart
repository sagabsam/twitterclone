import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twitter_clone/apis/storage_api.dart';
import 'package:twitter_clone/apis/tweet_api.dart';
import 'package:twitter_clone/core/core.dart';
import 'package:twitter_clone/core/emuns/tweet_type_enum.dart';
import 'package:twitter_clone/features/auth/controller/auth_controller.dart';
import 'package:twitter_clone/models/tweet_model.dart';
import 'package:twitter_clone/models/user_model.dart';
import 'package:twitter_clone/apis/notification_api.dart';
import 'package:twitter_clone/core/emuns/notification_type_enum.dart';
import 'package:twitter_clone/features/notifications/controller/notification_controller.dart';
import 'package:appwrite/appwrite.dart';

final tweetControllerProvider =
    StateNotifierProvider<TweetController, bool>((ref) {
  return TweetController(
    ref: ref, 
    tweetAPI: ref.watch(tweetAPIProvider),
    storageAPI: ref.watch(storageAPIProvider),
    notificationController: ref.watch(notificationControllerProvider.notifier),
  );
});

final getTweetsProvider = FutureProvider((ref) {
  final TweetController = ref.watch(tweetControllerProvider.notifier);
  return TweetController.getTweets();
});

final getRepliesToTweetsProvider = FutureProvider.family((ref, Tweet tweet) {
  final tweetController = ref.watch(tweetControllerProvider.notifier);
  return tweetController.getRepliesToTweet(tweet);
});

final getLatestTweetProvider = StreamProvider((ref) {
  final tweetAPI = ref.watch(tweetAPIProvider);
  return tweetAPI.getLatestTweet();
});

final getTweetByIdProvider = FutureProvider.family((ref, String id) async {
  final TweetController = ref.watch(tweetControllerProvider.notifier);
  return TweetController.getTweetById(id);
});

class TweetController extends StateNotifier<bool> {
  final TweetAPI _tweetAPI;
  final StorageAPI _storageAPI;
  final NotificationController _notificationController;
  final Ref _ref;
  TweetController(
      {
        required Ref ref,
        required TweetAPI tweetAPI,
        required StorageAPI storageAPI,
        required NotificationController notificationController,
      })
      : _ref = ref,
        _tweetAPI = tweetAPI,
        _storageAPI = storageAPI,
        _notificationController = notificationController,
        super(false);
        
           get currentUserDetailsProvider => null;

  Future<List<Tweet>> getTweets() async {
    final tweetList = await _tweetAPI.getTweets();
    return tweetList.map((tweet) => Tweet.fromMap(tweet.data)).toList();
  }

  Future<Tweet> getTweetById(String id) async {
    final tweet = await _tweetAPI.getTweetById(id);
    return Tweet.fromMap(tweet.data);
  }

  void likeTweet(Tweet tweet, UserModel user) async {
    List<String> likes = tweet.likes;

    if (tweet.likes.contains(user.uid)) {
      likes.remove(user.uid);
    } else {
      likes.add(user.uid);
    }

    tweet = tweet.copyWith(
      likes: likes, retweetedBy: '',
    );
    final res = await _tweetAPI.likeTweet(tweet);
    res.fold((l) => null, (r) => {
      _notificationController.createNotification(
        text: '${user.name} liked your tweet!', 
        postId: tweet.id, 
        notificationType: NotificationType.like, 
        uid: tweet.uid,
      ),
    });
  }
  void reshareTweet(
      Tweet tweet, UserModel currentUser, BuildContext context) async {
    tweet = tweet.copyWith(
      retweetedBy: currentUser.name,
      likes: [],
      commentIds: [],
      reshareCount: tweet.reshareCount + 1,
    );
    final res = await _tweetAPI.updateReshareCount(tweet);
    res.fold(
      (l) => showSnackbar(context, l.message),
      (r) async {
        tweet = tweet.copyWith(
          id: ID.unique(),
          reshareCount: 0,
          tweetedAt: DateTime.now(), retweetedBy: '',
        );
        final res2 = await _tweetAPI.shareTweet(tweet);
        res2.fold((l) => showSnackbar(context, l.message), (r) {
          _notificationController.createNotification(
            text: '${currentUser.name} reshare your tweet!',
            postId: tweet.id,
            notificationType: NotificationType.retweet,
            uid: tweet.uid,
          );
          showSnackbar(context, 'Retweeted!');
        });
      },
    );
  }

  void shareTweet({
    required List<File> images,
    required String text,
    required BuildContext context,
    required String repliedTo,
    required String repliedToUserId,
  }) {
    if (text.isEmpty) {
      showSnackbar(context, 'Please Enter Text');
      return;
    }
    if (images.isNotEmpty) {
      _shareImageTweet(images: images, text: text, context: context, repliedTo: repliedTo, repliedToUserId: repliedToUserId,);
    } else {
      _shareTextTweet(text: text, context: context, repliedTo: repliedTo, repliedToUserId: repliedToUserId,);
    }
  }

  Future<List<Tweet>> getRepliesToTweet(Tweet tweet) async {
    final documents = await _tweetAPI.getRepliesToTweet(tweet);
    return documents.map((tweet) => Tweet.fromMap(tweet.data)).toList();
  }

  void _shareImageTweet({
    required List<File> images,
    required String text,
    required BuildContext context,
    required String repliedTo,
    required String repliedToUserId,
  }) async {
    state = true;
    final hashtags = _getHashtagsFromText(text);
    String link = _getLinkFromText(text);
    final user = _ref.read(currentUserDetailsProvider).value!;
    final imageLinks = await _storageAPI.uploadImage(images);
    Tweet tweet = Tweet(
      text: text,
      hashtags: hashtags,
      link: link,
      imageLinks: imageLinks,
      uid: user.uid,
      tweetType: TweetType.image,
      tweetedAt: DateTime.now(),
      likes: const [],
      commentIds: const [],
      id: '',
      reshareCount: 0, 
      retweetedBy: '',
      repliedTo: repliedTo,
    );
    final res = await _tweetAPI.shareTweet(tweet);
    res.fold((l) => showSnackbar(context, l.message), (r) => {
      if(repliedToUserId.isNotEmpty) {
        _notificationController.createNotification(
            text: '${user.name} replied to your tweet!',
            postId: r.$id,
            notificationType: NotificationType.reply,
            uid: repliedToUserId,
          ),
      }
    });
    state = false;
    res.fold((l) => showSnackbar(context, l.message), (r) => null);
  }

  void _shareTextTweet({
    required String text,
    required BuildContext context,
    required String repliedTo,
    required String repliedToUserId,
  }) async {
    state = true;
    final hashtags = _getHashtagsFromText(text);
    String link = _getLinkFromText(text);
    final user = _ref.read(currentUserDetailsProvider).value!;
    Tweet tweet = Tweet(
      text: text,
      hashtags: hashtags,
      link: link,
      imageLinks: const [],
      uid: user.uid,
      tweetType: TweetType.text,
      tweetedAt: DateTime.now(),
      likes: const [],
      commentIds: const [],
      id: '',
      reshareCount: 0, retweetedBy: '', repliedTo: '',
    );
    final res = await _tweetAPI.shareTweet(tweet);
    res.fold((l) => showSnackbar(context, l.message), (r) => {
      if(repliedToUserId.isNotEmpty) {
        _notificationController.createNotification(
            text: '${user.name} replied to your tweet!',
            postId: r.$id,
            notificationType: NotificationType.reply,
            uid: repliedToUserId,
          ),
      }
    });
    state = false;
  }

  String _getLinkFromText(String text) {
    String link = '';
    List<String> wordsInSentence = text.split(' ');
    for (String word in wordsInSentence) {
      if (word.startsWith('https://') || word.startsWith('www.')) {
        link = word;
      }
    }
    return link;
  }

  List<String> _getHashtagsFromText(String text) {
    List<String> hashtags = [];
    List<String> wordsInSentence = text.split(' ');
    for (String word in wordsInSentence) {
      if (word.startsWith('#')) {
        hashtags.add(word);
      }
    }
    return hashtags;
  }
}