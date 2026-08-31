extends GdUnitTestSuite


func test_same_seed_and_name_replay_identically() -> void:
	var a: RngStream = RngStream.new(1234, &"reels")
	var b: RngStream = RngStream.new(1234, &"reels")
	for i: int in 50:
		assert_int(a.randi_range(0, 999)).is_equal(b.randi_range(0, 999))


func test_named_streams_are_independent() -> void:
	# The point of named streams: burning shop draws must not shift the reels.
	var reels_a: RngStream = RngStream.new(99, &"reels")
	var shop: RngStream = RngStream.new(99, &"shop")
	var first: int = reels_a.randi_range(0, 1000000)
	for i: int in 25:
		shop.randi_range(0, 1000000)
	var reels_b: RngStream = RngStream.new(99, &"reels")
	assert_int(reels_b.randi_range(0, 1000000)).is_equal(first)


func test_different_names_derive_different_seeds() -> void:
	assert_int(RngStream.derive_seed(7, &"reels")).is_not_equal(RngStream.derive_seed(7, &"shop"))


func test_derived_seeds_are_non_negative() -> void:
	for i: int in 200:
		assert_int(RngStream.derive_seed(i * 7919, &"reels")).is_greater_equal(0)


func test_weighted_index_respects_zero_weights() -> void:
	var rng: RngStream = RngStream.new(5, &"t")
	for i: int in 500:
		assert_int(rng.weighted_index(PackedInt32Array([0, 3, 0]))).is_equal(1)


func test_weighted_index_reports_an_empty_reel() -> void:
	assert_int(RngStream.new(5, &"t").weighted_index(PackedInt32Array([0, 0]))).is_equal(-1)


func test_draw_count_is_tracked() -> void:
	var rng: RngStream = RngStream.new(5, &"t")
	rng.randi_range(0, 1)
	rng.randf()
	assert_int(rng.draws).is_equal(2)
