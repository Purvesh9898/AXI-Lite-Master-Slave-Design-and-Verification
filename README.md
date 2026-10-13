# AXI Master–Slave RTL Design and SystemVerilog Verification

A small educational RTL project that models a serialized, AXI-like master–slave memory interface. The design is written in Verilog HDL, while a class-based SystemVerilog testbench generates transactions and checks read data using an independent reference-memory scoreboard.

> **Protocol scope:** This is a simplified AXI-like teaching model, not a complete AXI4 or AXI4-Lite implementation. Do not describe it as protocol-compliant. It does not implement all AXI channel independence, burst transfers, IDs, byte strobes, or the full protocol requirements.

## Features

- Verilog RTL for master, slave, and top-level DUT wrapper
- 8-bit address and 8-bit data paths
- 256 × 8-bit slave memory model
- FSM-based serialized read and write operations
- SystemVerilog transaction class and randomized stimulus
- Generator, driver, monitor, environment, and scoreboard
- Directed write/read test followed by 50 randomized transactions
- Read-data checking against an independent reference memory

## Repository layout

```text
axi-master-slave-design-verification/
├── rtl/
│   ├── axi_master.v
│   ├── axi_slave.v
│   └── dut.v
├── tb/
│   ├── axi_interface.sv
│   └── tb_axi.sv
├── docs/
│   └── verification-results.md
├── .gitignore
├── LICENSE
└── README.md
```

## Tools

- Xilinx Vivado Simulator (xsim), or
- QuestaSim / ModelSim with SystemVerilog class and mailbox support

## Run in Vivado

1. Create or open a Vivado project.
2. Add `rtl/axi_master.v`, `rtl/axi_slave.v`, and `rtl/dut.v` as **Design Sources**.
3. Add `tb/axi_interface.sv` and `tb/tb_axi.sv` as **Simulation Sources**.
4. Set `tb_axi` as the simulation top.
5. Select **Run Simulation → Run Behavioral Simulation**.
6. Inspect the Tcl Console for the verification summary. Add clock, reset, start signals, read data, and VALID/READY signals to the waveform for debugging.

## Run in QuestaSim / ModelSim

From the repository root, run:

```tcl
vlib work
vlog rtl/axi_master.v rtl/axi_slave.v rtl/dut.v
vlog -sv tb/axi_interface.sv tb/tb_axi.sv
vsim -voptargs=+acc work.tb_axi
add wave -r /*
run -all
```

Simulator versions vary in their support for SystemVerilog testbench features. If compilation fails, check the first compiler error and confirm SystemVerilog is enabled for the testbench files.

## Test sequence

1. Write `8'hA5` to address `8'h20`.
2. Read address `8'h20` and compare the result against the scoreboard.
3. Generate 50 randomized read/write transactions.
4. Print read/write completion counts and read-data mismatch count.

## Reported simulation result

In the reported Vivado simulation run:

| Metric | Result |
|---|---:|
| Completed reads | 33 |
| Completed writes | 19 |
| Total completed transactions | 52 |
| Read-data mismatches | 0 |
| Testbench status | `TEST PASSED` |

These values describe one simulation run, not exhaustive verification or protocol compliance. Re-run the simulation after any code changes and update the table if the results change.

## Known limitations / future work

- Implement and verify the complete AXI4-Lite requirements before claiming AXI4-Lite compliance.
- Add directed read-after-write overwrite tests and boundary-address tests (`8'h00`, `8'hFF`).
- Add assertions for handshake stability, reset behavior, and transaction completion.
- Add functional coverage for operation type, address regions, and data patterns.
- Add timeout checks and test reset during active transactions.
- Consider separating each class into its own `.sv` file as the environment grows.

## License

Released under the MIT License. See [`LICENSE`](LICENSE).
