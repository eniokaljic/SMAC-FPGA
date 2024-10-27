LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY smac_rx_buffer IS
	PORT ( clk: IN STD_LOGIC;
			 reset: IN STD_LOGIC;
			 
			 address: IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			 data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 len: OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
			 
			 receive: IN STD_LOGIC;
			 ready: OUT STD_LOGIC;
			 error: OUT STD_LOGIC;
			 
			 phy_rx_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 phy_rx_enable: IN STD_LOGIC;
			 phy_rx_error: IN STD_LOGIC );
END smac_rx_buffer;

ARCHITECTURE arch_smac_rx_buffer OF smac_rx_buffer IS
	COMPONENT ram512 IS
		PORT ( address: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
				 clock: IN STD_LOGIC  := '1';
				 data: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
				 wren: IN STD_LOGIC ;
				 q: OUT STD_LOGIC_VECTOR (7 DOWNTO 0) );
	END COMPONENT;
	
	COMPONENT crc_gen IS
		PORT ( clock: IN  STD_LOGIC;
				 reset: IN  STD_LOGIC;
				 soc: IN  STD_LOGIC;
				 data: IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
				 data_valid: IN  STD_LOGIC;
				 eoc: IN  STD_LOGIC;
				 crc: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 crc_valid: OUT STD_LOGIC );
	END COMPONENT;

	SIGNAL ram_address: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL ram_data_in: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ram_data_out: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL ram_wren: STD_LOGIC;
	
	SIGNAL crc_reset: STD_LOGIC;
	SIGNAL crc_soc: STD_LOGIC;
	SIGNAL crc_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL crc_data_valid: STD_LOGIC;
	SIGNAL crc_eoc: STD_LOGIC;
	SIGNAL crc_crc: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL crc_crc_valid: STD_LOGIC;
	
	SIGNAL address_counter: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL address_counter_next: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL crc16: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL frame_len: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL frame_len_next: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL frame_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL frame_data_next: STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	TYPE state_t IS (IDLE, RECEIVING_LEN, RECEIVING, STORING);
	SIGNAL state, state_next: state_t;

