extends Node

class_name PuzzleStorageProvider

const CACHE_ROOT := "user://puzzle_cache"

## Ensures a puzzle directory (image + size-specific folder) exists in cache.
## Returns the resolved base path (without size suffix) that callers should use
## as `base_file_path`.
func ensure_puzzle_cached(puzzle: Dictionary, size: int) -> String:
        var base_name: String = puzzle.get("base_name", "")
        if base_name == "":
                return ""
        var cache_base := CACHE_ROOT + "/" + base_name
        var cache_size_dir := cache_base + "_" + str(size)
        if DirAccess.dir_exists_absolute(cache_size_dir):
                return cache_base

        DirAccess.make_dir_recursive(cache_size_dir)
        var storage_base: String = puzzle.get("storage_base_path", puzzle.get("base_file_path", ""))

        if storage_base != "":
                await _download_bundle(storage_base, base_name, size, cache_base)

        if not DirAccess.dir_exists_absolute(cache_size_dir):
                _copy_local_bundle(storage_base, base_name, size, cache_base)

        return cache_base

func _copy_local_bundle(storage_base: String, base_name: String, size: int, cache_base: String) -> void:
        var source_base := storage_base
        if source_base == "":
                source_base = "res://assets/puzzles/jigsawpuzzleimages/" + base_name
        var source_image := source_base + ".jpg"
        var source_dir := source_base + "_" + str(size)
        var target_image := cache_base + ".jpg"
        var target_dir := cache_base + "_" + str(size)

        if FileAccess.file_exists(source_image):
                var bytes = FileAccess.get_file_as_bytes(source_image)
                var file := FileAccess.open(target_image, FileAccess.WRITE)
                if file:
                        file.store_buffer(bytes)

        if DirAccess.dir_exists_absolute(source_dir):
                _copy_dir_recursive(source_dir, target_dir)

func _copy_dir_recursive(source_dir: String, target_dir: String) -> void:
        DirAccess.make_dir_recursive(target_dir)
        var dir := DirAccess.open(source_dir)
        if dir == null:
                return
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
                if file_name.begins_with("."):
                        file_name = dir.get_next()
                        continue
                var source_path = source_dir + "/" + file_name
                var target_path = target_dir + "/" + file_name
                if dir.current_is_dir():
                        _copy_dir_recursive(source_path, target_path)
                else:
                        var bytes = FileAccess.get_file_as_bytes(source_path)
                        var file := FileAccess.open(target_path, FileAccess.WRITE)
                        if file:
                                file.store_buffer(bytes)
                file_name = dir.get_next()
        dir.list_dir_end()

func _download_bundle(storage_base: String, base_name: String, size: int, cache_base: String) -> void:
        if typeof(Firebase) == TYPE_NIL or not Firebase.has_method("Storage"):
                return
        var storage = Firebase.Storage
        if storage == null:
                return
        var size_dir := storage_base + "_" + str(size)
        var target_dir := cache_base + "_" + str(size)
        await _download_directory(storage, size_dir, target_dir)

        var source_image := storage_base + ".jpg"
        var target_image := cache_base + ".jpg"
        await _download_file_if_exists(storage, source_image, target_image)

func _download_directory(storage, storage_dir: String, target_dir: String) -> void:
        if not storage.has_method("list") or not storage.has_method("download_file"):
                return
        DirAccess.make_dir_recursive(target_dir)
        var list_result = await storage.list(storage_dir)
        if list_result is Dictionary:
                var items: Array = list_result.get("items", [])
                for item_path in items:
                        var target_path := target_dir + "/" + _strip_storage_prefix(storage_dir, item_path)
                        DirAccess.make_dir_recursive(target_path.get_base_dir())
                        await _download_file_if_exists(storage, item_path, target_path)
                var prefixes: Array = list_result.get("prefixes", [])
                for prefix in prefixes:
                        var child_dir := target_dir + "/" + _strip_storage_prefix(storage_dir, prefix)
                        await _download_directory(storage, prefix, child_dir)

func _strip_storage_prefix(prefix: String, path: String) -> String:
        if path.begins_with(prefix):
                return path.substr(prefix.length() + int(path[prefix.length()] == '/'))
        return path.get_file()

func _download_file_if_exists(storage, storage_path: String, target_path: String) -> void:
        if not storage.has_method("get_metadata") or not storage.has_method("download_file"):
                return
        var meta = await storage.get_metadata(storage_path)
        if meta == null:
                return
        DirAccess.make_dir_recursive(target_path.get_base_dir())
        await storage.download_file(storage_path, target_path)
