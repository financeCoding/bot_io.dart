part of bot_io;

abstract class EntityValidator {

  static Stream<String> validateFileStringContent(File entity,
      String targetContent) {
    return validateFileContentSha(entity, _getStringSha1(targetContent));
  }

  static Stream<String> validateFileContentSha(File entity, String targetSha) {
    if(entity is! File) {
      return new Stream.fromIterable(['entity is not a File']);
    }
    assert(targetSha != null);
    assert(targetSha.length == 40);

    var future = fileSha1Hex(entity)
        .then((String sha1) {
          if(sha1 == targetSha) {
            return [];
          } else {
            return ['content does not match: $entity'];
          }
        });

    return _streamFromIterableFuture(future);
  }

  static Stream<String> validateDirectoryFromMap(Directory entity,
      Map<String, dynamic> map) {
    if(entity is! Directory) {
      return new Stream.fromIterable(['entity is not a Directory']);
    }

    final expectedItems = new Set.from(map.keys);

    return expandStream(entity.list(), (FileSystemEntity item) {

      final relative = pathos.relative(item.path,
          from: entity.path);

      final expected = expectedItems.remove(relative);
      if(expected) {
        return validate(item, map[relative]);
      } else {
        return new Stream.fromIterable(['Not expected: $item']);
      }

    }, onDone: () {
      return new Stream.fromIterable(expectedItems.map((item) {
          return 'Missing item $item';
        }));
    });
  }

  static Stream<String> validate(FileSystemEntity entity, dynamic target) {
    if(target is EntityValidator) {
      return target.validateEntity(entity);
    } else if(target is String) {
      return validateFileStringContent(entity, target);
    } else if(target is Map) {
      return validateDirectoryFromMap(entity, target);
    } else {
      throw "Don't know how to deal with $target";
    }
  }

  Stream<String> validateEntity(FileSystemEntity entity);
}

class EntityExistsValidator implements EntityValidator {
  final FileSystemEntityType entityType;

  EntityExistsValidator([this.entityType]) {
    assert(entityType != FileSystemEntityType.NOT_FOUND);
  }

  @override
  Stream<String> validateEntity(FileSystemEntity entity) {
    assert(entity != null);
    return _streamFromIterableFuture(_getValidation(entity));
  }

  Future<List<String>> _getValidation(FileSystemEntity entity) {
    assert(entity != null);

    final entType = _getType(entity);
    if(entityType == null || entityType == entType) {
      return _exists(entity)
          .then((bool exists) {
            if(exists) {
              return [];
            }
            return ["$entity does not exist on disk"];
          });
    }

    return new Future.value(["Expected $entity to be $entityType,"
                             " but it is $entType"]);
  }

  static Future<bool> _exists(FileSystemEntity entity) {
    if(entity is Directory) {
      return entity.exists();
    } else if(entity is File) {
      return entity.exists();
    } else if(entity is Link) {
      return entity.exists();
    }
    throw 'entity $entity is not supported';
  }

  static FileSystemEntityType _getType(FileSystemEntity entity) {
    assert(entity != null);
    if(entity is File) {
      return FileSystemEntityType.FILE;
    } else if(entity is Directory) {
      return FileSystemEntityType.DIRECTORY;
    } else {
      assert(entity is Link);
      return FileSystemEntityType.LINK;
    }
  }
}

// TODO: move to bot?
// TODO: should this use pause/resume? Maybe? Likely?
// TODO: test!
Stream expandStream(Stream source, Stream convert(input), {Stream onDone()}) {
  final controller = new StreamController();

  Future itemFuture;

  source.listen((sourceItem) {
    Stream subStream = convert(sourceItem);
    Future next = _pipeStreamToController(controller, subStream);
    if(itemFuture == null) {
      itemFuture = next;
    } else {
      itemFuture = itemFuture.then((_) => next);
    }
  }, onDone: () {
    Future next = _pipeStreamToController(controller, onDone());
    if(itemFuture == null) {
      itemFuture = next;
    } else {
      itemFuture = itemFuture.then((_) => next);
    }
    itemFuture.whenComplete(() {
      controller.close();
    });
  });

  return controller.stream;
}

// TODO: move to bot?
Future _pipeStreamToController(StreamController controller, Stream input) {
  final completer = new Completer();

  input.listen((data) {
    controller.add(data);
  }, onDone: () {
    completer.complete();
  });

  return completer.future;
}

// TODO: move to bot?
Stream _streamFromIterableFuture(Future<Iterable> future) {
  final controller = new StreamController();

  future
    .then((Iterable values) {
      for(var value in values) {
        controller.add(value);
      }
    })
    .catchError((error) {
      controller.addError(error, getAttachedStackTrace(error));
    })
    .whenComplete(() {
      controller.close();
    });

  return controller.stream;
}

String _getStringSha1(String content) {
  final bytes = utf.encodeUtf8(content);
  final sha = new crypto.SHA1();
  sha.add(bytes);
  final sha1Bytes = sha.close();
  return crypto.CryptoUtils.bytesToHex(sha1Bytes);
}
