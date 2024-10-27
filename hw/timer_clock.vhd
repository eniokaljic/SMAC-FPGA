LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY timer_clock IS
	PORT ( clk: IN STD_LOGIC;
			 reset: IN STD_LOGIC;
			 ena: OUT STD_LOGIC );
END timer_clock;

ARCHITECTURE arch_timer_clock OF timer_clock IS
SIGNAL clock: STD_LOGIC_VECTOR(19 DOWNTO 0);

BEGIN
	PROCESS (clk, reset) IS
	BEGIN
		IF reset = '1' THEN
			clock <= STD_LOGIC_VECTOR(TO_UNSIGNED(499999, 20));
			ena <= '0';
		ELSIF RISING_EDGE(clk) THEN
			IF clock(clock'HIGH) = '1' THEN
				clock <= STD_LOGIC_VECTOR(TO_UNSIGNED(499999, 20));
				ena <= '1';
			ELSE
				clock <= clock - 1;
				ena <= '0';
			END IF;
		END IF;
	END PROCESS;
END arch_timer_clock;