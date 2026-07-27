extends SceneTree
## Un ASSAGGIO del lessico Chibiese, da ascoltare con le orecchie: rende
## in un unico WAV tre voci diverse che dicono le parole nuove (i sei
## suoni nuovi compresi: r arrotata, d, g, z ronzante, sh, ch).
##
## Uso (dal Godot portabile):
##   Godot --headless --path . --script res://tests/sampler_chibiese.gd
## Scrive dove dice CHIBI_SAMPLER_OUT (default user://chibiese_sampler.wav).
## Non fa parte della suite (il runner carica solo tests/cases/test_*.gd).

const CHB := preload("res://audio/Chibiese.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")


func _init() -> void:
	var out_path := OS.get_environment("CHIBI_SAMPLER_OUT")
	if out_path == "":
		out_path = "user://chibiese_sampler.wav"

	# tre voci, tre giri di parole: la natura coi suoni nuovi, i
	# sentimenti del Filo, il giocare e il villaggio
	var giro := [
		[7, "felice", ["uccellino", "ape", "gufo", "albero", "foglia", "arcobaleno"]],
		[13, "triste", ["cuore", "nostalgia", "ricordo", "abbraccio", "addio"]],
		[29, "felice", ["trovato", "giocare", "campana", "te", "piano", "villaggio"]],
	]
	var buf := PackedByteArray()
	var gap := PackedByteArray()
	gap.resize(int(0.32 * CHB.RATE) * 2)
	for terna: Array in giro:
		var voce: Dictionary = CHB.voice(DNA.generate(int(terna[0])))
		for parola in terna[2]:
			var wav: AudioStreamWAV = CHB.say(voce, [str(parola)], str(terna[1]))
			buf.append_array(wav.data)
			buf.append_array(gap)

	var wav_out := AudioStreamWAV.new()
	wav_out.format = AudioStreamWAV.FORMAT_16_BITS
	wav_out.mix_rate = CHB.RATE
	wav_out.data = buf
	wav_out.save_to_wav(out_path)
	print("SAMPLER: scritto %s (%.1f s)" % [out_path, buf.size() / 2.0 / CHB.RATE])
	quit(0)
