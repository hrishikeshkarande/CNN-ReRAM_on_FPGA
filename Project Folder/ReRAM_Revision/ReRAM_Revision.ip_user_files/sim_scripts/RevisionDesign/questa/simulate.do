onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib RevisionDesign_opt

do {wave.do}

view wave
view structure
view signals

do {RevisionDesign.udo}

run -all

quit -force
