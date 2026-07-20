RTL_DIR := rtl
SIM_DIR := sim
AUDIO_DIR := audio
TB := tb_synth_top
TOP_MODULES := $(RTL_DIR)/synth_top.v $(RTL_DIR)/uart_midi.v $(RTL_DIR)/note_lut.v $(RTL_DIR)/nco.v $(RTL_DIR)/adsr.v $(RTL_DIR)/mixer.v

.PHONY: all sim wave wav clean phase2 phase6

all: wav

phase2:
	iverilog -g2012 -o $(SIM_DIR)/tb_nco.vvp $(SIM_DIR)/tb_nco.v $(RTL_DIR)/nco.v
	cd $(SIM_DIR) && ln -sf ../$(RTL_DIR)/sine_lut.mem . && vvp tb_nco.vvp
	cd $(SIM_DIR) && python3 render_wav.py samples_a2.txt samples_a2.wav
	cd $(SIM_DIR) && python3 render_wav.py samples_a4.txt samples_a4.wav
	cd $(SIM_DIR) && python3 render_wav.py samples_a6.txt samples_a6.wav
	cd $(SIM_DIR) && python3 check_pitch.py

sim: $(SIM_DIR)/$(TB).vvp

$(SIM_DIR)/$(TB).vvp: $(SIM_DIR)/$(TB).v $(TOP_MODULES)
	iverilog -g2012 -o $@ $(SIM_DIR)/$(TB).v $(TOP_MODULES)

wave: sim
	cd $(SIM_DIR) && vvp $(TB).vvp
	@echo "Run: gtkwave $(SIM_DIR)/tb_synth_top.vcd"

wav: sim
	cd $(SIM_DIR) && ln -sf ../$(RTL_DIR)/sine_lut.mem . && vvp $(TB).vvp
	cd $(SIM_DIR) && python3 render_wav.py samples.txt samples.wav
	cd $(SIM_DIR) && python3 check_synth_top.py
	cd $(SIM_DIR) && python3 render_wav.py samples.txt ../$(AUDIO_DIR)/synth_top_demo.wav

phase6: wav

phase3:
	iverilog -g2012 -o $(SIM_DIR)/tb_adsr.vvp $(SIM_DIR)/tb_adsr.v $(RTL_DIR)/adsr.v $(RTL_DIR)/waveform_lut.v
	cd $(SIM_DIR) && ln -sf ../$(RTL_DIR)/sine_lut.mem . && vvp tb_adsr.vvp
	cd $(SIM_DIR) && python3 check_adsr.py

phase4:
	iverilog -g2012 -o $(SIM_DIR)/tb_poly.vvp $(SIM_DIR)/tb_poly.v $(RTL_DIR)/nco.v $(RTL_DIR)/adsr.v $(RTL_DIR)/mixer.v
	cd $(SIM_DIR) && ln -sf ../$(RTL_DIR)/sine_lut.mem . && vvp tb_poly.vvp
	cd $(SIM_DIR) && python3 render_wav.py samples_poly.txt samples_poly.wav
	cd $(SIM_DIR) && python3 check_poly.py

phase5:
	iverilog -g2012 -o $(SIM_DIR)/tb_melody.vvp $(SIM_DIR)/tb_melody.v $(RTL_DIR)/uart_midi.v $(RTL_DIR)/note_lut.v $(RTL_DIR)/nco.v $(RTL_DIR)/adsr.v
	cd $(SIM_DIR) && ln -sf ../$(RTL_DIR)/sine_lut.mem . && vvp tb_melody.vvp
	cd $(SIM_DIR) && python3 render_wav.py samples_melody.txt samples_melody.wav
	cd $(SIM_DIR) && python3 check_melody.py

clean:
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd $(SIM_DIR)/samples*.txt $(SIM_DIR)/envelope*.txt $(SIM_DIR)/waveform_samples.txt $(SIM_DIR)/samples*.wav
