LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timer IS
	PORT ( clk: IN STD_LOGIC;
			 ena: IN STD_LOGIC;
			 reset: IN STD_LOGIC;
			 t_in: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			 t_out: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			 timeout: OUT STD_LOGIC );
END timer;

ARCHITECTURE arch_timer OF timer IS
CONSTANT TIMEROFF: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(65535,16));
CONSTANT TIMEREXP: STD_LOGIC_VECTOR(15 DOWNTO 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(0,16));
SIGNAL t: STD_LOGIC_VECTOR(15 DOWNTO 0);

BEGIN
	PROCESS (clk, ena, reset, t_in)
	BEGIN
		IF reset = '1' THEN
			t <= t_in;
			t_out <= t_in;
			timeout <= '0';
		ELSIF RISING_EDGE(clk) THEN
			IF t = TIMEREXP THEN
				t_out <= t;
				timeout <= '1';
			ELSIF t = TIMEROFF THEN
				t_out <= t;
				timeout <= '0';
			ELSIF ena = '1' THEN
				t <= t - 1;
				t_out <= t;
				timeout <= '0';
			ELSE
				t_out <= t;
				timeout <= '0';
			END IF;
		END IF;
	END PROCESS;
END arch_timer;