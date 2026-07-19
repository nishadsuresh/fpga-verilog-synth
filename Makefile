RTL_DIR := rtl
SIM_DIR := sim
AUDIO_DIR := audio
TB := tb_synth_top
TOP_MODULES := $(RTL_DIR)/synth_top.v

.PHONY: all sim wave wav clean

all: wav

sim: $(SIM_DIR)/$(TB).vvp

$(SIM_DIR)/$(TB).vvp: $(SIM_DIR)/$(TB).v $(TOP_MODULES)
	iverilog -g2012 -o $@ $(SIM_DIR)/$(TB).v $(TOP_MODULES)

wave: sim
	cd $(SIM_DIR) && vvp $(TB).vvp
	@echo "Run: gtkwave $(SIM_DIR)/tb_synth_top.vcd"

wav: sim
	cd $(SIM_DIR) && vvp $(TB).vvp
	cd $(SIM_DIR) && python3 render_wav.py samples.txt ../$(AUDIO_DIR)/phase1_silence.wav

clean:
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.vcd $(SIM_DIR)/samples.txt $(AUDIO_DIR)/*.wav
