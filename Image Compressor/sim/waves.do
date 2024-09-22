# activate waveform simulation

view wave

# format signal names in waveform

configure wave -signalnamewidth 1
configure wave -timeline 0
configure wave -timelineunits us

# add signals to waveform

add wave -divider -height 20 {}
add wave -bin UUT/CLOCK_50_I
add wave -bin UUT/resetn
add wave -hex {UUT/PB_pushed[0]}
add wave UUT/top_state
add wave -hex UUT/SRAM_address
add wave -hex UUT/SRAM_read_data
add wave -hex UUT/SRAM_write_data
add wave -hex UUT/SRAM_we_n
add wave -uns UUT/MUL1_OP_A
add wave -uns UUT/MUL1_OP_B
add wave -uns UUT/MUL2_OP_A
add wave -uns UUT/MUL2_OP_B
add wave -uns UUT/MUL3_OP_A
add wave -uns UUT/MUL3_OP_B
add wave -uns UUT/MUL4_OP_A
add wave -uns UUT/MUL4_OP_B
add wave -uns UUT/MUL1
add wave -uns UUT/MUL2
add wave -uns UUT/MUL3
add wave -uns UUT/MUL4

add wave -divider -height 10 {}
add wave UUT/CSCD_UNIT/CSCD_state
add wave -uns UUT/CSCD_UNIT/SRAM_address
add wave -uns UUT/CSCD_UNIT/SRAM_read_data
add wave -uns UUT/CSCD_UNIT/SRAM_write_data
add wave -uns UUT/CSCD_UNIT/SRAM_we_n
add wave -uns UUT/CSCD_UNIT/pixel_X_pos
add wave -uns UUT/CSCD_UNIT/pixel_Y_pos
add wave -dec UUT/CSCD_UNIT/Accumulator
add wave -uns UUT/CSCD_UNIT/Y_val
add wave -uns UUT/CSCD_UNIT/U_val
add wave -uns UUT/CSCD_UNIT/V_val
add wave -uns UUT/CSCD_UNIT/U
add wave -uns UUT/CSCD_UNIT/V
add wave -bin UUT/CSCD_UNIT/Y_Write_EN
add wave -uns UUT/CSCD_UNIT/U_E_Buffer
add wave -uns UUT/CSCD_UNIT/V_E_Buffer
add wave -uns UUT/CSCD_UNIT/U_O_Buffer
add wave -uns UUT/CSCD_UNIT/V_O_Buffer
add wave -uns UUT/CSCD_UNIT/UVd_val
add wave -bin UUT/CSCD_UNIT/Ud_Vd_Pair_Ready
add wave -bin UUT/CSCD_UNIT/begin_Ud_Vd_Write
add wave -uns UUT/CSCD_UNIT/Y_Buffer
add wave -uns UUT/CSCD_UNIT/Ud_Buffer
add wave -uns UUT/CSCD_UNIT/Vd_Buffer
add wave -uns UUT/CSCD_UNIT/RGB_pointer
add wave -uns UUT/CSCD_UNIT/Y_pointer
add wave -bin UUT/CSCD_UNIT/finished