BEGIN
	ram512_inst: ram512
	PORT MAP ( address => ram_address,
				  clock => clk,
				  data => ram_data_in,
				  wren => ram_wren,
				  q => ram_data_out );
				  
	crc_gen_inst: crc_gen
	PORT MAP ( clock => clk, 
				  reset => crc_reset,
				  soc => crc_soc,
				  data => crc_data,
				  data_valid => crc_data_valid,
				  eoc => crc_eoc,
				  crc => crc_crc,
				  crc_valid => crc_crc_valid);
	
	len <= frame_len;
	
	fsm_clk: PROCESS (clk, reset) IS
	BEGIN
		IF reset = '1' THEN
			state <= IDLE;
			address_counter <= (OTHERS => '0');
		ELSE
			IF RISING_EDGE(clk) THEN
				state <= state_next;
				address_counter <= address_counter_next;
				frame_len <= frame_len_next;
				frame_data <= frame_data_next;
				IF crc_crc_valid = '1' THEN
					crc16 <= crc_crc;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	fsm: PROCESS (state, receive, address, phy_rx_enable, phy_rx_error) IS
	BEGIN
		state_next <= state;
		address_counter_next <= address_counter;
		frame_len_next <= frame_len;
		frame_data_next <= frame_data;
		
		CASE state IS
		
		WHEN IDLE =>
			ready <= '1';
			error <= '0';
			ram_address <= address;
			ram_data_in <= (OTHERS => '0');
			ram_wren <= '0';
			data <= ram_data_out;
			IF receive = '1' THEN
				frame_len_next <= (OTHERS => '0');
				address_counter_next <= (OTHERS => '0');
				state_next <= RECEIVING_LEN;
			END IF;
			crc_reset <= '1';
			crc_soc <= '0';
			crc_data <= (OTHERS => '0');
			crc_data_valid <= '0';
			crc_eoc <= '0';
			
		WHEN RECEIVING_LEN =>
			ready <= '0';
			error <= '0';
			ram_address <= address_counter;
			ram_data_in <= (OTHERS => '0');
			ram_wren <= '0';
			data <= (OTHERS => '0');
			IF phy_rx_enable = '1' THEN
				address_counter_next <= (OTHERS => '0');
				frame_len_next <= '0' & phy_rx_data;
				error <= '0'; 											--
				state_next <= RECEIVING;
			ELSIF phy_rx_error = '1' THEN
				frame_len_next <= (OTHERS => '0');
				error <= '1';
				state_next <= IDLE;
			END IF;
			crc_reset <= '1';
			crc_soc <= '0';
			crc_data <= (OTHERS => '0');
			crc_data_valid <= '0';
			crc_eoc <= '0';
			
		WHEN RECEIVING =>
			ready <= '0';
			error <= '0';
			data <= (OTHERS => '0');
			IF phy_rx_enable = '1' THEN
				error <= '0';											--
				ram_address <= address_counter;
				ram_data_in <= phy_rx_data;
				ram_wren <= '1';
				
				IF address_counter = STD_LOGIC_VECTOR(TO_UNSIGNED(0, 9)) THEN
					crc_reset <= '0';
					crc_data <= phy_rx_data;
					crc_data_valid <= '1';
					crc_soc <= '1';
					crc_eoc <= '0';
					
					state_next <= STORING;
				ELSIF (address_counter > 0) AND (address_counter < (frame_len - 3)) THEN
					crc_reset <= '0';
					crc_data <= phy_rx_data;
					crc_data_valid <= '1';
					crc_soc <= '0';
					crc_eoc <= '0';
					
					state_next <= STORING;
				ELSIF address_counter = (frame_len - 3) THEN
					crc_reset <= '0';
					crc_data <= phy_rx_data;
					crc_data_valid <= '1';
					crc_soc <= '0';
					crc_eoc <= '1';
					
					state_next <= STORING;
				ELSIF address_counter = (frame_len - 2) THEN
					crc_reset <= '0';
					crc_data <= (OTHERS => '0');
					crc_data_valid <= '0';
					crc_soc <= '0';
					crc_eoc <= '0';
					
					IF phy_rx_data /= crc16(15 DOWNTO 8) THEN
						error <= '1';
						state_next <= IDLE;
					ELSE
						state_next <= STORING;
					END IF;
				ELSIF address_counter = (frame_len - 1) THEN
					crc_reset <= '0';
					crc_data <= (OTHERS => '0');
					crc_data_valid <= '0';
					crc_soc <= '0';
					crc_eoc <= '0';
					IF phy_rx_data /= crc16(7 DOWNTO 0) THEN
						error <= '1';
						state_next <= IDLE;
					ELSE
						state_next <= STORING;
					END IF;
				ELSE
					ram_address <= address_counter;
					ram_data_in <= (OTHERS => '0');
					ram_wren <= '0';				
				END IF;				
			ELSIF phy_rx_error = '1' THEN
				error <= '1';
				
				ram_address <= address_counter;
				ram_data_in <= (OTHERS => '0');
				ram_wren <= '0';
				
				crc_reset <= '0';
				crc_soc <= '0';
				crc_data <= (OTHERS => '0');
				crc_data_valid <= '0';
				crc_eoc <= '0';
				
				state_next <= IDLE;
			ELSE
				ram_address <= address_counter;
				ram_data_in <= (OTHERS => '0');
				ram_wren <= '0';				
				
				crc_reset <= '0';
				crc_soc <= '0';
				crc_data <= (OTHERS => '0');
				crc_data_valid <= '0';
				crc_eoc <= '0';
			END IF;
			
		WHEN STORING =>
			ready <= '0';
			error <= '0';
			ram_address <= address_counter;
			ram_data_in <= (OTHERS => '0');
			ram_wren <= '0';
			data <= (OTHERS => '0');			
			IF address_counter < frame_len - 1 THEN
				address_counter_next <= address_counter + 1;
				state_next <= RECEIVING;
			ELSE
				state_next <= IDLE;
			END IF;
			crc_reset <= '0';
			crc_soc <= '0';
			crc_data <= (OTHERS => '0');
			crc_data_valid <= '0';
			crc_eoc <= '0';
			
		END CASE;
	END PROCESS;
	
END arch_smac_rx_buffer;