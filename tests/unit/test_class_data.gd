extends GutTest

func test_four_classes_registered() -> void:
	assert_eq(ClassDatabase.classes.size(), 4)
	for ct in [SharedEnums.ClassType.WARRIOR, SharedEnums.ClassType.ARCHER,
			   SharedEnums.ClassType.MAGE, SharedEnums.ClassType.RANGER]:
		assert_false(ClassDatabase.get_class_def(ct).is_empty(), "职业 %d 未注册" % ct)

func test_each_class_has_base_attributes() -> void:
	for ct in ClassDatabase.classes:
		var attrs = ClassDatabase.get_base_attributes(ct)
		assert_eq(attrs.size(), 6, "职业 %d 应有6属性" % ct)
		var total = 0
		for v in attrs.values():
			total += v
		assert_eq(total, 30, "职业 %d 初始属性总和应为30" % ct)

func test_each_class_has_two_branches() -> void:
	for ct in ClassDatabase.classes:
		var branches = ClassDatabase.get_branches(ct)
		assert_eq(branches.size(), 2, "职业 %d 应有2分支" % ct)

func test_each_class_has_weapons() -> void:
	for ct in ClassDatabase.classes:
		var weapons = ClassDatabase.get_weapons(ct)
		assert_gt(weapons.size(), 0, "职业 %d 应有武器" % ct)

func test_get_class_name() -> void:
	assert_eq(ClassDatabase.get_class_name(SharedEnums.ClassType.WARRIOR), "战士")
	assert_eq(ClassDatabase.get_class_name(999), "未知")

func test_warrior_branches() -> void:
	var branches = ClassDatabase.get_branches(SharedEnums.ClassType.WARRIOR)
	assert_true(branches.has(SharedEnums.ClassBranch.BERSERKER))
	assert_true(branches.has(SharedEnums.ClassBranch.GUARDIAN))
