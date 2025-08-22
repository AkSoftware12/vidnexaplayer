class OnboardingContents {
  final String title;
  final String image;
  final String desc;

  OnboardingContents({
    required this.title,
    required this.image,
    required this.desc,
  });
}

List<OnboardingContents> contents = [
  OnboardingContents(
    title: "Never Give Up!",
    image: "assets/first.png",
    desc: "Organize and manage all your files effortlessly. Access documents, videos, images, and music fromone powerful file manager.",
  ),
  OnboardingContents(
    title: "Polish your Skills",
    image: "assets/second.png",
    desc:
        "Master advanced file management techniques. Sort, search, and organize your digital content withpowerful tools and features.",
  ),
  OnboardingContents(
    title: "Secure Files",
    image: "assets/third.png",
    desc:
        "Protect your files and secure your data with our security technology. Keep your documents safe andorganized.",
  ),
];
