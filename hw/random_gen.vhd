LIBRARY IEEE;
LIBRARY ALTERA;
USE IEEE.STD_LOGIC_1164.ALL;
USE ALTERA.ALL;

ENTITY random_gen IS
	PORT ( clk : IN STD_LOGIC;
			 reset: IN STD_LOGIC;
			 random_num : OUT STD_LOGIC_VECTOR(23 DOWNTO 0) );
END random_gen;

ARCHITECTURE arch_random_gen OF random_gen IS
	SIGNAL x1, x2, x3: STD_LOGIC;
	SIGNAL rand_temp: STD_LOGIC_VECTOR(23 DOWNTO 0);
	COMPONENT LCELL 
		PORT (a_in : IN STD_LOGIC; 
				a_out : OUT STD_LOGIC); 
	END COMPONENT;
BEGIN
	-- Ring oscillator 1
	lcell_inst1: LCELL
	PORT MAP ( a_in => NOT(x1), a_out => x1);
	-- Ring oscillator 2
	lcell_inst2: LCELL
	PORT MAP ( a_in => NOT(x2), a_out => x2);
	-- Ring oscillator 3
	lcell_inst3: LCELL
	PORT MAP ( a_in => NOT(x3), a_out => x3);
	
	-- Sampler with shift register
	PROCESS (clk)
	BEGIN
		IF reset = '1' THEN
			rand_temp(23 DOWNTO 1) <= (OTHERS => '0');
			rand_temp(0) <= '1';
		ELSIF RISING_EDGE(clk) THEN
			rand_temp <= rand_temp(22 DOWNTO 0) & (x1 XOR x2 XOR x3);
		END IF;
	random_num <= rand_temp;
	END PROCESS;
END arch_random_gen;
