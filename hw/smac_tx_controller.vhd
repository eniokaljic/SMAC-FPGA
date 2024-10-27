LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY smac_tx_controller IS
	PORT ( clk: IN STD_LOGIC;
			 
			 reset: IN STD_LOGIC;
			 load: IN STD_LOGIC;
			 send: IN STD_LOGIC;
			 ready: OUT STD_LOGIC;
			 packet_type: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 packet_src: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_dst: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_dur: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_seq: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 packet_sleeptime: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 packet_payload_len: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 			 
			 payload_address: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 payload_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 
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
			 
			 phy_tx_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 phy_tx_enable: OUT STD_LOGIC;
			 phy_tx_ready: IN STD_LOGIC );
END smac_tx_controller;

ARCHITECTURE arch_smac_tx_controller OF smac_tx_controller IS
	CONSTANT SYNC: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000001";
	CONSTANT RTS: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000010";
	CONSTANT CTS: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000011";
	CONSTANT ACK: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000100";
	CONSTANT DATA: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000101";
	
	TYPE state_t IS (IDLE, LOADING_LEN, LOADING_TYPE, LOADING_SRC_H, LOADING_SRC_L, LOADING_DST_H, LOADING_DST_L, LOADING_DUR_H, LOADING_DUR_L, LOADING_SEQ, LOADING_SLEEPTIME_H, LOADING_SLEEPTIME_L, LOADING_PAYLOAD, LOADING_CRC_H, LOADING_CRC_L, SENDING, WAITING, WAITING_FRAG);
	TYPE tx_state_t IS
	RECORD
		state: state_t;
		
		len: STD_LOGIC_VECTOR(8 DOWNTO 0);
		crc: STD_LOGIC_VECTOR(15 DOWNTO 0);
		counter: STD_LOGIC_VECTOR(31 DOWNTO 0);
		address_frag: STD_LOGIC_VECTOR(8 DOWNTO 0);
		
		ready: STD_LOGIC;
				
		payload_address: STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		crc_reset: STD_LOGIC;
		crc_soc: STD_LOGIC;
		crc_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
		crc_data_valid: STD_LOGIC;
		crc_eoc: STD_LOGIC;
		
		ram_address: STD_LOGIC_VECTOR(8 DOWNTO 0);
		ram_data_in: STD_LOGIC_VECTOR(7 DOWNTO 0);
		ram_wren: STD_LOGIC;
			 
		phy_tx_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
		phy_tx_enable: STD_LOGIC;
	END RECORD;
	
	SIGNAL tx_state, tx_state_next: tx_state_t;
	
