LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY smac_rx_controller IS
	PORT ( clk: IN STD_LOGIC;
			 
			 reset: IN STD_LOGIC;
			 receive: IN STD_LOGIC;
			 store: IN STD_LOGIC;
			 ready: OUT STD_LOGIC;
			 error: OUT STD_LOGIC;
			 packet_type: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 packet_src: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_dst: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_dur: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_seq: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 packet_sleeptime: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_payload_len: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 
			 payload_address: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 payload_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 payload_wren: OUT STD_LOGIC;
			 
			 crc_reset: OUT STD_LOGIC;
			 crc_soc: OUT STD_LOGIC;
			 crc_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 crc_data_valid: OUT STD_LOGIC;
			 crc_eoc: OUT STD_LOGIC;
			 crc_crc: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 crc_crc_valid: IN STD_LOGIC;
			 
			 ram_address: OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			 ram_data_in: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 ram_wren: OUT STD_LOGIC;
			 ram_data_out: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 
			 phy_rx_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 phy_rx_enable: IN STD_LOGIC;
			 phy_rx_error: IN STD_LOGIC );
END smac_rx_controller;

ARCHITECTURE arch_smac_rx_controller OF smac_rx_controller IS
	CONSTANT SYNC: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000001";
	CONSTANT RTS: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000010";
	CONSTANT CTS: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000011";
	CONSTANT ACK: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000100";
	CONSTANT DATA: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000101";
	
	TYPE state_t IS (IDLE, RECEIVING_LEN, RECEIVING_TYPE, RECEIVING_SRC_H, RECEIVING_SRC_L, RECEIVING_DST_H, RECEIVING_DST_L, RECEIVING_DUR_H, RECEIVING_DUR_L, RECEIVING_SEQ, RECEIVING_SLEEPTIME_H, RECEIVING_SLEEPTIME_L, RECEIVING_PAYLOAD, RECEIVING_CRC_H, RECEIVING_CRC_L, WAITING_1, WAITING_2, STORING);
	TYPE rx_state_t IS
	RECORD
		state: state_t;
		
		len: STD_LOGIC_VECTOR(8 DOWNTO 0);
		crc: STD_LOGIC_VECTOR(15 DOWNTO 0);
		
		ready: STD_LOGIC;
		error: STD_LOGIC;
	   packet_type: STD_LOGIC_VECTOR(7 DOWNTO 0);
		packet_src: STD_LOGIC_VECTOR(15 DOWNTO 0);
		packet_dst: STD_LOGIC_VECTOR(15 DOWNTO 0);
		packet_dur: STD_LOGIC_VECTOR(15 DOWNTO 0);
		packet_seq: STD_LOGIC_VECTOR(7 DOWNTO 0);
		packet_sleeptime: STD_LOGIC_VECTOR(15 DOWNTO 0);
		packet_payload_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		payload_address: STD_LOGIC_VECTOR(7 DOWNTO 0);
		payload_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
		payload_wren: STD_LOGIC;
			 
		crc_reset: STD_LOGIC;
		crc_soc: STD_LOGIC;
		crc_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
		crc_data_valid: STD_LOGIC;
		crc_eoc: STD_LOGIC;
		
		ram_address: STD_LOGIC_VECTOR(8 DOWNTO 0);
		ram_data_in: STD_LOGIC_VECTOR(7 DOWNTO 0);
		ram_wren: STD_LOGIC;
	END RECORD;
	
	SIGNAL rx_state, rx_state_next: rx_state_t;
	
