extends Node

class_name PuzzleManifestLoader

const MANIFEST_CACHE_PATH := "user://puzzle_manifest.json"
const FIRESTORE_COLLECTION := "puzzles"
const MANIFEST_DOC_ID := "manifest"
const MANIFEST_FIELD := "puzzles"

var _manifest: Array = []
var _loading: bool = false

func _normalize_entry(entry: Dictionary) -> Dictionary:
        var normalized: Dictionary = {
                "file_name": entry.get("file_name", ""),
                "file_path": entry.get("file_path", ""),
                "base_name": entry.get("base_name", ""),
                "base_file_path": entry.get("base_file_path", ""),
                "storage_base_path": entry.get("storage_base_path", entry.get("base_file_path", "")),
                "available_sizes": entry.get("available_sizes", [10, 100, 1000])
        }
        if normalized["file_path"] == "" and normalized["base_file_path"] != "":
                normalized["file_path"] = normalized["base_file_path"] + ".jpg"
        normalized["thumbnail_storage_path"] = entry.get("thumbnail_storage_path", normalized["file_path"])
        return normalized

func load_manifest_from_cache(default_data: Array = []) -> Array:
        var file := FileAccess.open(MANIFEST_CACHE_PATH, FileAccess.READ)
        if file:
                var parsed = JSON.parse_string(file.get_as_text())
                if parsed is Array:
                        _manifest = []
                        for entry in parsed:
                                if entry is Dictionary:
                                        _manifest.append(_normalize_entry(entry))
        if _manifest.is_empty() and not default_data.is_empty():
                _manifest = _normalize_default(default_data)
        return _manifest

func save_manifest_to_cache() -> void:
        var file := FileAccess.open(MANIFEST_CACHE_PATH, FileAccess.WRITE)
        if not file:
                return
        var serialized: Array = []
        for entry in _manifest:
                if entry is Dictionary:
                        serialized.append(entry)
        file.store_string(JSON.stringify(serialized))

func get_manifest(default_data: Array = []) -> Array:
        if _manifest.is_empty() and not default_data.is_empty():
                _manifest = _normalize_default(default_data)
        return _manifest

func refresh_from_firestore(default_data: Array = []) -> Array:
        if _loading:
                await get_tree().process_frame
                return _manifest
        _loading = true
        var refreshed: Array = []
        if typeof(Firebase) != TYPE_NIL and Firebase.has_method("get_tree"):
                var collection: FirestoreCollection = Firebase.Firestore.collection(FIRESTORE_COLLECTION)
                var doc: FirestoreDocument = await collection.get_doc(MANIFEST_DOC_ID)
                if doc:
                        var remote_data = doc.get_value(MANIFEST_FIELD, [])
                        if remote_data is Array:
                                for entry in remote_data:
                                        if entry is Dictionary:
                                                refreshed.append(_normalize_entry(entry))
        if refreshed.is_empty():
                if _manifest.is_empty():
                        load_manifest_from_cache(default_data)
                refreshed = _manifest
        else:
                _manifest = refreshed
                save_manifest_to_cache()
        _loading = false
        return refreshed

func _normalize_default(default_data: Array) -> Array:
        var normalized: Array = []
        for entry in default_data:
                if entry is Dictionary:
                        normalized.append(_normalize_entry(entry))
        return normalized
