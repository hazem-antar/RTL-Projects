`ifndef DEFINE_STATE

// This defines the states
typedef enum logic [2:0] {
	S_IDLE,
	S_ENABLE_UART_RX,
	S_WAIT_UART_RX,
	S_CSCD_AWAITE,
	S_DCT_AWAITE
} top_state_type;

typedef enum logic [1:0] {
	S_RXC_IDLE,
	S_RXC_SYNC,
	S_RXC_ASSEMBLE_DATA,
	S_RXC_STOP_BIT
} RX_Controller_state_type;

typedef enum logic [2:0] {
	S_US_IDLE,
	S_US_STRIP_FILE_HEADER_1,
	S_US_STRIP_FILE_HEADER_2,
	S_US_START_FIRST_BYTE_RECEIVE,
	S_US_WRITE_FIRST_BYTE,
	S_US_START_SECOND_BYTE_RECEIVE,
	S_US_WRITE_SECOND_BYTE
} UART_SRAM_state_type;

typedef enum logic [3:0] {
	S_CSCD_IDLE,
	S_CSCD_NEW_PIXEL_ROW,
	S_CSCD_1,
	S_CSCD_2,
	S_CSCD_COM_0,
	S_CSCD_COM_1,
	S_CSCD_COM_2,
	S_CSCD_COM_3,
	S_CSCD_COM_4,
	S_CSCD_COM_5
} CSCD_state_type;

typedef enum logic [3:0] {
	S_DCT_FS_IDLE,
	S_DCT_FS_0,
	S_DCT_FS_1,
	S_DCT_FS_2,
	S_DCT_FS_3,
	S_DCT_FS_COM_0,
	S_DCT_FS_COM_1,
	S_DCT_FS_HOLD
} DCT_FS_state_type;

typedef enum logic [3:0] {
	S_DCT_CT_IDLE,
	S_DCT_CT_0,
	S_DCT_CT_1,
	S_DCT_CT_COM_0,
	S_DCT_CT_COM_1,
	S_DCT_CT_2,
	S_DCT_CT_HOLD
} DCT_CT_state_type;

typedef enum logic [3:0] {
	S_DCT_Sd_IDLE,
	S_DCT_Sd_0,
	S_DCT_Sd_1,
	S_DCT_Sd_COM_0,
	S_DCT_Sd_2,
	S_DCT_Sd_HOLD
} DCT_Sd_state_type;

typedef enum logic [3:0] {
	S_DCT_QLE_IDLE,
	S_DCT_QLE_0,
	S_DCT_QLE_COM_0,
	S_DCT_QLE_RELEASE_ZEROS,
	S_DCT_QLE_1,
	S_DCT_QLE_WRITE_OFFSET_UV,
	S_DCT_QLE_WRITE_Rest_Of_Header,
	S_DCT_QLE_2,
	S_DCT_QLE_HOLD
} DCT_QLE_state_type;

typedef enum logic {
	S_DCT_Timer_IDLE,
	S_DCT_Timer_ON
} DCT_Timer_state_type;

`define DEFINE_STATE 1
`endif
