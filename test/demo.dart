import 'package:flutter/material.dart';
import 'package:skullet/skullet.dart';

class User {
  const User(this.name, this.handle, this.bio);
  final String name;
  final String handle;
  final String bio;
}

const sampleUser = User(
  'Sample Name',
  '@samplehandle',
  'A short bio that wraps over two lines of text in the card, roughly as long as a real one.',
);
const realUser = User(
  'Ada Lovelace',
  '@ada',
  'Wrote the first published algorithm for a machine, and saw that it could do far more than arithmetic.',
);

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.user, this.dark = false});
  final User user;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xFF111111);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(
          color: dark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      Text(
                        user.handle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? Colors.white : const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      'Follow',
                      style: TextStyle(
                        color: dark ? Colors.black : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              user.bio,
              style: TextStyle(fontSize: 14, height: 1.4, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

Widget host(
  Widget child, {
  RevealMode reveal = RevealMode.smart,
  bool debug = false,
  bool dark = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(fontFamily: 'Roboto'),
  home: SkulletProvider(
    reveal: reveal,
    debug: debug,
    mode: dark ? SkulletMode.dark : SkulletMode.light,
    child: Scaffold(
      backgroundColor: dark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  ),
);

Widget profile(
  User? data, {
  String? id,
  User? sample = sampleUser,
  bool loading = false,
  VoidCallback? onReveal,
  bool dark = false,
}) => Skeleton<User>(
  id: id,
  data: data,
  sample: sample,
  loading: loading,
  label: 'Loading profile',
  onReveal: onReveal,
  builder: (context, user) => ProfileCard(user: user, dark: dark),
);
