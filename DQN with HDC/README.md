# HDC-Based Q-Learning and Hardware Acceleration

## Overview

This repository contains the implementation of a novel approach to Q-Learning using Hyperdimensional Computing (HDC) and its hardware acceleration. The project explores both software and hardware solutions, providing an efficient and scalable alternative to Deep Q-Learning (DQL) through the use of HDC. Additionally, it includes FPGA-based hardware implementation for accelerating the computations.

## Features
- **Deep Q-Learning (DQL)**: Implements DQL with experience replay to improve training stability.
- **HDC-Based Q-Learning**: Hyperdimensional Q-learning algorithm that binds states and actions into hypervectors and computes distances in the HDC domain.
  - **Distance-based projection**: Calculates distances between Q-value hypervectors and reference vectors for action selection.
  - **Up/Down projection**: Efficient projection of states and actions into the HDC space, optimized for hardware.
- **FPGA Acceleration**: Provides hardware designs using LFSR-based random number generation and pipelined architecture for fast computations.

## Software Components
- **Deep Q-Learning**: A baseline implementation that solves environments using DQL.
- **HDC Q-Learning**: An implementation of Hyperdimensional Q-learning where state-action pairs are projected into hyperdimensional space, allowing for more scalable computations.

## Hardware Components
- **FPGA-Based Acceleration**: Implements hardware architecture for generating state and action hypervectors using LFSRs.
- **Pipelined Distance Calculation**: An optimized 3-stage pipelined system that significantly improves computational performance.

## Performance Results
- **Software Results**: 
  - DQL solves the environment in ~400 episodes.
  - HDC-based Q-learning solves the environment in ~900 episodes with hypervectors of dimension 10,000.
  
- **Hardware Results**:
  - Single-cycle system achieves a maximum operating frequency of 24.97 MHz.
  - A 3-stage pipelined system boosts performance to 76.08 MHz.

## Important Notice

This project is part of ongoing academic research. The use of any code, data, or materials from this repository for any other research or project is strictly prohibited without prior written permission from the author. Unauthorized use or reproduction of this work may result in legal action. Please contact the author if you wish to collaborate or use any part of this project for academic or research purposes.

## Author
- **Hazem Taha** - [GitHub Profile](https://github.com/hazem-antar)
