class_name Weapon
extends RefCounted
## A weapon decides which problems the player faces and how hard each correct
## answer hits. Milestone 5 adds the rest of the arsenal.

var name: String
var skills: Array[ProblemGenerator.Skill]
var damage: int


func _init(p_name: String, p_skills: Array[ProblemGenerator.Skill], p_damage: int) -> void:
	name = p_name
	skills = p_skills
	damage = p_damage


static func adder_blaster() -> Weapon:
	return Weapon.new("Adder Blaster", [ProblemGenerator.Skill.ADD, ProblemGenerator.Skill.SUB], 1)
