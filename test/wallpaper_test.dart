import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/wallpaper_colors.dart';

void main() {
  test('the desktop wallpaper is preferred over the panel', () {
    const config = '''
[Containments][2]
activityId=
lastScreen=0
plugin=org.kde.plasma.panel

[Containments][2][Wallpaper][org.kde.image][General]
Image=file:///wallpapers/panel.png

[Containments][1]
activityId=abc
lastScreen=0
plugin=org.kde.plasma.folder

[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///wallpapers/desktop.png
''';
    expect(kdeWallpaperFromConfig(config), '/wallpapers/desktop.png');
  });

  test('a plain path and a gnome uri are accepted', () {
    expect(
      filePathFromImageValue('/usr/share/wallpapers/next.jpg'),
      '/usr/share/wallpapers/next.jpg',
    );
    expect(
      gnomeUriToPath("'file:///home/ada/photo.png'"),
      '/home/ada/photo.png',
    );
  });
}