BEGIN
	fsm_clk: PROCESS (clk, reset) IS
	BEGIN
		IF reset = '1' THEN
			rx_state.state <= IDLE;
			
			rx_state.len <= (OTHERS => '0');
			rx_state.crc <= (OTHERS => '0');
			
			rx_state.ready <= '0';
			rx_state.error <= '0';
			rx_state.packet_type <= (OTHERS => '0');
			rx_state.packet_src <= (OTHERS => '0');
			rx_state.packet_dst <= (OTHERS => '0');
			rx_state.packet_dur <= (OTHERS => '0');
			rx_state.packet_seq <= (OTHERS => '0');
			rx_state.packet_sleeptime <= (OTHERS => '0');
			rx_state.packet_payload_len <= (OTHERS => '0');
			
			rx_state.payload_address <= (OTHERS => '0');
			rx_state.payload_data <= (OTHERS => '0');
			rx_state.payload_wren <= '0';
			
			rx_state.crc_reset <= '1';
			rx_state.crc_soc <= '0';
			rx_state.crc_data <= (OTHERS => '0');
			rx_state.crc_data_valid <= '0';
			rx_state.crc_eoc <= '0';
			
			rx_state.ram_address <= (OTHERS => '0');
			rx_state.ram_data_in <= (OTHERS => '0');
			rx_state.ram_wren <= '0';
		ELSE
			IF RISING_EDGE(clk) THEN
				rx_state <= rx_state_next;
			END IF;
		END IF;
	END PROCESS;
	
	fsm: PROCESS (rx_state, receive, store, crc_crc, crc_crc_valid, ram_data_out, phy_rx_data, phy_rx_enable, phy_rx_error) IS
	BEGIN
		rx_state_next <= rx_state;
		
		CASE rx_state.state IS
		
		WHEN IDLE =>
			IF receive = '1' THEN
				rx_state_next.state <= RECEIVING_LEN;
				
				rx_state_next.len <= (OTHERS => '0');
				rx_state_next.crc <= (OTHERS => '0');
				
				rx_state_next.ready <= '0';
				rx_state_next.error <= '0';
				rx_state_next.packet_type <= (OTHERS => '0');
				rx_state_next.packet_src <= (OTHERS => '0');
				rx_state_next.packet_dst <= (OTHERS => '0');
				rx_state_next.packet_dur <= (OTHERS => '0');
				rx_state_next.packet_seq <= (OTHERS => '0');
				rx_state_next.packet_sleeptime <= (OTHERS => '0');
				rx_state_next.packet_payload_len <= (OTHERS => '0');
				
				rx_state_next.payload_address <= (OTHERS => '0');
				rx_state_next.payload_data <= (OTHERS => '0');
				rx_state_next.payload_wren <= '0';
				
				rx_state_next.crc_reset <= '1';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
				
				rx_state_next.ram_address <= (OTHERS => '0');
				rx_state_next.ram_data_in <= (OTHERS => '0');
				rx_state_next.ram_wren <= '0';
			END IF;
			IF store = '1' THEN
				rx_state_next.state <= WAITING_1;
				
				rx_state_next.payload_address <= (OTHERS => '1');
				rx_state_next.payload_data <= (OTHERS => '0');
				rx_state_next.payload_wren <= '0';
				
				rx_state_next.ram_address <= STD_LOGIC_VECTOR(TO_UNSIGNED(9,9));
				rx_state_next.ram_data_in <= (OTHERS => '0');
				rx_state_next.ram_wren <= '0';
			END IF;
			IF receive = '0' AND store = '0' THEN
				-- auto reset initialization
				rx_state_next.crc <= (OTHERS => '0');
				
				rx_state_next.ready <= '1';
				--rx_state_next.error <= '0';
				
				rx_state_next.payload_address <= (OTHERS => '0');
				rx_state_next.payload_data <= (OTHERS => '0');
				rx_state_next.payload_wren <= '0';
				
				rx_state_next.crc_reset <= '1';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
				
				rx_state_next.ram_address <= (OTHERS => '0');
				rx_state_next.ram_data_in <= (OTHERS => '0');
				rx_state_next.ram_wren <= '0';
			END IF;
		
		WHEN RECEIVING_LEN =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_TYPE;
			
				rx_state_next.len <= '0' & phy_rx_data;
				
				rx_state_next.ram_address <= (OTHERS => '0');
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			END IF;
		
		WHEN RECEIVING_TYPE =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_SRC_H;
				
				rx_state_next.packet_type <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '1';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			END IF;
	
		WHEN RECEIVING_SRC_H =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_SRC_L;
				
				rx_state_next.packet_src(15 DOWNTO 8) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_SRC_L =>
			IF phy_rx_enable = '1' THEN
				IF rx_state.packet_type = SYNC THEN
					rx_state_next.state <= RECEIVING_SEQ;
				ELSIF rx_state.packet_type = RTS OR rx_state.packet_type = CTS OR rx_state.packet_type = ACK THEN
					rx_state_next.state <= RECEIVING_DST_H;
				ELSIF rx_state.packet_type = DATA THEN
					rx_state_next.state <= RECEIVING_DST_H;
				ELSE
					rx_state_next.state <= IDLE;
					
					rx_state_next.ready <= '1';
					rx_state_next.error <= '1';
				END IF;
				
				rx_state_next.packet_src(7 DOWNTO 0) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_DST_H =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_DST_L;
				
				rx_state_next.packet_dst(15 DOWNTO 8) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_DST_L =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_DUR_H;
				
				rx_state_next.packet_dst(7 DOWNTO 0) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_DUR_H =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_DUR_L;
				
				rx_state_next.packet_dur(15 DOWNTO 8) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_DUR_L =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_SEQ;
				
				rx_state_next.packet_dur(7 DOWNTO 0) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_SEQ =>
			IF phy_rx_enable = '1' THEN
				IF rx_state.packet_type = SYNC THEN
					rx_state_next.state <= RECEIVING_SLEEPTIME_H;
					
					rx_state_next.packet_seq <= phy_rx_data;
					
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
					
					rx_state_next.crc_reset <= '0';
					rx_state_next.crc_soc <= '0';
					rx_state_next.crc_data <= phy_rx_data;
					rx_state_next.crc_data_valid <= '1';
					rx_state_next.crc_eoc <= '0';
				ELSIF rx_state.packet_type = RTS OR rx_state.packet_type = CTS OR rx_state.packet_type = ACK THEN
					rx_state_next.state <= RECEIVING_CRC_H;
					
					rx_state_next.packet_seq <= phy_rx_data;
					
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
					
					rx_state_next.crc_reset <= '0';
					rx_state_next.crc_soc <= '0';
					rx_state_next.crc_data <= phy_rx_data;
					rx_state_next.crc_data_valid <= '1';
					rx_state_next.crc_eoc <= '1';
				ELSIF rx_state.packet_type = DATA THEN
					rx_state_next.state <= RECEIVING_PAYLOAD;
					
					rx_state_next.packet_seq <= phy_rx_data;
					rx_state_next.packet_payload_len <= rx_state.len(7 DOWNTO 0) - 10;
					
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
					
					rx_state_next.crc_reset <= '0';
					rx_state_next.crc_soc <= '0';
					rx_state_next.crc_data <= phy_rx_data;
					rx_state_next.crc_data_valid <= '1';
					rx_state_next.crc_eoc <= '0';
				ELSE
					rx_state_next.state <= IDLE;
					
					rx_state_next.ready <= '1';
					rx_state_next.error <= '1';
				END IF;
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_SLEEPTIME_H =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_SLEEPTIME_L;
				
				rx_state_next.packet_sleeptime(15 DOWNTO 8) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '0';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_SLEEPTIME_L =>
			IF phy_rx_enable = '1' THEN
				rx_state_next.state <= RECEIVING_CRC_H;
				
				rx_state_next.packet_sleeptime(7 DOWNTO 0) <= phy_rx_data;
				
				rx_state_next.ram_address <= rx_state.ram_address + 1;
				rx_state_next.ram_data_in <= phy_rx_data;
				rx_state_next.ram_wren <= '1';
				
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= phy_rx_data;
				rx_state_next.crc_data_valid <= '1';
				rx_state_next.crc_eoc <= '1';
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_PAYLOAD =>
			IF phy_rx_enable = '1' THEN
				IF rx_state.ram_address < rx_state.len - 3 THEN
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
					
					rx_state_next.crc_reset <= '0';
					rx_state_next.crc_soc <= '0';
					rx_state_next.crc_data <= phy_rx_data;
					rx_state_next.crc_data_valid <= '1';
					rx_state_next.crc_eoc <= '0';
				ELSE
					rx_state_next.state <= RECEIVING_CRC_H;
					
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
				
					rx_state_next.crc_reset <= '0';
					rx_state_next.crc_soc <= '0';
					rx_state_next.crc_data <= phy_rx_data;
					rx_state_next.crc_data_valid <= '1';
					rx_state_next.crc_eoc <= '1';
				END IF;
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_CRC_H =>
			IF crc_crc_valid = '1' THEN
				rx_state_next.crc <= crc_crc;
			END IF;
			
			IF phy_rx_enable = '1' THEN
				IF rx_state.crc(15 DOWNTO 8) = phy_rx_data THEN
					rx_state_next.state <= RECEIVING_CRC_L;
					
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
				ELSE
					rx_state_next.state <= IDLE;
				
					rx_state_next.ready <= '1';
					rx_state_next.error <= '1';
				END IF;
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN RECEIVING_CRC_L =>
			IF phy_rx_enable = '1' THEN
				IF rx_state.crc(7 DOWNTO 0) = phy_rx_data THEN
					rx_state_next.state <= IDLE;
					
					rx_state_next.ready <= '1';
					
					rx_state_next.ram_address <= rx_state.ram_address + 1;
					rx_state_next.ram_data_in <= phy_rx_data;
					rx_state_next.ram_wren <= '1';
				ELSE
					rx_state_next.state <= IDLE;
				
					rx_state_next.ready <= '1';
					rx_state_next.error <= '1';
				END IF;
			ELSIF phy_rx_error = '1' THEN
				rx_state_next.state <= IDLE;
				
				rx_state_next.ready <= '1';
				rx_state_next.error <= '1';
			ELSE
				rx_state_next.crc_reset <= '0';
				rx_state_next.crc_soc <= '0';
				rx_state_next.crc_data <= (OTHERS => '0');
				rx_state_next.crc_data_valid <= '0';
				rx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN WAITING_1 =>
			rx_state_next.state <= WAITING_2;
			
			rx_state_next.ram_address <= rx_state.ram_address + 1;
			
		WHEN WAITING_2 =>
			rx_state_next.state <= STORING;
			
			rx_state_next.ram_address <= rx_state.ram_address + 1;
			
		WHEN STORING =>
			IF rx_state.ram_address = rx_state.len THEN
				rx_state_next.state <= IDLE;
			END IF;
			rx_state_next.payload_address <= rx_state.payload_address + 1;
			rx_state_next.payload_data <= ram_data_out;
			rx_state_next.payload_wren <= '1';
				
			rx_state_next.ram_address <= rx_state.ram_address + 1;
			
		END CASE;
		
	END PROCESS;
	
	fsm_output: PROCESS (rx_state) IS
	BEGIN
		ready <= rx_state.ready;
		error <= rx_state.error;		
		packet_type <= rx_state.packet_type;
		packet_src <= rx_state.packet_src;
		packet_dst <= rx_state.packet_dst;
		packet_dur <= rx_state.packet_dur;
		packet_seq <= rx_state.packet_seq;
		packet_sleeptime <= rx_state.packet_sleeptime;
		packet_payload_len <= rx_state.packet_payload_len;
		
		payload_address <= rx_state.payload_address;
		payload_data <= rx_state.payload_data;
		payload_wren <= rx_state.payload_wren;
		
		crc_reset <= rx_state.crc_reset;
		crc_soc <= rx_state.crc_soc;
		crc_data <= rx_state.crc_data;
		crc_data_valid <= rx_state.crc_data_valid;
		crc_eoc <= rx_state.crc_eoc;
		
		ram_address <= rx_state.ram_address;
		ram_data_in <= rx_state.ram_data_in;
		ram_wren <= rx_state.ram_wren;
	END PROCESS;
END arch_smac_rx_controller;