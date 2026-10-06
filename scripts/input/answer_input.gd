class_name AnswerInput
extends Node
## How the player answers. Combat only listens for `answer_submitted`, so input
## strategies (type the answer, shoot the answer, or later a hybrid) are swappable.

## target_id -1 means "auto-target whichever enemy this answer solves".
signal answer_submitted(answer: String, target_id: int)

var encounter: Encounter


func attach(p_encounter: Encounter) -> void:
	encounter = p_encounter


## Short help text for the HUD.
func hint() -> String:
	return ""