BEGIN
	fsm_clk: PROCESS (clk, reset) IS
	BEGIN
		IF reset = '1' THEN
			tx_state.state <= IDLE;
			
			tx_state.len <= (OTHERS => '0');
			tx_state.crc <= (OTHERS => '0');
			
			tx_state.ready <= '0';
			
			tx_state.payload_address <= (OTHERS => '0');
			
			tx_state.crc_reset <= '1';
			tx_state.crc_soc <= '0';
			tx_state.crc_data <= (OTHERS => '0');
			tx_state.crc_data_valid <= '0';
			tx_state.crc_eoc <= '0';
			
			tx_state.ram_address <= (OTHERS => '0');
			tx_state.ram_data_in <= (OTHERS => '0');
			tx_state.ram_wren <= '0';
			
			tx_state.phy_tx_data <= (OTHERS => '0');
			tx_state.phy_tx_enable <= '0';
		ELSE
			IF RISING_EDGE(clk) THEN
				tx_state <= tx_state_next;
			END IF;
		END IF;
	END PROCESS;
	
	fsm: PROCESS (tx_state, load, send, packet_type, packet_src, packet_dst, packet_dur, packet_seq, packet_sleeptime, packet_payload_len, payload_data, crc_crc, crc_crc_valid, ram_data_out, phy_tx_ready) IS
	BEGIN
		tx_state_next <= tx_state;
		
		CASE tx_state.state IS
		
		WHEN IDLE =>
			IF load = '1' THEN
				tx_state_next.state <= LOADING_LEN;
				
				tx_state_next.ready <= '0';

				tx_state_next.payload_address <= (OTHERS => '0');
				
				tx_state_next.ram_address <= (OTHERS => '0');
				IF packet_type = SYNC THEN
					tx_state_next.len <= STD_LOGIC_VECTOR(TO_UNSIGNED(8,9));
					tx_state_next.ram_data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(8,8));
				ELSIF packet_type = RTS OR packet_type = CTS OR packet_type = ACK THEN
					tx_state_next.len <= STD_LOGIC_VECTOR(TO_UNSIGNED(10,9));
					tx_state_next.ram_data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(10,8));
				ELSIF packet_type = DATA THEN
					tx_state_next.len <= STD_LOGIC_VECTOR(TO_UNSIGNED(10,9)) + ('0' & packet_payload_len);
					tx_state_next.ram_data_in <= STD_LOGIC_VECTOR(TO_UNSIGNED(10,8)) + packet_payload_len;
				ELSE
					tx_state_next.len <= (OTHERS => '0');
					tx_state_next.ram_data_in <= (OTHERS => '0');
				END IF;
				tx_state_next.ram_wren <= '1';
			END IF;
			IF (send = '1') AND (phy_tx_ready = '1') THEN			
				tx_state_next.state <= WAITING;
				
				tx_state_next.ready <= '0';
				
				tx_state_next.address_frag <= (OTHERS => '0');
				
				tx_state_next.ram_address <= (OTHERS => '0');
			END IF;
			IF load = '0' AND send = '0' THEN
				-- auto reset initialization
				tx_state_next.ready <= '1';
				
				tx_state_next.crc <= (OTHERS => '0');
				
				tx_state_next.payload_address <= (OTHERS => '0');
				
				tx_state_next.crc_reset <= '1';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= (OTHERS => '0');
				tx_state_next.crc_data_valid <= '0';
				tx_state_next.crc_eoc <= '0';
				
				tx_state_next.ram_address <= (OTHERS => '0');
				tx_state_next.ram_data_in <= (OTHERS => '0');
				tx_state_next.ram_wren <= '0';
				
				tx_state_next.phy_tx_data <= (OTHERS => '0');
				tx_state_next.phy_tx_enable <= '0';
			END IF;
			
		WHEN LOADING_LEN =>
			tx_state_next.state <= LOADING_TYPE;
			
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_type;
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '1';
			tx_state_next.crc_data <= packet_type;
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '0';
			
		WHEN LOADING_TYPE =>
			tx_state_next.state <= LOADING_SRC_H;
			
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_src(15 DOWNTO 8);
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_src(15 DOWNTO 8);
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '0';
			
		WHEN LOADING_SRC_H =>
			tx_state_next.state <= LOADING_SRC_L;
			
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_src(7 DOWNTO 0);
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_src(7 DOWNTO 0);
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '0';
			
		WHEN LOADING_SRC_L =>
			IF packet_type = SYNC THEN
				tx_state_next.state <= LOADING_SEQ;
				
				tx_state_next.ram_address <= tx_state.ram_address + 1;
				tx_state_next.ram_data_in <= packet_seq;
				tx_state_next.ram_wren <= '1';
				
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= packet_seq;
				tx_state_next.crc_data_valid <= '1';
				tx_state_next.crc_eoc <= '0';
			ELSE
				tx_state_next.state <= LOADING_DST_H;
				
				tx_state_next.ram_address <= tx_state.ram_address + 1;
				tx_state_next.ram_data_in <= packet_dst(15 DOWNTO 8);
				tx_state_next.ram_wren <= '1';
				
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= packet_dst(15 DOWNTO 8);
				tx_state_next.crc_data_valid <= '1';
				tx_state_next.crc_eoc <= '0';
			END IF;
			
		WHEN LOADING_DST_H =>
			tx_state_next.state <= LOADING_DST_L;
				
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_dst(7 DOWNTO 0);
			tx_state_next.ram_wren <= '1';
				
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_dst(7 DOWNTO 0);
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '0';
			
		WHEN LOADING_DST_L =>
			tx_state_next.state <= LOADING_DUR_H;
			
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_dur(15 DOWNTO 8);
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_dur(15 DOWNTO 8);
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '0';
		
		WHEN LOADING_DUR_H =>
			tx_state_next.state <= LOADING_DUR_L;
			
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_dur(7 DOWNTO 0);
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_dur(7 DOWNTO 0);
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '0';
			
			IF packet_type = DATA THEN		
				tx_state_next.payload_address <= tx_state.payload_address + 1;
			END IF;
			
		WHEN LOADING_DUR_L =>
			tx_state_next.state <= LOADING_SEQ;
			
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_seq;
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_seq;
			tx_state_next.crc_data_valid <= '1';
			
			IF packet_type = DATA THEN
				tx_state_next.crc_eoc <= '0';
				
				tx_state_next.payload_address <= tx_state.payload_address + 1;
			ELSE
				tx_state_next.crc_eoc <= '1';
			END IF;
			
		WHEN LOADING_SEQ =>
			IF packet_type = SYNC THEN
				tx_state_next.state <= LOADING_SLEEPTIME_H;
				
				tx_state_next.ram_address <= tx_state.ram_address + 1;
				tx_state_next.ram_data_in <= packet_sleeptime(15 DOWNTO 8);
				tx_state_next.ram_wren <= '1';
				
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= packet_sleeptime(15 DOWNTO 8);
				tx_state_next.crc_data_valid <= '1';
				tx_state_next.crc_eoc <= '0';
			ELSIF packet_type = RTS OR packet_type = CTS OR packet_type = ACK THEN
				IF crc_crc_valid = '1' THEN
					tx_state_next.state <= LOADING_CRC_H;
					
					tx_state_next.crc <= crc_crc;
					
					tx_state_next.ram_address <= tx_state.ram_address + 1;
					tx_state_next.ram_data_in <= crc_crc(15 DOWNTO 8);
					tx_state_next.ram_wren <= '1';
				END IF;
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= (OTHERS => '0');
				tx_state_next.crc_data_valid <= '0';
				tx_state_next.crc_eoc <= '0';
			ELSIF packet_type = DATA THEN
				tx_state_next.state <= LOADING_PAYLOAD;
				
				IF packet_payload_len > 1 THEN
					tx_state_next.payload_address <= tx_state.payload_address + 1;
					
					tx_state_next.ram_address <= tx_state.ram_address + 1;
					tx_state_next.ram_data_in <= payload_data;
					tx_state_next.ram_wren <= '1';
					
					tx_state_next.crc_reset <= '0';
					tx_state_next.crc_soc <= '0';
					tx_state_next.crc_data <= payload_data;
					tx_state_next.crc_data_valid <= '1';
					tx_state_next.crc_eoc <= '0';
				ELSE
					tx_state_next.payload_address <= tx_state.payload_address + 1;
					
					tx_state_next.ram_address <= tx_state.ram_address + 1;
					tx_state_next.ram_data_in <= payload_data;
					tx_state_next.ram_wren <= '1';
					
					tx_state_next.crc_reset <= '0';
					tx_state_next.crc_soc <= '0';
					tx_state_next.crc_data <= payload_data;
					tx_state_next.crc_data_valid <= '1';
					tx_state_next.crc_eoc <= '1';
				END IF;
				
			ELSE
				tx_state_next.state <= IDLE;
			END IF;
		
		WHEN LOADING_SLEEPTIME_H =>
			tx_state_next.state <= LOADING_SLEEPTIME_L;
				
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= packet_sleeptime(7 DOWNTO 0);
			tx_state_next.ram_wren <= '1';
				
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= packet_sleeptime(7 DOWNTO 0);
			tx_state_next.crc_data_valid <= '1';
			tx_state_next.crc_eoc <= '1';
		
		WHEN LOADING_SLEEPTIME_L =>
			IF crc_crc_valid = '1' THEN
				tx_state_next.state <= LOADING_CRC_H;
				
				tx_state_next.crc <= crc_crc;
				
				tx_state_next.ram_address <= tx_state.ram_address + 1;
				tx_state_next.ram_data_in <= crc_crc(15 DOWNTO 8);
				tx_state_next.ram_wren <= '1';
			END IF;
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= (OTHERS => '0');
			tx_state_next.crc_data_valid <= '0';
			tx_state_next.crc_eoc <= '0';
			
		WHEN LOADING_PAYLOAD =>
			IF tx_state.payload_address < packet_payload_len + 1 THEN
				tx_state_next.payload_address <= tx_state.payload_address + 1;
			
				tx_state_next.ram_address <= tx_state.ram_address + 1;
				tx_state_next.ram_data_in <= payload_data;
				tx_state_next.ram_wren <= '1';
				
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= payload_data;
				tx_state_next.crc_data_valid <= '1';
				tx_state_next.crc_eoc <= '0';
			ELSIF tx_state.payload_address = packet_payload_len + 1 THEN
				tx_state_next.payload_address <= tx_state.payload_address + 1;
			
				tx_state_next.ram_address <= tx_state.ram_address + 1;
				tx_state_next.ram_data_in <= payload_data;
				tx_state_next.ram_wren <= '1';
				
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= payload_data;
				tx_state_next.crc_data_valid <= '1';
				tx_state_next.crc_eoc <= '1';
			ELSE
				IF crc_crc_valid = '1' THEN
					tx_state_next.state <= LOADING_CRC_H;
				
					tx_state_next.payload_address <= (OTHERS => '0');
					
					tx_state_next.crc <= crc_crc;
				
					tx_state_next.ram_address <= tx_state.ram_address + 1;
					tx_state_next.ram_data_in <= crc_crc(15 DOWNTO 8);
					tx_state_next.ram_wren <= '1';
				END IF;
				tx_state_next.crc_reset <= '0';
				tx_state_next.crc_soc <= '0';
				tx_state_next.crc_data <= (OTHERS => '0');
				tx_state_next.crc_data_valid <= '0';
				tx_state_next.crc_eoc <= '0';
			END IF;
		
		WHEN LOADING_CRC_H =>
			tx_state_next.state <= LOADING_CRC_L;
					
			tx_state_next.ram_address <= tx_state.ram_address + 1;
			tx_state_next.ram_data_in <= tx_state.crc(7 DOWNTO 0);
			tx_state_next.ram_wren <= '1';
			
			tx_state_next.crc_reset <= '0';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= (OTHERS => '0');
			tx_state_next.crc_data_valid <= '0';
			tx_state_next.crc_eoc <= '0';
			
		WHEN LOADING_CRC_L =>
			tx_state_next.state <= IDLE;			
					
			tx_state_next.ram_address <= (OTHERS => '0');
			tx_state_next.ram_data_in <= (OTHERS => '0');
			tx_state_next.ram_wren <= '0';
			
			tx_state_next.crc_reset <= '1';
			tx_state_next.crc_soc <= '0';
			tx_state_next.crc_data <= (OTHERS => '0');
			tx_state_next.crc_data_valid <= '0';
			tx_state_next.crc_eoc <= '0';
		
		WHEN SENDING =>
			IF phy_tx_ready = '1' THEN
				IF tx_state.ram_address <= tx_state.len THEN
					tx_state_next.state <= WAITING;
					
					tx_state_next.ram_address <= tx_state.ram_address + 1;
					
					tx_state_next.phy_tx_data <= ram_data_out;
					tx_state_next.phy_tx_enable <= '1';
				ELSE
					tx_state_next.state <= IDLE;
				END IF;
			ELSE
				tx_state_next.phy_tx_data <= (OTHERS => '0');
				tx_state_next.phy_tx_enable <= '0';
			END IF;
			
		WHEN WAITING =>
			tx_state_next.phy_tx_data <= (OTHERS => '0');
			tx_state_next.phy_tx_enable <= '0';
			IF phy_tx_ready = '1' THEN
				tx_state_next.state <= SENDING;
			END IF;
			IF UNSIGNED(tx_state.ram_address) - UNSIGNED(tx_state.address_frag) = 30 THEN
				tx_state_next.state <= WAITING_FRAG;
				tx_state_next.address_frag <= tx_state.ram_address;
				tx_state_next.counter <= STD_LOGIC_VECTOR(TO_UNSIGNED(2000000,32));
			END IF;			
			
		WHEN WAITING_FRAG =>
			IF tx_state.counter > 0 THEN
				tx_state_next.counter <= tx_state.counter - 1;
			ELSE
				IF phy_tx_ready = '1' THEN
					tx_state_next.state <= SENDING;
				END IF;
			END IF;
			
		END CASE;
	END PROCESS;
	
	fsm_output: PROCESS (tx_state) IS
	BEGIN
		ready <= tx_state.ready;				
		
		payload_address <= tx_state.payload_address;
		
		crc_reset <= tx_state.crc_reset;
		crc_soc <= tx_state.crc_soc;
		crc_data <= tx_state.crc_data;
		crc_data_valid <= tx_state.crc_data_valid;
		crc_eoc <= tx_state.crc_eoc;
		
		ram_address <= tx_state.ram_address;
		ram_data_in <= tx_state.ram_data_in;
		ram_wren <= tx_state.ram_wren;
			 
		phy_tx_data <= tx_state.phy_tx_data;
		phy_tx_enable <= tx_state.phy_tx_enable;
	END PROCESS;
	
END arch_smac_tx_controller;