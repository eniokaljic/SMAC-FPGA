LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY smac_controller IS
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
END smac_controller;

ARCHITECTURE arch_smac_controller OF smac_controller IS
	CONSTANT SYNC: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000001";
	CONSTANT RTS: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000010";
	CONSTANT CTS: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000011";
	CONSTANT ACK: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000100";
	CONSTANT DATA: STD_LOGIC_VECTOR(7 DOWNTO 0) := "00000101";
	
	CONSTANT TASYNC: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(70,16));		-- 46
	CONSTANT TADATA: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(72,16));		-- 51
	CONSTANT TSLEEP: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1149,16));		-- 785
	CONSTANT DIFS: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(5,16));			-- 8
	CONSTANT SIFS: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1,16));			-- 4	
	CONSTANT RFSETUP: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(10,16));		-- 6
	CONSTANT TIMEROFF: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(65535,16));
	CONSTANT SYNC_DELAY: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1,16));
	CONSTANT RTS_DELAY: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1,16));
	CONSTANT CTS_DELAY: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1,16));
	CONSTANT ACK_DELAY: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(1,16));
	CONSTANT DATA_DELAY: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(34,16));
	
	TYPE state_t IS (IDLE, WAITING_INTRO, INTRO, SLEEP, WAITING_ACTIVE_SYNC, ACTIVE_SYNC, LOADING_SYNC, SENDING_SYNC, ACTIVE_DATA, SLEEP_NAV, BACKOFF, LOADING_RTS, SENDING_RTS, WAITING_CTS, LOADING_DATA, SENDING_DATA, WAITING_ACK, LOADING_CTS, SENDING_CTS, WAITING_DATA, LOADING_ACK, SENDING_ACK);
	TYPE smac_state_t IS
	RECORD
		state: state_t;
		
		status: STD_LOGIC_VECTOR(2 DOWNTO 0);
		sync_sent: STD_LOGIC_VECTOR(3 DOWNTO 0);
		
		timer1_reset: STD_LOGIC;
		timer1_t_in: STD_LOGIC_VECTOR(15 DOWNTO 0);
		
		timer2_reset: STD_LOGIC;
		timer2_t_in: STD_LOGIC_VECTOR(15 DOWNTO 0);
		
		timer3_reset: STD_LOGIC;
		timer3_t_in: STD_LOGIC_VECTOR(15 DOWNTO 0);
		
		random_num_reset: STD_LOGIC;
		
		app_tx_done: STD_LOGIC;
		app_rx_src: STD_LOGIC_VECTOR(15 DOWNTO 0);
		app_rx_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
		app_rx_done: STD_LOGIC;
		
		tx_reset: STD_LOGIC;
		tx_load: STD_LOGIC;
		tx_send: STD_LOGIC;
		tx_packet_type: STD_LOGIC_VECTOR(7 DOWNTO 0);
		tx_packet_src: STD_LOGIC_VECTOR(15 DOWNTO 0);
		tx_packet_dst: STD_LOGIC_VECTOR(15 DOWNTO 0);
		tx_packet_dur: STD_LOGIC_VECTOR(15 DOWNTO 0);
		tx_packet_seq: STD_LOGIC_VECTOR(7 DOWNTO 0);
		tx_packet_sleeptime: STD_LOGIC_VECTOR(15 DOWNTO 0);
		tx_packet_payload_len: STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		rx_reset: STD_LOGIC;
		rx_receive: STD_LOGIC;
		rx_store: STD_LOGIC;
		
		phy_enable: STD_LOGIC;
	END RECORD;
	
	SIGNAL smac_state, smac_state_next: smac_state_t;
	
