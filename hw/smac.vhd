LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY smac IS
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
END smac;

ARCHITECTURE arch_smac OF smac IS
	COMPONENT smac_tx_controller IS
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
	END COMPONENT;
	
	COMPONENT smac_rx_controller IS
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
	END COMPONENT;
	
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
	
	COMPONENT smac_controller IS
		PORT ( clk: IN STD_LOGIC;
				 
				 reset: IN STD_LOGIC;
				 
				 node_address: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 status: OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
				 
				 timer1_reset: OUT STD_LOGIC;
				 timer1_t_in: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timer1_t_out: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timer1_timeout: IN STD_LOGIC;
				 
				 timer2_reset: OUT STD_LOGIC;
				 timer2_t_in: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timer2_t_out: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timer2_timeout: IN STD_LOGIC;
				 
				 timer3_reset: OUT STD_LOGIC;
				 timer3_t_in: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timer3_t_out: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timer3_timeout: IN STD_LOGIC;
				 
				 random_num: IN STD_LOGIC_VECTOR(23 DOWNTO 0);
				 random_num_reset: OUT STD_LOGIC;
				 
				 app_tx_send: IN STD_LOGIC;
				 app_tx_dst: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 app_tx_len: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_tx_done: OUT STD_LOGIC;
				 app_rx_src: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 app_rx_len: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 app_rx_done: OUT STD_LOGIC;
				 
				 tx_reset: OUT STD_LOGIC;
				 tx_load: OUT STD_LOGIC;
				 tx_send: OUT STD_LOGIC;
				 tx_ready: IN STD_LOGIC;
				 tx_packet_type: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 tx_packet_src: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 tx_packet_dst: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 tx_packet_dur: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 tx_packet_seq: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 tx_packet_sleeptime: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 tx_packet_payload_len: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
				 
				 rx_reset: OUT STD_LOGIC;
				 rx_receive: OUT STD_LOGIC;
				 rx_store: OUT STD_LOGIC;
				 rx_ready: IN STD_LOGIC;
				 rx_error: IN STD_LOGIC;
				 rx_packet_type: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				 rx_packet_src: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 rx_packet_dst: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 rx_packet_dur: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 rx_packet_seq: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
				 rx_packet_sleeptime: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 rx_packet_payload_len: IN STD_LOGIC_VECTOR(7 DOWNTO 0);

				 phy_enable: OUT STD_LOGIC;
				 phy_rx_active: IN STD_LOGIC );
	END COMPONENT;
	
	COMPONENT timer_clock IS
		PORT ( clk: IN STD_LOGIC;
				 reset: IN STD_LOGIC;
				 ena: OUT STD_LOGIC );
	END COMPONENT;
	
	COMPONENT timer IS
		PORT ( clk: IN STD_LOGIC;
				 ena: IN STD_LOGIC;
				 reset: IN STD_LOGIC;
				 t_in: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
				 t_out: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
				 timeout: OUT STD_LOGIC );
	END COMPONENT;
	
	COMPONENT random_gen IS
		PORT ( clk : IN STD_LOGIC;
				 reset: IN STD_LOGIC;
				 random_num : OUT STD_LOGIC_VECTOR(23 DOWNTO 0) );
	END COMPONENT;
	
	COMPONENT noise_gen IS
	Generic (
				W : integer := 16;					-- LFSR scaleable from 24 down to 4 bits
				V : integer := 18;					-- LFSR for non uniform clocking scalable from 24 down to 18 bit
				g_type : integer := 0;			-- gausian distribution type, 0 = unimodal, 1 = bimodal, from g_noise_out
				u_type : integer := 1			-- uniform distribution type, 0 = uniform, 1 =  ave-uniform, from u_noise_out
			);
    Port ( 
			clk 						: 		in  STD_LOGIC;
			n_reset 			: 		in  STD_LOGIC;
			enable				: 		in  STD_LOGIC;
			g_noise_out 	:		out STD_LOGIC_VECTOR (W-1 downto 0);					-- port for bimodal/unimodal gaussian distributions
			u_noise_out 	: 		out  STD_LOGIC_VECTOR (W-1 downto 0)						-- port for uniform/ave-uniform distributions
			);
	END COMPONENT;
	
	SIGNAL timer_clock_ena: STD_LOGIC;
	
	SIGNAL timer1_reset: STD_LOGIC;
	SIGNAL timer1_t_in: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL timer1_t_out: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL timer1_timeout: STD_LOGIC;
	
	SIGNAL timer2_reset: STD_LOGIC;
	SIGNAL timer2_t_in: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL timer2_t_out: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL timer2_timeout: STD_LOGIC;
	
	SIGNAL timer3_reset: STD_LOGIC;
	SIGNAL timer3_t_in: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL timer3_t_out: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL timer3_timeout: STD_LOGIC;
	
	SIGNAL random_num: STD_LOGIC_VECTOR(23 DOWNTO 0);
	SIGNAL random_num_reset: STD_LOGIC;
	
	SIGNAL smac_tx_reset: STD_LOGIC;
	SIGNAL smac_tx_load: STD_LOGIC;
	SIGNAL smac_tx_send: STD_LOGIC;
	SIGNAL smac_tx_ready: STD_LOGIC;
	SIGNAL smac_tx_packet_type: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_tx_packet_src: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_tx_packet_dst: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_tx_packet_dur: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_tx_packet_seq: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_tx_packet_sleeptime: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_tx_packet_payload_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	SIGNAL smac_tx_crc_reset: STD_LOGIC;
	SIGNAL smac_tx_crc_soc: STD_LOGIC;
	SIGNAL smac_tx_crc_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_tx_crc_data_valid: STD_LOGIC;
	SIGNAL smac_tx_crc_eoc: STD_LOGIC;
	SIGNAL smac_tx_crc_crc: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_tx_crc_crc_valid: STD_LOGIC;
	
	SIGNAL smac_tx_ram_address: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL smac_tx_ram_data_in: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_tx_ram_wren: STD_LOGIC;
	SIGNAL smac_tx_ram_data_out: STD_LOGIC_VECTOR(7 DOWNTO 0);
		
	SIGNAL smac_rx_reset: STD_LOGIC;
	SIGNAL smac_rx_receive: STD_LOGIC;
	SIGNAL smac_rx_store: STD_LOGIC;
	SIGNAL smac_rx_ready: STD_LOGIC;
	SIGNAL smac_rx_error: STD_LOGIC;
	SIGNAL smac_rx_packet_type: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_rx_packet_src: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_rx_packet_dst: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_rx_packet_dur: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_rx_packet_seq: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_rx_packet_sleeptime: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_rx_packet_payload_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	SIGNAL smac_rx_crc_reset: STD_LOGIC;
	SIGNAL smac_rx_crc_soc: STD_LOGIC;
	SIGNAL smac_rx_crc_data: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_rx_crc_data_valid: STD_LOGIC;
	SIGNAL smac_rx_crc_eoc: STD_LOGIC;
	SIGNAL smac_rx_crc_crc: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL smac_rx_crc_crc_valid: STD_LOGIC;
	 
	SIGNAL smac_rx_ram_address: STD_LOGIC_VECTOR(8 DOWNTO 0);
	SIGNAL smac_rx_ram_data_in: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL smac_rx_ram_wren: STD_LOGIC;
	SIGNAL smac_rx_ram_data_out: STD_LOGIC_VECTOR(7 DOWNTO 0);
		
