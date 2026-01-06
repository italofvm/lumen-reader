import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bookmark_service.dart';

final bookmarkServiceProvider = Provider((ref) => BookmarkService());
