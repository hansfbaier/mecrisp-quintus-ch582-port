
ARMGNU?=riscv64-linux-gnu

AOPS = --warn --fatal-warnings

all : mecrisp-quintus-ch582.bin

mecrisp-quintus-ch582.o : mecrisp-quintus-ch582.s terminal.s interrupts.s flash.s
	$(ARMGNU)-as mecrisp-quintus-ch582.s -o mecrisp-quintus-ch582.o -march=rv32im

mecrisp-quintus-ch582.bin : memmap mecrisp-quintus-ch582.o
	$(ARMGNU)-ld -o mecrisp-quintus-ch582.elf -T memmap mecrisp-quintus-ch582.o -m elf32lriscv
	$(ARMGNU)-objdump -Mnumeric -D mecrisp-quintus-ch582.elf > mecrisp-quintus-ch582.list
	$(ARMGNU)-objcopy mecrisp-quintus-ch582.elf mecrisp-quintus-ch582.bin -O binary
	$(ARMGNU)-objcopy mecrisp-quintus-ch582.elf mecrisp-quintus-ch582.hex -O ihex

clean:
	rm -f *.bin
	rm -f *.hex
	rm -f *.o
	rm -f *.elf
	rm -f *.list