BEGIN	
	smac_tx_controller_inst: smac_tx_controller
	PORT MAP ( clk => clk,
				  
				  reset => smac_tx_reset,
				  load => smac_tx_load,
				  send => smac_tx_send,
				  ready => smac_tx_ready,				  
				  packet_type => smac_tx_packet_type,
				  packet_src => smac_tx_packet_src,
				  packet_dst => smac_tx_packet_dst,
				  packet_dur => smac_tx_packet_dur,
				  packet_seq => smac_tx_packet_seq,
				  packet_sleeptime => smac_tx_packet_sleeptime,
				  packet_payload_len => smac_tx_packet_payload_len,
				  
				  payload_address => app_tx_ram_address,
				  payload_data => app_tx_ram_data,
				  
				  crc_reset => smac_tx_crc_reset,
				  crc_soc => smac_tx_crc_soc,
				  crc_data => smac_tx_crc_data,
				  crc_data_valid => smac_tx_crc_data_valid,
				  crc_eoc => smac_tx_crc_eoc,
				  crc_crc => smac_tx_crc_crc,
				  crc_crc_valid => smac_tx_crc_crc_valid,
				  
				  ram_address => smac_tx_ram_address,
				  ram_data_in => smac_tx_ram_data_in,
				  ram_wren => smac_tx_ram_wren,
				  ram_data_out => smac_tx_ram_data_out,
				  				  
				  phy_tx_data => phy_tx_data,
				  phy_tx_enable => phy_tx_enable,
				  phy_tx_ready => phy_tx_ready );
				  
	smac_tx_ram512_inst: ram512
	PORT MAP ( address => smac_tx_ram_address,
				  clock => clk,
				  data => smac_tx_ram_data_in,
				  wren => smac_tx_ram_wren,
				  q => smac_tx_ram_data_out );
				  
	smac_tx_crc_gen_inst: crc_gen
	PORT MAP ( clock => clk, 
				  reset => smac_tx_crc_reset,
				  soc => smac_tx_crc_soc,
				  data => smac_tx_crc_data,
				  data_valid => smac_tx_crc_data_valid,
				  eoc => smac_tx_crc_eoc,
				  crc => smac_tx_crc_crc,
				  crc_valid => smac_tx_crc_crc_valid);
				  
	smac_rx_controller_inst: smac_rx_controller
	PORT MAP ( clk => clk,
				 
				  reset => smac_rx_reset,
				  receive => smac_rx_receive,
				  store => smac_rx_store,
				  ready => smac_rx_ready,
				  error => smac_rx_error,
				  packet_type => smac_rx_packet_type,
				  packet_src => smac_rx_packet_src,
				  packet_dst => smac_rx_packet_dst,
				  packet_dur => smac_rx_packet_dur,
				  packet_seq => smac_rx_packet_seq,
				  packet_sleeptime => smac_rx_packet_sleeptime,
				  packet_payload_len => smac_rx_packet_payload_len,
				  
				  payload_address => app_rx_ram_address,
				  payload_data => app_rx_ram_data,
				  payload_wren => app_rx_ram_wren,
				  
				  crc_reset => smac_rx_crc_reset,
				  crc_soc => smac_rx_crc_soc,
				  crc_data => smac_rx_crc_data,
				  crc_data_valid => smac_rx_crc_data_valid,
				  crc_eoc => smac_rx_crc_eoc,
				  crc_crc => smac_rx_crc_crc,
				  crc_crc_valid => smac_rx_crc_crc_valid,
				  
				  ram_address => smac_rx_ram_address,
				  ram_data_in => smac_rx_ram_data_in,
				  ram_wren => smac_rx_ram_wren,
				  ram_data_out => smac_rx_ram_data_out,
				  
				  phy_rx_data => phy_rx_data,
				  phy_rx_enable => phy_rx_enable,
				  phy_rx_error => phy_rx_error );
	
	smac_rx_ram512_inst: ram512
	PORT MAP ( address => smac_rx_ram_address,
				  clock => clk,
				  data => smac_rx_ram_data_in,
				  wren => smac_rx_ram_wren,
				  q => smac_rx_ram_data_out );
	
	smac_rx_crc_gen_inst: crc_gen
	PORT MAP ( clock => clk, 
				  reset => smac_rx_crc_reset,
				  soc => smac_rx_crc_soc,
				  data => smac_rx_crc_data,
				  data_valid => smac_rx_crc_data_valid,
				  eoc => smac_rx_crc_eoc,
				  crc => smac_rx_crc_crc,
				  crc_valid => smac_rx_crc_crc_valid);
	
	smac_controller_inst: smac_controller
	PORT MAP ( clk => clk,
				  
				  reset => reset,
				  
				  node_address => node_address,
				  status => status,
				  
				  timer1_reset => timer1_reset,
				  timer1_t_in => timer1_t_in,
				  timer1_t_out => timer1_t_out,
				  timer1_timeout => timer1_timeout,
				  
				  timer2_reset => timer2_reset,
				  timer2_t_in => timer2_t_in,
				  timer2_t_out => timer2_t_out,
				  timer2_timeout => timer2_timeout,
				  
				  timer3_reset => timer3_reset,
				  timer3_t_in => timer3_t_in,
				  timer3_t_out => timer3_t_out,
				  timer3_timeout => timer3_timeout,
				  
				  random_num => random_num,
				  random_num_reset => random_num_reset,
				  
				  app_tx_send => app_tx_send,
				  app_tx_dst => app_tx_dst,
				  app_tx_len => app_tx_len,
				  app_tx_done => app_tx_done,
				  app_rx_src => app_rx_src,
				  app_rx_len => app_rx_len,
				  app_rx_done => app_rx_done,
				  
				  tx_reset => smac_tx_reset,
				  tx_load => smac_tx_load,
				  tx_send => smac_tx_send,
				  tx_ready => smac_tx_ready,
				  tx_packet_type => smac_tx_packet_type,
				  tx_packet_src => smac_tx_packet_src,
				  tx_packet_dst => smac_tx_packet_dst,
				  tx_packet_dur => smac_tx_packet_dur,
				  tx_packet_seq => smac_tx_packet_seq,
				  tx_packet_sleeptime => smac_tx_packet_sleeptime,
				  tx_packet_payload_len => smac_tx_packet_payload_len,
				  
				  rx_reset => smac_rx_reset,
				  rx_receive => smac_rx_receive,
				  rx_store => smac_rx_store,
				  rx_ready => smac_rx_ready,
				  rx_error => smac_rx_error,
				  rx_packet_type => smac_rx_packet_type,
				  rx_packet_src => smac_rx_packet_src,
				  rx_packet_dst => smac_rx_packet_dst,
				  rx_packet_dur => smac_rx_packet_dur,
				  rx_packet_seq => smac_rx_packet_seq,
				  rx_packet_sleeptime => smac_rx_packet_sleeptime,
				  rx_packet_payload_len => smac_rx_packet_payload_len,
				  
				  phy_enable => phy_enable,
				  phy_rx_active => phy_rx_active );
	
	timer_clock_inst: timer_clock
	PORT MAP ( clk => clk,
				  reset => reset,
				  ena => timer_clock_ena );
	
	timer1_inst: timer
	PORT MAP ( clk => clk,
				  ena => timer_clock_ena,
				  reset => timer1_reset,
				  t_in => timer1_t_in,
				  t_out => timer1_t_out,
				  timeout => timer1_timeout );
	
	timer2_inst: timer
	PORT MAP ( clk => clk,
				  ena => timer_clock_ena,
				  reset => timer2_reset,
				  t_in => timer2_t_in,
				  t_out => timer2_t_out,
				  timeout => timer2_timeout );
	
	timer3_inst: timer
	PORT MAP ( clk => clk,
				  ena => timer_clock_ena,
				  reset => timer3_reset,
				  t_in => timer3_t_in,
				  t_out => timer3_t_out,
				  timeout => timer3_timeout );
				  
	random_gen_inst: random_gen
	PORT MAP ( clk => clk,
				  reset => random_num_reset,
				  random_num => random_num );				  
	
	--noise_gen_inst: noise_gen
	--GENERIC MAP ( W => 24, V => 24, g_type => 0, u_type => 0)
	--PORT MAP ( clk => clk,
	--			  n_reset => NOT(random_num_reset),
	--			  enable => '1',
	--			  u_noise_out => random_num,
	--			  g_noise_out => OPEN );
END arch_smac;