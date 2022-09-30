#
#    Mecrisp-Quintus - A native code Forth implementation for RISC-V
#    Copyright (C) 2018  Matthias Koch
#    Copyright (C) 2022  Hans Baier <hansfbaier@gmail.com> (CH582 port)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# -----------------------------------------------------------------------------
# Swiches for capabilities of this chip
# -----------------------------------------------------------------------------

.option norelax
.option rvc
.equ compressed_isa, 1

# -----------------------------------------------------------------------------
# Speicherkarte für Flash und RAM
# Memory map for Flash and RAM
# -----------------------------------------------------------------------------

# Konstanten für die Größe des Ram-Speichers

.equ RamAnfang,  0x20000000  # Start of RAM
.equ RamEnde,    0x20008000  # End   of RAM.   32 kb.
# the area above 64kb is reserved for DMA

# Konstanten für die Größe und Aufteilung des Flash-Speichers

.equ FlashAnfang, 0x00000000 # Start of Flash

# .equ FlashEnde,   0x00070000 # End   of Flash.  448 kb.
# Only 64 kB are cached in RAMX and able to run forth code efficiently
# If we try to run code outside that range it will run at 1/8 speed
# also writes to it will need a reset in order to appear visibles
.equ FlashEnde,   0x0070000 # End   of Flash.  448 kb.

# we need to start at a 64k page boundary because otherwise
# we could not erase and reprogram flash without erasing
# parts of the core
.equ FlashDictionaryAnfang, FlashAnfang + 0x5000
.equ FlashDictionaryEnde,   FlashEnde

.equ R8_SAFE_ACCESS_SIG,   0x40001040
.equ R16_CLK_SYS_CFG,      0x40001008
.equ R8_HFCK_PWR_CTRL,     0x4000100A
.equ R8_PLL_CONFIG,        0x4000104B
.equ R8_FLASH_CFG,         0x40001807


.equ RB_CLK_PLL_PON,       0x10
.equ CLK_SOURCE_PLL_60MHz, 0x48
.equ R8_CLK_PLL_DIV,       0x1F
.equ RB_CLK_SYS_MOD,       0xC0

.macro dbg, char
  li    x14, 0x40003408    # R8_UART1_THR
  li    x15, \char
  sb    x15, 0 (x14)
.endm

# -----------------------------------------------------------------------------
# Core start
# -----------------------------------------------------------------------------

.text

# -----------------------------------------------------------------------------
# Vector table
# -----------------------------------------------------------------------------

.global _start
.align  1
  j Reset
.align  1
_vector_base:
.option norvc;
  .word   0
  .word   0
  j irq_software                /* NMI Handler */
  j irq_memfault                /* Hard Fault Handler */
  .word   0xf5f9bda9
  .word   0
  .word   0
  .word   0
  .word   0
  .word   0
  .word   0
  .word   0
  j irq_systick            /* SysTick Handler */
  .word   0
  j irq_software           /* SW Handler */
  .word   0
  /* External Interrupts */
  j irq_collection          /* TMR0 */
  j irq_collection          /* GPIOA */
  j irq_collection          /* GPIOB */
  j irq_collection          /* SPI0 */
  j irq_collection          /* BLEB */
  j irq_collection          /* BLEL */
  j irq_usb                 /* USB */
  j irq_usb2                /* USB2 */
  j irq_timer1              /* TMR1 */
  j irq_timer2              /* TMR2 */
  j irq_collection          /* UART0 */
  j irq_collection          /* UART1 */
  j irq_collection          /* RTC */
  j irq_collection          /* ADC */
  j irq_collection          /* I2C */
  j irq_collection          /* PWMX */
  j irq_timer3              /* TMR3 */
  j irq_collection          /* UART2 */
  j irq_collection          /* UART3 */
  j irq_collection          /* WDOG_BAT */
.option rvc;

enable_safe_access:
  li a0, R8_SAFE_ACCESS_SIG
  # write safe access sequence
  li t0, 0x57
  sb t0, 0(a0)
  li t0, 0xa8
  sb t0, 0(a0)
  nop
  nop
  ret

disable_safe_access:
  li a0, R8_SAFE_ACCESS_SIG
  sb x0, 0(a0)
  ret

# -----------------------------------------------------------------------------
# Include the Forth core of Mecrisp-Quintus
# -----------------------------------------------------------------------------

  .include "../common/forth-core.s"

# -----------------------------------------------------------------------------
Reset: # Forth begins here
csrrsi zero, mstatus, 8    # MSTATUS: Set Machine Interrupt Enable Bit

# -----------------------------------------------------------------------------
  /* init system clock */
  call enable_safe_access

  # clock init
  li    a0, R8_PLL_CONFIG
  lb    t0, 0(a0)
  andi  t0, t0, 0xdf # ~( 1 << 5 )
  sb    t0, 0(a0)

  call disable_safe_access

  # power up PLL, if necessary
  li   a0, R8_HFCK_PWR_CTRL
  lb   t0, 0(a0)
  andi t0, t0, RB_CLK_PLL_PON
  bnez t0, 2f

  call enable_safe_access
  lb   t0, 0(a0)
  ori  t0, t0, RB_CLK_PLL_PON
  sb   t0, 0(a0)
  li   t0, 2000
1:
  nop
  nop
  addi t0, t0, -1
  bnez t0, 1b

2:
  call enable_safe_access
  li    a0, R16_CLK_SYS_CFG
  li    t0, CLK_SOURCE_PLL_60MHz
  andi  t0, t0, 0x1f
  sh    t0, 0(a0)
  nop
  nop
  nop
  nop
  call disable_safe_access

  call enable_safe_access
  li    a0, R8_FLASH_CFG
  li    t0, 0x52
  sb    t0, 0(a0)
  call disable_safe_access

  call enable_safe_access
  li    a0, R8_PLL_CONFIG
  lb    t0, 0(a0)
  ori   t0, t0, (1 << 7)
  sb    t0, 0(a0)
  call disable_safe_access

  # Initialisation of terminal hardware, without stacks
  call uart_init

  dbg 'U'

	/* interrupts */
	li      t0, 0x1f
	csrw    0xbc0, t0

  li      t0, 0x3
	csrw    0x804, t0

  li      t0, 0x88
  csrs    mstatus, t0
	la      t0, _vector_base
  ori     t0, t0, 3
	csrw    mtvec, t0
	la      t0, init
	csrw    mepc, t0
	mret

init:
  # Catch the pointers for Flash dictionary
  .include "../common/catchflashpointers.s"

  welcome " for RISC-V 32 IMAC by Matthias Koch, ported to CH582 by Hans Baier\r\n"

  # Ready to fly !
  .include "../common/boot.s"
