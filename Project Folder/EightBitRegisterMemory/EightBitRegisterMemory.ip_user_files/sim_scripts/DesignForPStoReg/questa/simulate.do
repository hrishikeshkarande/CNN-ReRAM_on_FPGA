onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib DesignForPStoReg_opt

do {wave.do}

view wave
view structure
view signals

do {DesignForPStoReg.udo}

run -all

quit -force
