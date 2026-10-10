extends Control
var index: int
var target: int
var caption: Label
var progress: ProgressBar
var title: String
var unit: String
var reward: int
func setup(task_index: int, task_title: String, task_unit: String, task_target: int, xp_reward: int) -> void:
	index=task_index
	title=task_title
	unit=task_unit
	target=task_target
	reward=xp_reward
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.flat_card(self,Rect2(0,0,465,174)).mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiKit.label(title,self,Rect2(15,12,435,48),28,true)
	caption=UiKit.label("",self,Rect2(20,65,425,52),24)
	progress=UiKit.meter(self,Rect2(30,135,405,14),0)
	GameState.changed.connect(refresh)
	refresh()
func refresh() -> void:
	UiKit.set_text(caption,str(GameState.daily.counts[index])+" / "+str(target)+unit+" · 经验＋"+str(reward)+(" · 已领取" if GameState.daily.claimed[index] else ""))
	progress.value=minf(1.0,float(GameState.daily.counts[index])/target)
func _exit_tree() -> void:
	if GameState.changed.is_connected(refresh):GameState.changed.disconnect(refresh)
