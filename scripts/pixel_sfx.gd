extends Node
## 8-bit 搞笑音效包统一播放口(ffmpeg 合成,零版权风险)。
## 用法:父节点 add_child(pixel_sfx) 后调 pixel_sfx.play("arcade_blip")。
## 文件缺失时静默跳过——并行会话有过误删文件史,音效缺失绝不能炸游戏。

## 角色专属彩蛋音:下标对应 archive_entrance_npc.NPCS 顺序。
const NPC_CUE := {"niu_lai": "moo_8bit", "meituan_kangaroo": "boing"}

var _cache: Dictionary = {}

func play(cue: String, volume_db := -10.0) -> void:
	var cached: Variant = _cache.get(cue)
	if cached is AudioStream:
		_play_stream(cached, volume_db)
		return
	if cached != null:
		return  # 缺失标记,静默跳过
	var stream := load("res://assets/audio/%s.wav" % cue) as AudioStream
	if stream == null:
		push_warning("音效缺失(已跳过): %s" % cue)
		_cache[cue] = false
		return
	_cache[cue] = stream
	_play_stream(stream, volume_db)

func _play_stream(stream: AudioStream, volume_db: float) -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = stream
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	p.play()

## NPC 开聊彩蛋:牛来哞 / 袋鼠 boing,其余角色走通用开聊音。
func play_npc_greeting(npc_id: String) -> void:
	play(String(NPC_CUE.get(npc_id, "npc_open")), -8.0)
