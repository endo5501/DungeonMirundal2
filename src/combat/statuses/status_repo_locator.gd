class_name StatusRepoLocator
extends RefCounted

# Single resolution point for StatusRepository: returns the test-provided
# override when set, otherwise falls back to DataLoader (which caches the
# repo statically, making the fallback essentially free after the first call).
static func resolve(override: StatusRepository) -> StatusRepository:
	if override != null:
		return override
	return DataLoader.new().load_status_repository()
