# scripts/objects/ball_item.gd
# 필드에 배치되는 공 수집 아이템. 공이 접촉하면 수집된다.
extends Area2D

signal collected


# 공이 접촉하면 수집 시그널을 발생시키고 사라진다.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("ball"):
		collected.emit()
		queue_free()
