LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY wsn IS
	PORT ( clk: IN STD_LOGIC;
			 rst: IN STD_LOGIC;
			 led: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
			 rf_enable: OUT STD_LOGIC;
			 rf_tx: OUT STD_LOGIC;
			 rf_rx: IN STD_LOGIC );
END wsn;

ARCHITECTURE arch_wsn OF wsn IS
	COMPONENT basic_uart IS
		GENERIC ( DIVISOR: NATURAL );
		PORT (
			clk: IN STD_LOGIC;   -- system clock
			reset: IN STD_LOGIC;
  
			-- Client interface
			rx_active: OUT STD_LOGIC;	-- receive in progress
			rx_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);  -- received byte
			rx_enable: OUT STD_LOGIC;  -- validates received byte (1 system clock spike)
			rx_error: OUT STD_LOGIC;	-- missing stop bit (1 system clock spike)
			tx_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- byte to send
			tx_enable: IN STD_LOGIC;  -- validates byte to send if tx_ready is '1'
			tx_ready: OUT STD_LOGIC;  -- if '1', we can send a new byte, otherwise we won't take it
  
			-- Physical interface
			rx: IN STD_LOGIC;
			tx: OUT STD_LOGIC
		);
	END COMPONENT;
	
	COMPONENT smac IS
		PORT ( clk: IN STD_LOGIC;
				 
				 reset: IN STD_LOGIC;
				 
				 node_address: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 status: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
				 
				 app_tx_ram_address: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_tx_ram_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				 
				 app_tx_send: IN STD_LOGIC;
				 app_tx_dst: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 app_tx_len: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_tx_done: OUT STD_LOGIC;
				 app_rx_src: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 app_rx_len: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_rx_done: OUT STD_LOGIC;
				 
				 app_rx_ram_address: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_rx_ram_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_rx_ram_wren: OUT STD_LOGIC;
				 
				 phy_enable: OUT STD_LOGIC;			 
				 phy_tx_data: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 phy_tx_enable: OUT STD_LOGIC;
				 phy_tx_ready: IN STD_LOGIC;
				 phy_rx_active: IN STD_LOGIC;
				 phy_rx_data: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				 phy_rx_enable: IN STD_LOGIC;
				 phy_rx_error: IN STD_LOGIC );
	END COMPONENT;
	
	COMPONENT app IS
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
	END COMPONENT;
	
	COMPONENT debounce IS
		GENERIC ( counter_size  :  INTEGER := 19 ); --counter size (19 bits gives 10.5ms with 50MHz clock)
		PORT( clk     : IN  STD_LOGIC;  --input clock
				button  : IN  STD_LOGIC;  --input signal to be debounced
				result  : OUT STD_LOGIC ); --debounced signal
	END COMPONENT;
	
	SIGNAL reset: STD_LOGIC;
	
	SIGNAL smac_node_address: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2,16));
	SIGNAL smac_status: STD_LOGIC_VECTOR(2 DOWNTO 0);
			 
	SIGNAL app_tx_ram_address: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_tx_ram_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
				 
	SIGNAL app_tx_send: STD_LOGIC;
	SIGNAL app_tx_dst: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL app_tx_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_tx_done: STD_LOGIC;
	SIGNAL app_rx_src: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL app_rx_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_rx_done: STD_LOGIC;
		 
	SIGNAL app_rx_ram_address: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_rx_ram_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL app_rx_ram_wren: STD_LOGIC;
				 
	SIGNAL phy_enable: STD_LOGIC;			 
	SIGNAL phy_tx_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL phy_tx_enable: STD_LOGIC;
	SIGNAL phy_tx_ready: STD_LOGIC;
	SIGNAL phy_rx_active: STD_LOGIC;
	SIGNAL phy_rx_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL phy_rx_enable: STD_LOGIC;
	SIGNAL phy_rx_error: STD_LOGIC;
	
BEGIN
	led <= smac_status;

	rf_enable <= phy_enable;
	
	basic_uart_inst: basic_uart
	GENERIC MAP (DIVISOR => 326) -- 9600 bps
	PORT MAP ( clk => clk,
				  reset => reset,
				  rx_active => phy_rx_active,
				  rx_data => phy_rx_data,
				  rx_enable => phy_rx_enable,
				  rx_error => phy_rx_error,
				  tx_data => phy_tx_data,
				  tx_enable => phy_tx_enable,
				  tx_ready => phy_tx_ready,
				  rx => rf_rx,
				  tx => rf_tx );

	smac_inst: smac
	PORT MAP ( clk => clk,
				  
				  reset => reset,
				  
				  node_address => smac_node_address,
				  status => smac_status,
				  
				  app_tx_ram_address => app_tx_ram_address,
				  app_tx_ram_data => app_tx_ram_data,
				  
				  app_tx_send => app_tx_send,
				  app_tx_dst => app_tx_dst,
				  app_tx_len => app_tx_len,
				  app_tx_done => app_tx_done,
				  app_rx_src => app_rx_src, 
				  app_rx_len => app_rx_len,
				  app_rx_done => app_rx_done,
				  
				  app_rx_ram_address => app_rx_ram_address,
				  app_rx_ram_data => app_rx_ram_data,
				  app_rx_ram_wren => app_rx_ram_wren,
				 
				  phy_enable => phy_enable,
				  phy_tx_data => phy_tx_data,
				  phy_tx_enable => phy_tx_enable,
				  phy_tx_ready => phy_tx_ready,
				  phy_rx_active => phy_rx_active,
				  phy_rx_data => phy_rx_data,
				  phy_rx_enable => phy_rx_enable,
				  phy_rx_error => phy_rx_error );
	
	app_inst: app
	PORT MAP ( clk => clk,
			 
				  reset => reset,
			 
				  tx_ram_address => app_tx_ram_address,
				  tx_ram_data => app_tx_ram_data,
			 
				  tx_send => app_tx_send,
				  tx_dst => app_tx_dst,
				  tx_len => app_tx_len,
				  tx_done => app_tx_done,
				  rx_src => app_rx_src,
				  rx_len => app_rx_len,
				  rx_done => app_rx_done,
			 
				  rx_ram_address => app_rx_ram_address,
				  rx_ram_data => app_rx_ram_data,
				  rx_ram_wren => app_rx_ram_wren );

	debounce_inst: debounce
	GENERIC MAP ( counter_size => 19 )
	PORT MAP ( clk => clk,
				  button => NOT(rst),
				  result => reset );
END arch_wsn;