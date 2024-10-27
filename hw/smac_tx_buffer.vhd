LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY smac_tx_buffer IS
	PORT ( clk: IN STD_LOGIC;
			 reset: IN STD_LOGIC;
			 
			 address: IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			 data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 wren: IN STD_LOGIC;
			 len: IN STD_LOGIC_VECTOR(8 DOWNTO 0);
			 
			 send: IN STD_LOGIC;
			 ready: OUT STD_LOGIC;
			 
			 phy_tx_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 phy_tx_enable: OUT STD_LOGIC;
			 phy_tx_ready: IN STD_LOGIC );
END smac_tx_buffer;

ARCHITECTURE arch_smac_tx_buffer OF smac_tx_buffer IS
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
	SIGNAL phy_tx_data_next: STD_LOGIC_VECTOR(7 DOWNTO 0);		-- dodano
	SIGNAL phy_tx_enable_next: STD_LOGIC;								-- dodano
	
	--TYPE state_t IS (IDLE, SENDING_LEN, LOADING, SENDING);
	TYPE state_t IS (IDLE, SENDING_LEN, SENDING, WAITING);
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
				  	
	fsm_clk: PROCESS (clk, reset) IS
	BEGIN
		IF reset = '1' THEN
			state <= IDLE;
			address_counter <= (OTHERS => '0');
		ELSE
			IF RISING_EDGE(clk) THEN
				state <= state_next;
				address_counter <= address_counter_next;
				phy_tx_data <= phy_tx_data_next;			-- dodano
				phy_tx_enable <= phy_tx_enable_next;	-- dodano
				IF crc_crc_valid = '1' THEN
					crc16 <= crc_crc;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
	fsm: PROCESS (state, send, address, data, wren, phy_tx_ready) IS
	BEGIN
		state_next <= state;
		address_counter_next <= address_counter;
		
		CASE state IS
		
		WHEN IDLE =>
			ready <= '1';
			ram_address <= address;
			ram_data_in <= data;
			ram_wren <= wren;
			phy_tx_data_next <= (OTHERS => '0');	-- dodano
			phy_tx_enable_next <= '0';					-- dodano
			IF send = '1' THEN
				address_counter_next <= (OTHERS => '0');
				state_next <= SENDING_LEN;
			END IF;
			crc_reset <= '1';
			crc_soc <= '0';
			crc_data <= (OTHERS => '0');
			crc_data_valid <= '0';
			crc_eoc <= '0';
			
		WHEN SENDING_LEN =>
			ready <= '0';
			ram_address <= address_counter;
			ram_data_in <= (OTHERS => '0');
			ram_wren <= '0';
			IF phy_tx_ready = '1' THEN
				address_counter_next <= (OTHERS => '0');
				phy_tx_data_next <= len(7 DOWNTO 0); -- dodano
				phy_tx_enable_next <= '1';				 -- dodano
				state_next <= WAITING;
			ELSE
				phy_tx_data_next <= (OTHERS => '0'); -- dodano
				phy_tx_enable_next <= '0';				 -- dodano
			END IF;
			crc_reset <= '1';
			crc_soc <= '0';
			crc_data <= (OTHERS => '0');
			crc_data_valid <= '0';
			crc_eoc <= '0';
				
		WHEN SENDING =>
			ready <= '0';
			ram_address <= address_counter;
			ram_data_in <= (OTHERS => '0');
			ram_wren <= '0';
			IF phy_tx_ready = '1' THEN
				IF address_counter = STD_LOGIC_VECTOR(TO_UNSIGNED(0, 9)) THEN
					phy_tx_data_next <= ram_data_out;  -- dodano
					phy_tx_enable_next <= '1';			  -- dodano
					
					crc_reset <= '0';
					crc_data <= ram_data_out;
					crc_data_valid <= '1';
					crc_soc <= '1';
					crc_eoc <= '0';
					
					address_counter_next <= address_counter + 1;
					
					state_next <= WAITING;
				ELSIF (address_counter > 0) AND (address_counter < (len - 3)) THEN
					phy_tx_data_next <= ram_data_out;  -- dodano
					phy_tx_enable_next <= '1';			  -- dodano
					
					crc_reset <= '0';
					crc_data <= ram_data_out;
					crc_data_valid <= '1';
					crc_soc <= '0';
					crc_eoc <= '0';
					
					address_counter_next <= address_counter + 1;
					
					state_next <= WAITING;
				ELSIF address_counter = (len - 3) THEN
					phy_tx_data_next <= ram_data_out;  -- dodano
					phy_tx_enable_next <= '1';			  -- dodano
					
					crc_reset <= '0';
					crc_data <= ram_data_out;
					crc_data_valid <= '1';
					crc_soc <= '0';
					crc_eoc <= '1';
					
					address_counter_next <= address_counter + 1;
					
					state_next <= WAITING;
				ELSIF address_counter = (len - 2) THEN
					phy_tx_data_next <= crc16(15 DOWNTO 8);  -- dodano
					phy_tx_enable_next <= '1';					  -- dodano
					
					crc_reset <= '0';
					crc_data <= (OTHERS => '0');
					crc_data_valid <= '0';
					crc_soc <= '0';
					crc_eoc <= '0';
					
					address_counter_next <= address_counter + 1;
					
					state_next <= WAITING;
				ELSIF address_counter = (len - 1) THEN
					phy_tx_data_next <= crc16(7 DOWNTO 0);  -- dodano
					phy_tx_enable_next <= '1';					 -- dodano
					
					crc_reset <= '0';
					crc_data <= (OTHERS => '0');
					crc_data_valid <= '0';
					crc_soc <= '0';
					crc_eoc <= '0';
				
					state_next <= IDLE;
				END IF;
			ELSE
				phy_tx_data_next <= (OTHERS => '0');		-- dodano
				phy_tx_enable_next <= '0';						-- dodano
				
				crc_reset <= '0';
				crc_soc <= '0';
				crc_data <= (OTHERS => '0');
				crc_data_valid <= '0';
				crc_eoc <= '0';
			END IF;

		WHEN WAITING =>
			ready <= '0';
			ram_address <= address_counter;
			ram_data_in <= (OTHERS => '0');
			ram_wren <= '0';
			phy_tx_data_next <= (OTHERS => '0');
			phy_tx_enable_next <= '0';
			IF phy_tx_ready = '1' THEN
				state_next <= SENDING;
			END IF;
			crc_data <= (OTHERS => '0');
			crc_data_valid <= '0';
			crc_soc <= '0';
			crc_eoc <= '0';
			crc_reset <= '0';
		
		END CASE;
	END PROCESS;	
	
END arch_smac_tx_buffer;