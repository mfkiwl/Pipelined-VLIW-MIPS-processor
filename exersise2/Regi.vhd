
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity regi is
   generic (N :NATURAL);
   Port ( Data_in : in  STD_LOGIC_VECTOR (N-1 downto 0);
           data_out : out  STD_LOGIC_VECTOR (N-1 downto 0);
           clock : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           write_enable : in  STD_LOGIC);--remove this if not needed
	end regi;

architecture Behavioral of regi is
	signal data: STD_LOGIC_VECTOR (N-1 downto 0);
	--constant resetstate   : std_logic_vector(0 to N-1) := "0000000000000000000000000000000000000000000000000000000000000000";

	begin

	-- For each clock_cycle when write_enable is 1, the contents of the PC, represented by the signal data,
	-- will be updated with output from Incrementation, Branching or Jump
	REGIST : process(clock, reset,data)
	begin
	
	--	if(reset='1') then
			--	data<=resetstate;
		if(rising_edge(clock)) then
		--	if(write_enable='1')then
				data<=data_in;
	--		end if;
		end if;
	 end process;
 
	data_out<=data;


end Behavioral;
