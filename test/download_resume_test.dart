import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/download_resume.dart';

void main() {
  test('a partial response continues after the saved bytes', () {
    final plan = planDownloadBody(
      statusCode: 206,
      partialBytes: 4,
      contentLength: 4,
      contentRange: 'bytes 4-7/8',
    );
    expect(plan.mode, DownloadBodyMode.append);
    expect(plan.already, 4);
    expect(plan.total, 8);
  });

  test('a full response replaces the partial', () {
    final plan = planDownloadBody(
      statusCode: 200,
      partialBytes: 4,
      contentLength: 8,
      contentRange: null,
    );
    expect(plan.mode, DownloadBodyMode.replace);
    expect(plan.already, 0);
    expect(plan.total, 8);
  });

  test('a range that does not match the partial is refused', () {
    final plan = planDownloadBody(
      statusCode: 206,
      partialBytes: 4,
      contentLength: 2,
      contentRange: 'bytes 2-3/8',
    );
    expect(plan.mode, DownloadBodyMode.restart);
  });

  test('a satisfied file is already complete', () {
    final plan = planDownloadBody(
      statusCode: 416,
      partialBytes: 8,
      contentRange: 'bytes */8',
    );
    expect(plan.mode, DownloadBodyMode.complete);
    expect(plan.total, 8);
  });

  test('an unusable range starts over', () {
    final plan = planDownloadBody(
      statusCode: 416,
      partialBytes: 4,
      contentRange: 'bytes */8',
    );
    expect(plan.mode, DownloadBodyMode.restart);
  });

  test('a partial longer than the announced file is not complete', () {
    final plan = planDownloadBody(
      statusCode: 416,
      partialBytes: 9,
      contentRange: 'bytes */8',
    );
    expect(plan.mode, DownloadBodyMode.restart);
    expect(plan.total, 8);
  });

  test('the validator prefers the etag', () {
    expect(downloadValidator({'etag': '"v1"', 'last-modified': 'Mon'}), '"v1"');
    expect(downloadValidator({'last-modified': ' Mon '}), 'Mon');
    expect(downloadValidator({}), isNull);
  });
}