BEGIN
	fsm_clk: PROCESS (clk, reset) IS
	BEGIN
		IF reset = '1' THEN
			smac_state.state <= IDLE;
			
			smac_state.status <= "000";
			smac_state.sync_sent <= (OTHERS => '0');
			
			smac_state.timer1_reset <= '1';
			smac_state.timer1_t_in <= (OTHERS => '0');
			
			smac_state.timer2_reset <= '1';
			smac_state.timer2_t_in <= (OTHERS => '0');
			
			smac_state.timer3_reset <= '1';
			smac_state.timer3_t_in <= (OTHERS => '0');
			
			smac_state.random_num_reset <= '1';
			
			smac_state.app_tx_done <= '0';
			smac_state.app_rx_src <= (OTHERS => '0');
			smac_state.app_rx_len <= (OTHERS => '0');
			smac_state.app_rx_done <= '0';
			
			smac_state.tx_reset <= '1';
			smac_state.tx_load <= '0';
			smac_state.tx_send <= '0';
			smac_state.tx_packet_type <= (OTHERS => '0');
			smac_state.tx_packet_src <= (OTHERS => '0');
			smac_state.tx_packet_dst <= (OTHERS => '0');
			smac_state.tx_packet_dur <= (OTHERS => '0');
			smac_state.tx_packet_seq <= (OTHERS => '0');
			smac_state.tx_packet_sleeptime <= (OTHERS => '0');
			smac_state.tx_packet_payload_len <= (OTHERS => '0');
			
			smac_state.rx_reset <= '1';
			smac_state.rx_receive <= '0';
			smac_state.rx_store <= '0';
			
			smac_state.phy_enable <= '0';
		ELSE
			IF RISING_EDGE(clk) THEN
				smac_state <= smac_state_next;
			END IF;
		END IF;
	END PROCESS;

	fsm: PROCESS(smac_state, node_address, timer1_t_out, timer1_timeout, timer2_t_out, timer2_timeout, timer3_t_out, timer3_timeout, app_tx_send, app_tx_dst, app_tx_len, rx_ready, rx_error, rx_packet_type, rx_packet_src, rx_packet_dst, rx_packet_dur, rx_packet_seq, rx_packet_sleeptime, rx_packet_payload_len, phy_rx_active) IS
	BEGIN
		smac_state_next <= smac_state;
		
		CASE smac_state.state IS
		
		WHEN IDLE =>
			-- Power on RF
			smac_state_next.phy_enable <= '1';
			-- Reset RNG
			smac_state_next.random_num_reset <= '1';
			-- Reset sync sent counter
			smac_state_next.sync_sent <= (OTHERS => '0');
			-- Set T1 = RFsetup
			smac_state_next.timer1_reset <= '1';
			smac_state_next.timer1_t_in <= RFSETUP;
			-- Go to WAITING_INTRO
			smac_state_next.state <= WAITING_INTRO;
			
			smac_state_next.status <= "000";
			
		WHEN WAITING_INTRO =>
			-- Start T1
			smac_state_next.timer1_reset <= '0';
			-- On T1 timeout prepare for intro
			IF timer1_timeout = '1' THEN
				-- Reset receiver
				smac_state_next.rx_reset <= '1';
				smac_state_next.rx_receive <= '0';
				-- Set T1 = Tasync + Tadata + Tsleep
				smac_state_next.timer1_reset <= '1';
				smac_state_next.timer1_t_in <= TASYNC + TADATA + TSLEEP;
				-- Go to state INTRO
				smac_state_next.state <= INTRO;
			END IF;
			
			smac_state_next.status <= "000";
			
		WHEN INTRO =>			
			-- Start T1
			smac_state_next.timer1_reset <= '0';
			-- Start receiver
			smac_state_next.rx_reset <= '0';
			smac_state_next.rx_receive <= '0';
			-- Start RNG
			smac_state_next.random_num_reset <= '0';
			-- On ERROR reset receiver
			IF rx_error = '1' THEN
				smac_state_next.rx_reset <= '1';
			-- On T1 timeout prepare for sleep
			ELSIF timer1_timeout = '1' THEN
				-- Set T1 = Tsleep
				smac_state_next.timer1_reset <= '1';
				smac_state_next.timer1_t_in <= TSLEEP;
				-- Power off RF
				smac_state_next.phy_enable <= '0';
				-- Reset receiver
				smac_state_next.rx_reset <= '1';
				-- Reset transmitter
				smac_state_next.tx_reset <= '1';
				-- Goto state SLEEP
				smac_state_next.state <= SLEEP;
			-- On RX done check packet type
			ELSIF rx_ready = '1' THEN
				-- Start receiver
				smac_state_next.rx_receive <= '1';
				-- Check if packet type is SYNC
				IF rx_packet_type = SYNC THEN
					-- Set T1 = Sleep time
					smac_state_next.timer1_reset <= '1';
					smac_state_next.timer1_t_in <= rx_packet_sleeptime;
					-- Reset receiver
					smac_state_next.rx_reset <= '1';
				END IF;
			END IF;
			
			smac_state_next.status <= "001";
			
		WHEN SLEEP =>
			-- Start T1
			smac_state_next.timer1_reset <= '0';
			-- On T1 timeout prepare for waiting active sync
			IF timer1_timeout = '1' THEN
				-- Power on RF
				smac_state_next.phy_enable <= '1';				
				-- Check sync sent counter
				IF smac_state.sync_sent = "1000" THEN
					-- Set T1 = RFsetup + Random time
					smac_state_next.timer1_reset <= '1';
					smac_state_next.timer1_t_in <= RFSETUP + random_num(9 DOWNTO 0); 	-- RNG period problem
					-- Reset sync sent counter
					smac_state_next.sync_sent <= (OTHERS => '0');			
					-- Go to WAITING_INTRO
					smac_state_next.state <= WAITING_INTRO;
				ELSE
					-- Set T1 = RFsetup
					smac_state_next.timer1_reset <= '1';
					smac_state_next.timer1_t_in <= RFSETUP;
					-- Go to WAITING_ACTIVE_SYNC
					smac_state_next.state <= WAITING_ACTIVE_SYNC;
				END IF;				
			END IF;
			
			smac_state_next.status <= "000";
			
		WHEN WAITING_ACTIVE_SYNC =>
			-- Start T1
			smac_state_next.timer1_reset <= '0';
			-- On T1 timeout prepare for active sync
			IF timer1_timeout = '1' THEN
				-- Reset receiver
				smac_state_next.rx_reset <= '1';
				smac_state_next.rx_receive <= '0';				
				-- Set T1 = Tasync + Tadata
				smac_state_next.timer1_reset <= '1';
				smac_state_next.timer1_t_in <= TASYNC + TADATA;
				-- Set T2 = Tasync
				smac_state_next.timer2_reset <= '1';
				smac_state_next.timer2_t_in <= TASYNC;
				-- Set T3 = DIFS + Random backoff
				smac_state_next.timer3_reset <= '1';
				IF random_num(4 DOWNTO 0) = "00000" THEN
					smac_state_next.timer3_t_in <= DIFS + 2;
				ELSE
					smac_state_next.timer3_t_in <= DIFS + ("0000000000" & random_num(4 DOWNTO 0) & "0");
				END IF;
				-- Go to ACTIVE_SYNC
				smac_state_next.state <= ACTIVE_SYNC;
			END IF;
			
			smac_state_next.status <= "010";
			
		WHEN ACTIVE_SYNC =>
			-- Prepare receiver
			smac_state_next.rx_reset <= '0';
			smac_state_next.rx_receive <= '0';
			-- Prepare sender
			smac_state_next.tx_reset <= '0';
			smac_state_next.tx_load <= '0';
			smac_state_next.tx_send <= '0';
			-- Start T1
			smac_state_next.timer1_reset <= '0';
			-- Start T2
			smac_state_next.timer2_reset <= '0';
			-- Start T3
			smac_state_next.timer3_reset <= '0';
			-- On ERROR stop T3 and reset receiver
			IF rx_error = '1' THEN
				-- Stop T3
				smac_state_next.timer3_reset <= '1';
				smac_state_next.timer3_t_in <= TIMEROFF;
				-- Reset receiver
				smac_state_next.rx_reset <= '1';
			-- On RF activity stop T3
			ELSIF phy_rx_active = '1' THEN
				-- Stop T3
				smac_state_next.timer3_reset <= '1';
				smac_state_next.timer3_t_in <= TIMEROFF;
			-- On RX done check packet type
			ELSIF rx_ready = '1' THEN
				-- Start receiver
				smac_state_next.rx_receive <= '1';
				-- Check if packet type is SYNC
				IF rx_packet_type = SYNC THEN
					-- Stop T3
					smac_state_next.timer3_reset <= '1';
					smac_state_next.timer3_t_in <= TIMEROFF;
					-- Set T1 = Sleep time
					smac_state_next.timer1_reset <= '1';
					smac_state_next.timer1_t_in <= rx_packet_sleeptime;
					-- Reset receiver
					smac_state_next.rx_reset <= '1';
					-- Reset sync sent counter
					smac_state_next.sync_sent <= (OTHERS => '0');
				END IF;
			-- On T2 timeout prepare for active data
			ELSIF timer2_timeout = '1' THEN
				-- Stop T2
				smac_state_next.timer2_reset <= '1';
				smac_state_next.timer2_t_in <= TIMEROFF;
				-- Stop T3
				smac_state_next.timer3_reset <= '1';
				smac_state_next.timer3_t_in <= TIMEROFF;
				-- Go to ACTIVE_DATA
				smac_state_next.state <= ACTIVE_DATA;
			-- On T3 prepare for loading sync
			ELSIF timer3_timeout = '1' THEN
				-- Stop T3
				smac_state_next.timer3_reset <= '1';
				smac_state_next.timer3_t_in <= TIMEROFF;
				-- Load SYNC
				smac_state_next.tx_load <= '1';
				smac_state_next.tx_packet_type <= SYNC;
				smac_state_next.tx_packet_src <= node_address;
				smac_state_next.tx_packet_seq <= (OTHERS => '0');		-- not implemented
				smac_state_next.tx_packet_sleeptime <= timer1_t_out - SYNC_DELAY;
				-- Increment sync sent counter
				smac_state_next.sync_sent <= smac_state.sync_sent + 1;
				-- Go to LOADING_SYNC
				smac_state_next.state <= LOADING_SYNC;
			END IF;
						
			smac_state_next.status <= "010";
			
		WHEN LOADING_SYNC =>
			-- Finish loading
			smac_state_next.tx_load <= '0';
			
			-- On loading done go to SENDING_SYNC
			IF tx_ready = '1' THEN
				smac_state_next.state <= SENDING_SYNC;
			END IF;
			
			smac_state_next.status <= "010";
			
		WHEN SENDING_SYNC =>			
			-- On TX ready send packet and go to ACTIVE_SYNC
			IF tx_ready = '1' THEN
				smac_state_next.tx_send <= '1';
				smac_state_next.state <= ACTIVE_SYNC;
			END IF;
			
			smac_state_next.status <= "010";
						
		WHEN ACTIVE_DATA =>
			-- Prepare receiver
			smac_state_next.rx_reset <= '0';
			smac_state_next.rx_receive <= '0';
			-- Prepare sender
			smac_state_next.tx_reset <= '0';
			smac_state_next.tx_load <= '0';
			smac_state_next.tx_send <= '0';			
			-- Start T1
			smac_state_next.timer1_reset <= '0';
			-- On T1 timeout prepare for sleep
			IF timer1_timeout = '1' THEN
				-- Set T1 = Tsleep
				smac_state_next.timer1_reset <= '1';
				smac_state_next.timer1_t_in <= TSLEEP;
				-- Power off RF
				smac_state_next.phy_enable <= '0';
				-- Go to SLEEP
				smac_state_next.state <= SLEEP;
			-- On ERROR reset receiver
			ELSIF rx_error = '1' THEN
				-- Reset receiver
				smac_state_next.rx_reset <= '1';
			-- On RX done check packet type
			ELSIF rx_ready = '1' THEN
				-- Start receiver
				smac_state_next.rx_receive <= '1';
				-- Check if packet type is CTS
				IF rx_packet_type = CTS THEN
					-- Set T2 = DUR
					smac_state_next.timer2_reset <= '1';
					smac_state_next.timer2_t_in <= rx_packet_dur;
					-- Power off RF
					smac_state_next.phy_enable <= '0';
					-- Go to SLEEP_NAV
					smac_state_next.state <= SLEEP_NAV;
				-- Check if packet type is RTS
				ELSIF rx_packet_type = RTS THEN
					-- Check if packet is destined to me
					IF rx_packet_dst = node_address THEN
						-- Set T2 = DUR
						smac_state_next.timer2_reset <= '1';
						smac_state_next.timer2_t_in <= rx_packet_dur;
						-- Set T3 = SIFS
						smac_state_next.timer3_reset <= '1';
						smac_state_next.timer3_t_in <= SIFS;
						-- Load CTS
						smac_state_next.tx_load <= '1';
						smac_state_next.tx_packet_type <= CTS;
						smac_state_next.tx_packet_src <= node_address;
						smac_state_next.tx_packet_dst <= rx_packet_src;
						smac_state_next.tx_packet_dur <= rx_packet_dur - SIFS - CTS_DELAY;
						smac_state_next.tx_packet_seq <= (OTHERS => '0');		-- not implemented
						-- Go to LOADING_CTS
						smac_state_next.state <= LOADING_CTS;
					ELSE
						-- Set T2 = DUR
						smac_state_next.timer2_reset <= '1';
						smac_state_next.timer2_t_in <= rx_packet_dur;
						-- Power off RF
						smac_state_next.phy_enable <= '0';
						-- Go to SLEEP_NAV
						smac_state_next.state <= SLEEP_NAV;
					END IF;
				END IF;
			-- On Data prepare for backoff
			ELSIF app_tx_send = '1' THEN
				-- Set T3 = DIFS + Random backoff
				smac_state_next.timer3_reset <= '1';
				IF random_num(4 DOWNTO 0) = "00000" THEN
					smac_state_next.timer3_t_in <= DIFS + 2;
				ELSE
					smac_state_next.timer3_t_in <= DIFS + ("0000000000" & random_num(4 DOWNTO 0) & "0");
				END IF;
				-- Go to BACKOFF
				smac_state_next.state <= BACKOFF;
			END IF;
			
			smac_state_next.status <= "100";
		
		WHEN SLEEP_NAV =>
			-- Start T2
			smac_state_next.timer2_reset <= '0';
			-- On T2 timeout go to active data
			IF timer2_timeout = '1' THEN
				-- Go to ACTIVE_DATA
				smac_state_next.state <= ACTIVE_DATA;
			END IF;
			
		WHEN BACKOFF =>
	
		WHEN LOADING_RTS => 
		
		WHEN SENDING_RTS =>
		
		WHEN WAITING_CTS =>
		
		WHEN LOADING_DATA =>
		
		WHEN SENDING_DATA =>
		
		WHEN WAITING_ACK =>
		
		WHEN LOADING_CTS => 
		
		WHEN SENDING_CTS =>
		
		WHEN WAITING_DATA =>
		
		WHEN LOADING_ACK => 
		
		WHEN SENDING_ACK =>
			
		END CASE;
		
	END PROCESS;

	fsm_output: PROCESS (smac_state) IS
	BEGIN	
		status <= smac_state.status;
		
		timer1_reset <= smac_state.timer1_reset;
		timer1_t_in <= smac_state.timer1_t_in;
		
		timer2_reset <= smac_state.timer2_reset;
		timer2_t_in <= smac_state.timer2_t_in;
		
		timer3_reset <= smac_state.timer3_reset;
		timer3_t_in <= smac_state.timer3_t_in;
		
		random_num_reset <= smac_state.random_num_reset;
		
		app_tx_done <= smac_state.app_tx_done;
		app_rx_src <= smac_state.app_rx_src;
		app_rx_len <= smac_state.app_rx_len;
		app_rx_done <= smac_state.app_rx_done;
		
		tx_reset <= smac_state.tx_reset;
		tx_load <= smac_state.tx_load;
		tx_send <= smac_state.tx_send;
		tx_packet_type <= smac_state.tx_packet_type;
		tx_packet_src <= smac_state.tx_packet_src;
		tx_packet_dst <= smac_state.tx_packet_dst;
		tx_packet_dur <= smac_state.tx_packet_dur;
		tx_packet_seq <= smac_state.tx_packet_seq;
		tx_packet_sleeptime <= smac_state.tx_packet_sleeptime;
		tx_packet_payload_len <= smac_state.tx_packet_payload_len;
		
		rx_reset <= smac_state.rx_reset;
		rx_receive <= smac_state.rx_receive;
		rx_store <= smac_state.rx_store;
		
		phy_enable <= smac_state.phy_enable;
	END PROCESS;	
END arch_smac_controller;