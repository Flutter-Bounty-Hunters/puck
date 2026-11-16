import 'dart:io';

int? processMemoryBytes() {
  try {
    return ProcessInfo.currentRss;
  } on UnsupportedError {
    return null;
  }
}
