# Synchronous_FIFO
Implement a synchronous, single-clock FIFO (First-In First-Out) memory in Verilog. FIFOs are present in virtually every RTL block—from USB controllers to GPU command queues—and understanding their pointer arithmetic, flag generation, and corner-cases is must.

# Design Specification (Verilog RTL)
- Parameterize data width DATA_W (default 8) and depth DEPTH (default 16, must support any power-of-two depth).
- Use a circular buffer implemented with a register array (not SRAM macros). Read and write pointers must be one bit wider than needed to distinguish full from empty (the classic N+1 bit pointer trick).
- Implement standard flags: full, empty, and also programmable almost_full (asserted when occupancy >= AFULL_THRESH) and almost_empty (asserted when occupancy <= AEMPTY_THRESH), where both thresholds are runtime-configurable inputs.
- Push and pop must be single-cycle operations on the rising clock edge. Simultaneously asserting wr_en and rd_en when neither full nor empty must safely bypass data (show/write-first behavior, selectable via parameter).
- The design must handle back-pressure correctly: writes when full and reads when empty must be silently ignored without corrupting the pointer state.
• Include an occupancy output port giving the exact number of valid entries at all times.

# Testbench Requirements (SystemVerilog)
- Write a SystemVerilog testbench with a virtual interface and a class-based environment.
- Implement a FIFO scoreboard class that maintains a queue as a golden reference model; every popped value is checked against the front of the reference queue.
- Directed tests: fill FIFO to depth, read all, re-fill while reading simultaneously, verify almost_full/almost_empty toggle at correct threshold occupancies.
- Constrained-random test: randomize wr_en, rd_en, and wr_data each cycle for 10,000 cycles; the scoreboard must report zero mismatches.
- Write SVA (SystemVerilog Assertions) properties:
  1. full -> !wr_en or data not corrupted
  2. empty -> !rd_en
  3. occupancy never exceeds DEPTH
  4. almost_full asserts exactly when occupancy >= threshold.
- Measure functional coverage: covergroup tracking occupancy bins (empty, 1–25%, 26–50%,
51–75%, 76–99%, full), and simultaneous read-write scenarios.

# Expected Deliverables
- Synchronous_FIFO.v — synthesizable RTL.
- tb_Synchronous_FIFO.sv — class-based testbench with scoreboard and SVA.
- coverage_report.txt — summary showing >95% functional coverage.
- Waveform showing: push to full, simultaneous read/write, almost_full toggle.
