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

add wave -hex UUT/LFSR_PROJECTION_GENERATOR/lfsr
add wave -hex UUT/LFSR_PROJECTION_GENERATOR/channels
add wave -uns UUT/LFSR_PROJECTION_GENERATOR/cycle_count

add wave -dec UUT/projection_stream
add wave -dec UUT/actions_stream

add wave -hex UUT/sum_permu_states
add wave -hex UUT/Stack_StateHV
add wave -hex UUT/Stack_StateHV_buffered

add wave -hex UUT/state_actionsHVs
add wave -hex UUT/Q_S_A_HVs
add wave -hex UUT/Q_S_A_HVs_buffered
add wave -hex UUT/ReferenceHV

add wave -hex UUT/diff_angles
add wave -hex UUT/partial_similarity
add wave -hex UUT/similarity_accumulator

add wave -uns UUT/Q_Embedded_RAM_Pointer
add wave -uns UUT/Q_Embedded_RAM_Address_A
add wave -uns UUT/Q_Embedded_RAM_Address_B

add wave -hex UUT/Q_Embedded_RAM_Read_Data_A
add wave -hex UUT/Q_Embedded_RAM_Read_Data_B

add wave -hex UUT/Q_Embedded_RAM_Data_A
add wave -hex UUT/Q_Embedded_RAM_Data_B

add wave -hex UUT/Q_Embedded_RAM_we_A
add wave -hex UUT/Q_Embedded_RAM_we_B



add wave -hex UUT/Q_HV