LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY app IS
	PORT ( clk: IN STD_LOGIC;
			 
			 reset: IN STD_LOGIC;
			 
			 tx_ram_address: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 tx_ram_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 
			 tx_send: OUT STD_LOGIC;
			 tx_dst: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			 tx_len: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
			 tx_done: IN STD_LOGIC;
			 rx_src: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 rx_len: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 rx_done: IN STD_LOGIC;
			 
			 rx_ram_address: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 rx_ram_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
			 rx_ram_wren: IN STD_LOGIC );
END app;

ARCHITECTURE arch_app OF app IS
	COMPONENT ram256dp IS
		PORT ( clock: IN STD_LOGIC  := '1';
				 data: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
				 rdaddress: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
				 wraddress: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
				 wren: IN STD_LOGIC  := '0';
				 q: OUT STD_LOGIC_VECTOR (7 DOWNTO 0) );
	END COMPONENT;

	SIGNAL app_tx_ram_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_tx_ram_address: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_tx_ram_wren: STD_LOGIC;
	
	SIGNAL app_rx_ram_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_rx_ram_address: STD_LOGIC_VECTOR(7 DOWNTO 0);
	
BEGIN
	app_tx_ram256dp_inst: ram256dp
	PORT MAP ( clock => clk,
				  data => app_tx_ram_data,
				  rdaddress => tx_ram_address,
				  wraddress => app_tx_ram_address,
				  wren => app_tx_ram_wren,
				  q => tx_ram_data );
				  
	app_rx_ram256dp_inst: ram256dp
	PORT MAP ( clock => clk,
				  data => rx_ram_data,
				  rdaddress => app_rx_ram_address,
				  wraddress => rx_ram_address,
				  wren => rx_ram_wren,
				  q => app_rx_ram_data );

END arch_app;