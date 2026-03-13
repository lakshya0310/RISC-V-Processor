# RISC-V Processor Architecture Design (IPA Project - Spring 2026)

## Overview

This project is developed as part of the **IPA (Introduction to Processor Architecture)** course for Spring 2025. The objective is to design and simulate a processor architecture based on the **RISC-V ISA** using **Verilog**. The project explores both **sequential** and **pipelined** processor designs, with emphasis on modularity, correctness, and performance.

---

## Project Goals

-  Implement a **sequential** processor architecture.
-  Develop a **5-stage pipelined** processor architecture with hazard handling.
-  Execute and verify the following **RISC-V instructions**:
  - `add`, `sub`, `and`, `or`
  - `ld`, `sd`
  - `beq`
-  Used **Verilog HDL** for all design modules and testbenches.
-  Written a **test assembly program** (sorting algorithm) and used encoded instructions to test the processor.

---

## Design Approach

The processor was implemented using a **modular design philosophy**, where each stage of the processor is built and tested independently before integration. The two main architectural variants developed are:

### Sequential Processor
- Implements instruction execution in a single-cycle format.
- Serves as a base reference for functional correctness.

### 5-Stage Pipelined Processor
- **Stages**:
  - **IF** – Instruction Fetch
  - **ID** – Instruction Decode
  - **EX** – Execute
  - **MEM** – Memory Access
  - **WB** – Write Back
- Includes **data forwarding** and **hazard detection** mechanisms.
- Optimized for performance and scalability.

---

## Implementation Details

- **Language Used**: Verilog HDL
- **Modules**:
  - Instruction Memory
  - Control Unit
  - Register File
  - ALU
  - Data Memory
  - Hazard Detection Unit
  - Forwarding Unit
- **Testing**:
  - Each module tested independently using custom Verilog testbenches.
  - Integrated system tested with encoded RISC-V instruction sequences.
- **Toolchain**:
  - Simulation: Icarus Verilog
  - Scripting: Python / Bash for automation

---
