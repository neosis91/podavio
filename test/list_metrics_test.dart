import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/settings/settings_controller.dart';
import 'package:podavio/ui/widgets/list_metrics.dart';

void main() {
  final textTheme = Typography.material2021().black;

  EpisodeTileMetrics metrics({
    required double width,
    EpisodeListDensity density = EpisodeListDensity.comfortable,
    double textScale = 1,
  }) {
    return EpisodeTileMetrics.resolve(
      width: width,
      textTheme: textTheme,
      textScaler: TextScaler.linear(textScale),
      density: density,
      played: false,
      onSurface: const Color(0xFF000000),
      muted: const Color(0xFF666666),
    );
  }

  test('listWidthTier matches subscription breakpoints', () {
    expect(listWidthTier(320), ListWidthTier.narrow);
    expect(listWidthTier(359), ListWidthTier.narrow);
    expect(listWidthTier(360), ListWidthTier.phone);
    expect(listWidthTier(599), ListWidthTier.phone);
    expect(listWidthTier(600), ListWidthTier.tablet);
    expect(listWidthTier(899), ListWidthTier.tablet);
    expect(listWidthTier(900), ListWidthTier.large);
  });

  test('cover size grows with width tier and stays within clamps', () {
    final narrow = metrics(width: 320);
    final phone = metrics(width: 400);
    final large = metrics(width: 1000);

    expect(narrow.coverSize, inInclusiveRange(52, 72));
    expect(phone.coverSize, inInclusiveRange(56, 88));
    expect(large.coverSize, inInclusiveRange(64, 96));
    expect(large.coverSize, greaterThanOrEqualTo(narrow.coverSize));
  });

  test('compact density uses smaller type and cover than comfortable', () {
    final comfortable = metrics(width: 400);
    final compact = metrics(
      width: 400,
      density: EpisodeListDensity.compact,
    );

    expect(
      compact.titleStyle.fontSize!,
      lessThan(comfortable.titleStyle.fontSize!),
    );
    expect(compact.coverSize, lessThanOrEqualTo(comfortable.coverSize));
    expect(compact.gap, lessThanOrEqualTo(comfortable.gap));
  });

  test('textScaler enlarges cover but stays clamped', () {
    final normal = metrics(width: 400);
    final scaled = metrics(width: 400, textScale: 1.5);

    expect(scaled.coverSize, greaterThanOrEqualTo(normal.coverSize));
    expect(scaled.coverSize, lessThanOrEqualTo(88));
  });

  test('title is larger on desktop than on narrow', () {
    final narrow = metrics(width: 320);
    final large = metrics(width: 1000);

    expect(
      large.titleStyle.fontSize!,
      greaterThan(narrow.titleStyle.fontSize!),
    );
  });

  test('progress bar height is 2 on compact/narrow and 3 otherwise', () {
    expect(metrics(width: 320).progressBarHeight, 2);
    expect(
      metrics(width: 320, density: EpisodeListDensity.compact).progressBarHeight,
      2,
    );
    expect(
      metrics(width: 400, density: EpisodeListDensity.compact).progressBarHeight,
      2,
    );
    expect(metrics(width: 400).progressBarHeight, 3);
    expect(metrics(width: 1000).progressBarHeight, 3);
  });

  test('trailing hides percent on narrow and grows hit target with width', () {
    final narrow = metrics(width: 320);
    final phone = metrics(width: 400);
    final tablet = metrics(width: 700);
    final large = metrics(width: 1000);
    final largeCompact = metrics(
      width: 1000,
      density: EpisodeListDensity.compact,
    );

    expect(narrow.showDownloadPercent, isFalse);
    expect(phone.showDownloadPercent, isTrue);
    expect(narrow.trailingMinSize, inInclusiveRange(32, 36));
    expect(phone.trailingMinSize, inInclusiveRange(32, 36));
    expect(tablet.trailingMinSize, greaterThanOrEqualTo(40));
    expect(large.trailingMinSize, greaterThanOrEqualTo(44));
    expect(large.trailingMinSize, greaterThan(largeCompact.trailingMinSize));
    expect(narrow.trailingVisualDensity, VisualDensity.compact);
    expect(phone.trailingVisualDensity, VisualDensity.compact);
  });

  test('horizontal padding follows plan tiers', () {
    expect(listHorizontalPadding(320), 12);
    expect(listHorizontalPadding(400), 16);
    expect(listHorizontalPadding(700), 20);
    expect(listHorizontalPadding(1000), 24);
    expect(metrics(width: 320).horizontalPadding, 12);
    expect(metrics(width: 1000).horizontalPadding, 24);
  });
}
