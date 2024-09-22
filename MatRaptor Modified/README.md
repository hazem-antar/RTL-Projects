# Verilog Implementation of MatRaptor - Sparse Matrix Multiplication Accelerator

## Overview

This repository contains the Verilog implementation of **MatRaptor**, a hardware accelerator designed for efficient Sparse-Sparse Matrix Multiplication (SpSpMM) using a **Row-Wise Product** approach. The project focuses on enhancing computational efficiency, memory bandwidth usage, and scalability, targeting high-performance computing platforms such as FPGA and ASIC.

## Features
- **Row-Wise Product**: Efficiently handles sparse matrix multiplication by processing only non-zero elements in a row-major format, improving data locality and parallelism.
- **C2SR Format**: Implements the Channel Cyclic Sparse Row (C2SR) format for better memory access and efficient parallel processing.
- **Hardware Design**:
  - Uses systolic array-based architecture with parallel processing elements (PEs) for high-speed computation.
  - Double buffering and pipelined processing for simultaneous multiplication and merging operations.
  
## Hardware Components
- **MatRaptor Architecture**: 
  - Sparse A and B matrix loaders (SpAL, SpBL) feed data to the Processing Elements (PEs).
  - Parallel PEs perform sparse matrix multiplications and merging in a pipelined manner, reducing computational overhead.
- **Integration with MicroBlaze**: MatRaptor is integrated with the MicroBlaze soft processor for seamless control and data management using BRAM blocks.

## Performance Results
- **Scalable Architecture**: Demonstrates improved memory bandwidth utilization and eliminates channel conflicts.
- **Successful FPGA Integration**: The system was tested on the **GENESYS 2** FPGA board, showing successful results in sparse matrix multiplication through BRAM integration.
