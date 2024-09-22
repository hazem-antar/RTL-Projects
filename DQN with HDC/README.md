# Project Title: HDC-Based Q-Learning and Hardware Acceleration

## Overview
This repository contains the implementation of a novel approach to Q-Learning using Hyperdimensional Computing (HDC) and its hardware acceleration. The project explores both software and hardware solutions, providing an efficient and scalable alternative to Deep Q-Learning (DQL) through the use of HDC. Additionally, it includes FPGA-based hardware implementation for accelerating the computations.

## Features
Deep Q-Learning (DQL): Implements DQL with experience replay to improve training stability.
HDC-Based Q-Learning: Introduces an HDC-based approach with two techniques:
Distance-based projection: Using hypervectors to represent Q-values and calculate distances for action selection.
Up/Down projection: Efficient projection of states and actions into the HDC space, with optimizations for hardware.
FPGA Acceleration: Provides hardware designs using LFSR-based random number generation and pipelined architecture for fast computations.

## Software Components
Deep Q-Learning: A baseline implementation solving environments using DQL.
HDC Q-Learning: Hyperdimensional Q-learning algorithm that binds states and actions into hypervectors and computes distances in the HDC domain.

## Hardware Components
FPGA-Based Acceleration: Implements the hardware architecture for generating state and action hypervectors using LFSRs.
Pipelined Distance Calculation: Optimized 3-stage pipelined system for distance calculation between hypervectors, with results showcasing significant frequency improvements.

## Performance Results
### Software Results:
DQL solves the environment in ~400 episodes.
HDC-based Q-learning solves it in ~900 episodes with hypervectors of dimension 10,000.
### Hardware Results:
Single-cycle system achieves a maximum operating frequency of 24.97 MHz.
A 3-stage pipelined system boosts performance up to 76.08 MHz.