add wave -divider -height 20 {}
add wave UUT/DCT_UNIT/DCT_FS_state
add wave -uns UUT/DCT_UNIT/SRAM_address
add wave -uns UUT/DCT_UNIT/SRAM_read_data
add wave -uns UUT/DCT_UNIT/SRAM_write_data
add wave -uns UUT/DCT_UNIT/SRAM_we_n
add wave -uns UUT/DCT_UNIT/timer
add wave -uns UUT/DCT_UNIT/block_relative_col_counter
add wave -uns UUT/DCT_UNIT/block_relative_row_counter
add wave -uns UUT/DCT_UNIT/block_col_start_counter
add wave -uns UUT/DCT_UNIT/block_row_start_address
add wave -uns UUT/DCT_UNIT/SRAM_Relative_address
add wave -uns UUT/DCT_UNIT/SRAM_address_FS
add wave -uns UUT/DCT_UNIT/SRAM_Fetch_Segment
add wave -hex UUT/DCT_UNIT/Buffer_SRAM
add wave -hex UUT/DCT_UNIT/S_Embedded_RAM_Write_Data_A
add wave -uns UUT/DCT_UNIT/S_Embedded_RAM_we_A
add wave UUT/DCT_UNIT/DCT_CT_state
add wave -uns UUT/DCT_UNIT/S_Embedded_RAM_Address_A
add wave -uns UUT/DCT_UNIT/S_Embedded_RAM_Address_B
add wave -hex UUT/DCT_UNIT/S_Embedded_RAM_Read_Data_A
add wave -hex UUT/DCT_UNIT/S_Embedded_RAM_Read_Data_B
add wave -uns UUT/DCT_UNIT/T_i_counter
add wave -uns UUT/DCT_UNIT/T_j_counter
add wave -hex UUT/DCT_UNIT/MULTs_Buffer
add wave -uns UUT/DCT_UNIT/New_T
add wave -uns UUT/DCT_UNIT/T_Buffer
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM1_Address_A
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM1_Address_B
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM1_Read_Data_A
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM1_Read_Data_B
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM1_Write_Data_A
add wave -uns UUT/DCT_UNIT/T_Embedded_RAM1_we_A
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM2_Address_A
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM2_Address_B
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM2_Read_Data_A
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM2_Read_Data_B
add wave -hex UUT/DCT_UNIT/T_Embedded_RAM2_Write_Data_A
add wave -uns UUT/DCT_UNIT/T_Embedded_RAM2_we_A
add wave -hex UUT/DCT_UNIT/MUL1_OP_B
add wave -hex UUT/DCT_UNIT/MUL2_OP_B
add wave -hex UUT/DCT_UNIT/MUL3_OP_B
add wave -hex UUT/DCT_UNIT/MUL4_OP_B
add wave -hex UUT/DCT_UNIT/New_Element_Unrounded
add wave UUT/DCT_UNIT/DCT_Sd_state
add wave -uns UUT/DCT_UNIT/Sd_i_counter
add wave -uns UUT/DCT_UNIT/Sd_j_counter
add wave -uns UUT/DCT_UNIT/New_Sd
add wave -hex UUT/DCT_UNIT/Sd_Embedded_RAM1_Address_A
add wave -hex UUT/DCT_UNIT/Sd_Embedded_RAM1_Read_Data_A
add wave -hex UUT/DCT_UNIT/Sd_Embedded_RAM1_Write_Data_A
add wave -uns UUT/DCT_UNIT/Sd_Embedded_RAM1_we_A
add wave -hex UUT/DCT_UNIT/Sd_Embedded_RAM2_Address_A
add wave -hex UUT/DCT_UNIT/Sd_Embedded_RAM2_Read_Data_A
add wave -hex UUT/DCT_UNIT/Sd_Embedded_RAM2_Write_Data_A
add wave -uns UUT/DCT_UNIT/Sd_Embedded_RAM2_we_A
add wave UUT/DCT_UNIT/DCT_QLE_state
add wave -uns UUT/DCT_UNIT/Sd_Embedded_RAM_Address_A_QLE
add wave -uns UUT/DCT_UNIT/QLE_j_counter
add wave -uns UUT/DCT_UNIT/QLE_i_counter
add wave -uns UUT/DCT_UNIT/polarity
add wave -uns UUT/DCT_UNIT/diag_index
add wave -uns UUT/DCT_UNIT/Sd_Read
add wave -uns UUT/DCT_UNIT/Quantized
add wave -uns UUT/DCT_UNIT/Quantized_clipped
add wave -uns UUT/DCT_UNIT/Encoded_Buffer
add wave -uns UUT/DCT_UNIT/pointer
add wave -uns UUT/DCT_UNIT/group_zeros_counter
add wave -uns UUT/DCT_UNIT/zeros_counter
add wave -uns UUT/DCT_UNIT/release_zeros
add wave -uns UUT/DCT_UNIT/done_releasing_zeros
add wave -uns UUT/DCT_UNIT/Hold_COM_0
add wave -uns UUT/DCT_UNIT/buffer_Quantized_clipped
add wave -uns UUT/DCT_UNIT/SRAM_address_QLE
add wave -bin UUT/SRAM_we_n
add wave -uns UUT/DCT_UNIT/last_block_in_channel
add wave -uns UUT/DCT_UNIT/last_block_in_channel_buffer

add wave -uns UUT/DCT_UNIT/Two_Byte_Counter
add wave -uns UUT/DCT_UNIT/UV_Offset_index
add wave -uns UUT/DCT_UNIT/SRAM_write_data_UV_Offset
add wave -uns UUT/DCT_UNIT/Header_Offset_index
add wave -uns UUT/DCT_UNIT/SRAM_write_data_HEADER
add wave -uns UUT/DCT_UNIT/SRAM_address_QLE_Buffer