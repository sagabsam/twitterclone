import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twitter_clone/common/common.dart';
import 'package:twitter_clone/features/auth/controller/auth_controller.dart';
import 'package:twitter_clone/features/tweet/widgets/tweet_card.dart';
import 'package:twitter_clone/features/user_profile/controller/user_profile_controller.dart';
import 'package:twitter_clone/features/user_profile/view/edit_profile_view.dart';
import 'package:twitter_clone/features/user_profile/widget/follow_count.dart';
import 'package:twitter_clone/models/user_model.dart';
import 'package:twitter_clone/theme/theme.dart';

class UserProfile extends ConsumerWidget {
  final UserModel user;
  const UserProfile({super.key, required this.user});
  
  get currentUserDetailsProvider => null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserDetailsProvider).value;

    return currentUser == null
      ? const Loader() 
      : NestedScrollView(headerSliverBuilder: (context, innerBoxIsScrolled) {
      return [
        SliverAppBar(
          expandedHeight: 150,
          floating: true,
          snap: true,
          flexibleSpace: Stack(
            children: [
              Positioned.fill(
                child: user.bannerPic.isEmpty
                  ? Container(
                      color: Pallete.blueColor,
                    )
                  : Image.network(
                      user.bannerPic,
                      fit: BoxFit.fitWidth,
                    ),
              ),
              Positioned(
                bottom: 0,
                child: CircleAvatar(
                  backgroundImage: NetworkImage(user.profilePic),
                  radius: 45,
                ),
              ),
              Container(
                alignment: Alignment.bottomRight,
                margin: const EdgeInsets.all(20),
                child: OutlinedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: Pallete.whiteColor,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                  ),
                  child: Text(
                    currentUser.uid == user.uid
                        ? 'Edit Profile'
                        : 'Follow',
                    style: const TextStyle(color: Pallete.whiteColor,),
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${user.name}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Pallete.greyColor,
                  ),
                ),
                Text(
                  user.bio,
                  style: const TextStyle(
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FollowCount(
                      count: user.following.length -1,
                      text: 'Following',
                    ),
                    const SizedBox(width: 15),
                    FollowCount(
                      count: user.followers.length -1,
                      text: 'Followers',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Divider(color: Pallete.whiteColor),
              ],
            ),
          ),
        ),
      ];
    }, 
    body: ref.watch(getUserTweetsProvider(user.uid)).when(
      data: (tweets) {
        return ListView.builder(
          itemCount: tweets.length,
          itemBuilder: (BuildContext context, int index) {
            final tweet = tweets[index];
            return TweetCard(tweet: tweet);
          },
        );
      },
      error: (error, st) => ErrorText(
        error: error.toString(),
      ),
      loading: () => const Loader(),
    ),
    );
  }
}