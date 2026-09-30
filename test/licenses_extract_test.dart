import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/core/licenses.dart';

void main() {
  test('extractLicenseCreators reads copyright holders', () {
    expect(
      extractLicenseCreators(
        'Copyright (c) 2020 Alice Example.\nAll rights reserved.\n\nMIT License',
      ),
      ['Alice Example'],
    );
    expect(
      extractLicenseCreators(
        'Copyright 2012, the Dart project authors.\n\nRedistribution...',
      ),
      ['the Dart project authors'],
    );
    expect(extractLicenseCreators('© 2019 Bob Builder\n\nApache License'), [
      'Bob Builder',
    ]);
  });

  test('friendlyLicenseName humanizes package ids', () {
    expect(friendlyLicenseName('cached_network_image'), 'Cached Network Image');
    expect(friendlyLicenseName('go_router'), 'Go Router');
    expect(friendlyLicenseName('flutter'), 'Flutter');
    expect(friendlyLicenseName('saf_util'), 'SAF Util');
    expect(friendlyLicenseName('xml'), 'XML');
    expect(friendlyLicenseName('file_picker_ios'), 'File Picker iOS');
  });
}
