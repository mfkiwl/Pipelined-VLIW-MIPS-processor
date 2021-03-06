library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use WORK.MIPS_CONSTANT_PKG.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


--TODO ADD PIPELINESTAGE FOR THE FORWARDING AND THE ALUOP UNITS
entity PROCESSOR is
 generic ( MEM_ADDR_BUS: natural := 32; MEM_DATA_BUS : natural := 32);
	Port ( 
		clk : in STD_LOGIC;
		reset					: in STD_LOGIC;
		processor_enable	: in  STD_LOGIC;
		imem_address 		: out  STD_LOGIC_VECTOR (MEM_ADDR_BUS-1 downto 0);
		imem_address2 		: out  STD_LOGIC_VECTOR (MEM_ADDR_BUS-1 downto 0);
		imem_data_in 		: in  STD_LOGIC_VECTOR (MEM_DATA_BUS-1 downto 0);
		imem_data2_in 		: in  STD_LOGIC_VECTOR (MEM_DATA_BUS-1 downto 0);
		dmem_data_in 		: in  STD_LOGIC_VECTOR (MEM_DATA_BUS-1 downto 0);
		dmem_address 		: out  STD_LOGIC_VECTOR (MEM_ADDR_BUS-1 downto 0);
		dmem_address_wr	: out  STD_LOGIC_VECTOR (MEM_ADDR_BUS-1 downto 0);
		dmem_data_out		: out  STD_LOGIC_VECTOR (MEM_DATA_BUS-1 downto 0);
		dmem_write_enable	: out  STD_LOGIC
	);
end PROCESSOR;

architecture Behavioral of PROCESSOR is

	--component declarations
	component controlpath is
    Port ( PC_OUTPUT : in  STD_LOGIC_VECTOR (31 downto 0);
           Signextended : in  STD_LOGIC_VECTOR (31 downto 0);
           Instr_Mem_Concat : in  STD_LOGIC_VECTOR (25 downto 0);
           FinalPCAddress : out  STD_LOGIC_VECTOR (31 downto 0);
           jump : in  STD_LOGIC;
			  branch: in std_logic;
			  zero: in std_logic);
	end component controlpath;
	component Vliw_multipliercontrol is
    Port ( IFID_funct : in  STD_LOGIC_VECTOR (5 downto 0);
           LO_write : out  STD_LOGIC;
           Vliw_aluOP: out std_logic
           );
end component Vliw_multipliercontrol;
	
	component shift_register is
   Port ( data_in : in  STD_LOGIC;
           data_out : out  STD_LOGIC_VECTOR (1 downto 0);--2 bits index + branch instruction address forms index for prediction register
           clock : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           write_enable : in  STD_LOGIC);--remove this if not needed
end component shift_register;

	component QuadputMux is
    Port ( A : in  STD_LOGIC_VECTOR (31 downto 0);
           B : in  STD_LOGIC_VECTOR (31 downto 0);
           C : in  STD_LOGIC_VECTOR (31 downto 0);
           D : in  STD_LOGIC_VECTOR (31 downto 0);
           R : out  STD_LOGIC_VECTOR (31 downto 0);
           control : in  STD_LOGIC_VECTOR (1 downto 0));
end component QuadputMux;
	
	
	component Hazarddetection is
    Port ( IDEXCONTROL : in  STD_LOGIC_VECTOR(8 downto 0);
           IDEXregisterRT : in  STD_LOGIC_VECTOR(4 downto 0);
			  IFIDregisterRS : in  STD_LOGIC_VECTOR(4 downto 0);
			  IFIDregisterRT : in  STD_LOGIC_VECTOR(4 downto 0);
			  IFIDInstructionType: in  STD_LOGIC_VECTOR (5 downto 0);
           PCWrite : out  STD_LOGIC;
			  IFIDwrite: out STD_LOGIC;
			  IFIDreset: out STD_LOGIC;--remove this maybe?
			  processor_enable: in std_logic;
           Controlenable : out  STD_LOGIC

			  );
end component Hazarddetection;
--	component Hazarddetection is
--    Port ( IDEXCONTROL : in  STD_LOGIC_VECTOR(8 downto 0);
--           IDEXregisterRT : in  STD_LOGIC_VECTOR(31 downto 0);
--			  IFIDInstructionType: in  STD_LOGIC_VECTOR (5 downto 0);
--          PCWrite : out  STD_LOGIC;
--			  IFIDwrite: out STD_LOGIC;
--			  IFIDreset: out STD_LOGIC;--syncronous reset for god's sake
--			  processor_enable: in std_logic;
 --         Controlenable : out  STD_LOGIC;
--			  State: out std_logic_vector(1 downto 0);
--			  State_in: in std_logic_vector(1 downto 0);
--			  IFID_state_in: in std_logic_vector(1 downto 0);
--			  buffer_write: out std_logic;
--			 -- branch: in std_logic_vector(1 downto 0);
--			  branch_ok:out std_logic;
--			  revert:out std_logic;
--			  IFIDbranch_taken: in std_logic;
--			  branch_taken: out std_logic;
--			  branched1: in std_logic;
--			  --equalvals2: in std_logic_vector(31 downto 0);
--			  predicted_address: in std_logic_vector(15 downto 0);
--			  shift_register_write: out std_logic;
--			  branch_address: in std_logic_vector(15 downto 0)
--			  );
--	end component Hazarddetection;
	
	
	component branchprediction is
    Port ( 
				IFIDInstructionType: in std_logic_vector(5 downto 0);
			  IFIDreset: out STD_LOGIC;--syncronous reset for ifid register. Must be done when a branch prediction fails in order to prevent the wrong instructions to be executed
			  State: out std_logic_vector(1 downto 0); --the incremented state to be written back to the local branch prediction buffer (ID stage).
			  State_in: in std_logic_vector(1 downto 0);-- the information from the local branch prediction buffer. (IF stage)
			  IFID_state_in: in std_logic_vector(1 downto 0);	--the information from the local branch prediction buffer.(ID stage) 
			  buffer_write: out std_logic;	--signal that allow writes to all the prediction buffers
			  branch_ok:out std_logic; --signal to allow the calculated branch address to the PC register
			  revert:out std_logic;-- signal that allows reverting a faulty branchprediction
			  IFIDbranch_taken: in std_logic;--branch_taken signal in the ID stage
			  branch_taken: out std_logic;--signals the a mux wheter a branchprediction should be taken or not. Signal is determined in IF stage
			  branched1: in std_logic; --tells wheter a branch (not the prediction) is actually taken or not
			  predicted_address: in std_logic_vector(15 downto 0);--this is the predicted address, it must be tested if its the actual right branchaddress
			  shift_register_write: out std_logic; --this allow write to the shiftregister where the global branch information is stored. The input is 1 bit indicating wheter a branch (not prediction) actually is taken or not.
			  branch_address: in std_logic_vector(15 downto 0)--this is the actual branch address 
			  );
end component branchprediction;
	
		component predictorbuffer is
    generic (N :NATURAL :=16; M:NATURAL:=32; K:NATURAL:=4);
	port(
			CLK 			:	in	STD_LOGIC;				
			RESET			:	in	STD_LOGIC;				
			RW				:	in	STD_LOGIC;				
			Read_address:	in	STD_LOGIC_VECTOR (K downto 0); 
			Write_address:	in	STD_LOGIC_VECTOR (K downto 0);
			WRITE_DATA	:	in	STD_LOGIC_VECTOR (N-1 downto 0); 
			Data_out		:	out	STD_LOGIC_VECTOR (N-1 downto 0)
	);
	end component predictorbuffer;


	component ALUOperation is
    Port ( ALUOp0 : in  STD_LOGIC;
           ALUOp1 : in  STD_LOGIC;
           funct : in  STD_LOGIC_VECTOR (5 downto 0);
           operation : out  STD_LOGIC_VECTOR (4 downto 0);
                          memtoreg2: out std_logic;
                          memtoreg: out std_logic
                          );
	end component ALUOperation;
	
		component adder is
		generic (N :NATURAL :=32);  
		port(
			X	: in	STD_LOGIC_VECTOR(N-1 downto 0);
			Y	: in	STD_LOGIC_VECTOR(N-1 downto 0);
			COUT	: out	STD_LOGIC;
			R	: out	STD_LOGIC_VECTOR(N-1 downto 0));
	end component adder;
	component TriputMux is
    Port ( A : in  STD_LOGIC_VECTOR (31 downto 0);
           B : in  STD_LOGIC_VECTOR (31 downto 0);
           C : in  STD_LOGIC_VECTOR (31 downto 0);
           R : out  STD_LOGIC_VECTOR (31 downto 0);
           control : in  STD_LOGIC_VECTOR (1 downto 0));
end component TriputMux;

	component REGISTER_FILE is
	port(
			CLK 			:	in	STD_LOGIC;				
			RESET			:	in	STD_LOGIC;				
			RW				:	in	STD_LOGIC;				
			RS_ADDR 		:	in	STD_LOGIC_VECTOR (RADDR_BUS-1 downto 0); 
			RT_ADDR 		:	in	STD_LOGIC_VECTOR (RADDR_BUS-1 downto 0); 
			RD_ADDR 		:	in	STD_LOGIC_VECTOR (RADDR_BUS-1 downto 0);
			WRITE_DATA	:	in	STD_LOGIC_VECTOR (31 downto 0); 
			RS				:	out	STD_LOGIC_VECTOR (31 downto 0);
			RT				:	out	STD_LOGIC_VECTOR (31 downto 0);
			RS_ADDR2 		:	in	STD_LOGIC_VECTOR (RADDR_BUS-1 downto 0); 
			RT_ADDR2		:	in	STD_LOGIC_VECTOR (RADDR_BUS-1 downto 0); 
			RS2			:	out	STD_LOGIC_VECTOR (31 downto 0);
			RT2				:	out	STD_LOGIC_VECTOR (31 downto 0)
	);
	end component REGISTER_FILE;
	
	component Regi is
	generic(N : natural :=32);
   port ( Data_in : in  STD_LOGIC_VECTOR (N-1 downto 0);
           data_out : out  STD_LOGIC_VECTOR (N-1 downto 0);
           clock : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           write_enable : in  STD_LOGIC);--remove this if not needed
	end component regi;
	
	component alu is
				generic (N :NATURAL :=DDATA_BUS);
		port(
			X			: in STD_LOGIC_VECTOR(N-1 downto 0);
			Y			: in STD_LOGIC_VECTOR(N-1 downto 0);
			ALU_IN	: in ALU_INPUT;
			R			: out STD_LOGIC_VECTOR(N-1 downto 0);
			FLAGS		: out ALU_FLAGS
		);
	end component alu;
	
	component Vliw_alu is
	generic (N :NATURAL :=32);
        port(
                X                        : in STD_LOGIC_VECTOR(N-1 downto 0);
                Y                        : in STD_LOGIC_VECTOR(N-1 downto 0);
                R_LO                        : out STD_LOGIC_VECTOR(N-1 downto 0);
					 R_HI								: out std_logic_vector(N-1 downto 0);
                vliw_aluOP                : in std_logic
        );
end component Vliw_alu;
	component PC is
	    Port ( Data_in : in  STD_LOGIC_VECTOR (31 downto 0);
           data_out : out  STD_LOGIC_VECTOR (31 downto 0);
           clock : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           write_enable : in  STD_LOGIC);
	end component PC;
	
	component simple_multiplexer is
	generic (N :NATURAL :=32);
	    Port ( a : in  STD_LOGIC_VECTOR (N-1 downto 0);
           b : in  STD_LOGIC_VECTOR (N-1 downto 0);
           control_signal : in  STD_LOGIC;
           output : out  STD_LOGIC_VECTOR (N-1 downto 0));
	
	end component simple_multiplexer;
	
	component control is
    Port ( control_input : in  STD_LOGIC_VECTOR (5 downto 0);
           Ops : out STD_LOGIC_VECTOR (9 downto 0);
              clk: in std_logic;
              reset: in std_logic
              );
	end component control;
	
	component Forwarding is
    Port ( ExmemregisterRD : in  STD_LOGIC_VECTOR (4 downto 0);
           MEMWbregisterRD : in  STD_LOGIC_VECTOR (4 downto 0);
			  MEMWBregwrite: in std_logic;
			  EXMEMregwrite: in std_logic;
           RS : in  STD_LOGIC_VECTOR (4 downto 0);
           RT : in  STD_LOGIC_VECTOR (4 downto 0);
           forwardA : out  STD_LOGIC_VECTOR (1 downto 0);
           forwardB  : out  STD_LOGIC_VECTOR (1 downto 0));
end component Forwarding;

	--Signal, categorized as signals FROM different components:

	--From PC
	signal PC_Output : STD_LOGIC_VECTOR (31 downto 0); --From PC to Instruction Memory + Control Circuit


	-- From Register
	signal Read_Data1 : STD_LOGIC_VECTOR (31 downto 0); -- Read data 1 from Register_File
	signal Read_Data2 : STD_LOGIC_VECTOR (31 downto 0); -- Read data 2 from Register_File


	-- From ALU
	signal ALU_Result : STD_LOGIC_VECTOR (31 downto 0); -- The ALU Result output from the ALU
	signal Zero : ALU_FLAGS; -- The Zero output from the ALU

	-- From instruction memory
	signal Signextended : STD_LOGIC_VECTOR (31 downto 0); -- Data output from Signextend

	-- From ALUControl
	signal ALUControl : ALU_INPUT; 

	--controlsignal for forwardingA
	signal ctForwardA: STD_LOGIC_VECTOR(1 downto 0);
		--controlsignal for forwardingB
	signal ctForwardB: STD_LOGIC_VECTOR(1 downto 0);
	
	--output from forwardA mux
	signal ForwardAout: std_logic_vector(31 downto 0);
	
	--output from forwardB mux
	signal ForwardBout: std_logic_vector(31 downto 0);
	-- From MUX1, Between Instruction Memory and Register File (input for Write Register)
	signal ChosenWriteReg : STD_LOGIC_VECTOR (4 downto 0);

	-- From MUX2 Between Register File/Sign Extend and ALU (ALU Input 2)
	signal ChosenALUInput : STD_LOGIC_VECTOR (31 downto 0);

	-- From MUX3 Between ALU/Data Memory and Instruction Memory (input for Write Data)
	signal ChosenWriteData : STD_LOGIC_VECTOR (31 downto 0);
	
	--input to PC register
	signal FinalPCAddress : STD_LOGIC_VECTOR (31 downto 0);

	--writenable signal from the controlunit
	signal enablepcwrite: std_logic;
	
		-- From Concat
	signal Concat : STD_LOGIC_VECTOR (31 downto 0); -- Data output from Concat
	--incremented PC signal to MUX
	signal incremented : STD_LOGIC_VECTOR (31 downto 0);
	--output from mux1
	signal mux1out: STD_LOGIC_VECTOR (31 downto 0);
	signal mux2out: STD_LOGIC_VECTOR (31 downto 0);
	signal branchcalc: STD_LOGIC_VECTOR (31 downto 0);
	
	
	-- Output signals from the controller.
	signal Ops : std_logic_vector (9 downto 0);
	-- They are divided into each signal to make the overview easier
	--signal jump : std_logic;
	--signal memwrite : std_logic;
	--signal regwrite : std_logic;
	signal memtoreg : std_logic;
	--signal alusrc : std_logic;
	--signal branch(1) : std_logic;
	--signal regdest : std_logic;
	--signal ALUOp : std_logic_vector(1 downto 0);
		--signal branch(0) : std_logic;
	--assigned to the alu operation. We dont use the enumeration in aluOP module because its easier for us to use a vector
	signal operation: std_logic_vector(4 downto 0);
	--branchadder
	signal BranchAdder : STD_LOGIC_VECTOR (31 downto 0);
	--IF/ID out
	signal IFIDs: std_logic_vector(119 downto 0);
	
	--ID/EX out
	signal IDEXs: std_logic_vector(260 downto 0);
	
	--EX/MEM out
	
	signal EXMEMs: std_logic_vector(209 downto 0);
	
	--mem/wb output
	signal MEMWBs: std_logic_vector(109 downto 0);
	
		--this signal is 1 if branch equal
	signal branch_ok: std_logic;
	
	--enables output from controlunit
	signal control_enable: std_logic;
	
	--chosen operation from the controloutputmux
	signal chosen_OP: std_logic_vector(9 downto 0);
	
	--flushsignals
	
	signal IFflush:std_logic;
	
	--controls write to IFID
	signal IFIDwrite:std_logic;
	signal IFIDreset: std_logic;

	
	--enables write to pcpointer register and the predictionbuffer
	--output from state in branchpredictor
	signal state_writeback:std_logic_vector(1 downto 0);
	signal stateread:std_logic_vector(1 downto 0);
	--output from the PCpointer
	--signal to write to the dynamic branchpred registers
	signal buffer_write: std_logic;
	
	--output for the muxt for the branchadress
	signal branch_out:std_logic_vector(31 downto 0);
	
	signal revert: std_logic;
	
	signal equalvals:std_logic_vector(31 downto 0);
	signal equalvals2:std_logic_vector(31 downto 0);
	
	signal branch_taken: std_logic;
	--signal stateread2:std_logic_vector(17 downto 0);
	
	signal prediction_address: std_logic_vector(15 downto 0);
	
	signal global_prediction_out: std_logic_vector(1 downto 0);
	
	signal shift_register_write: std_logic;
	signal branched1: std_logic;
	
	
	
	--for wliv datapath
	
		signal Signextended2 : STD_LOGIC_VECTOR (31 downto 0); -- Data output from Signextend2
		
	signal Read_Data_vliw1 : STD_LOGIC_VECTOR (31 downto 0); -- Read data 1 from Register_File
	signal Read_Data_vliw2 : STD_LOGIC_VECTOR (31 downto 0); -- Read data 2 from Register_File
	
	--input to LO register
	signal LO_IN : std_logic_vector(31 downto 0);
	--input to HI register
	signal HI_IN: std_logic_vector(31 downto 0);
	
	--controlsignal for mux3 (
	signal memtoreg2: std_logic;
	
	signal LO_out: std_logic_vector(31 downto 0);
	signal HI_out: std_logic_vector(31 downto 0);
	signal LO_write: std_logic;--change name
	signal Vliw_aluOP: std_logic;		
	begin
	--equalvals<=(IDEXs(105 downto 74) xor IDEXs(73 downto 42));
	--equalvals2<=read_data1 xor read_data2;--fix this

		branched1 <= '1' when ((read_data1=read_data2) and (chosen_OP(5)='1'))
	else '1' when (chosen_OP(9)='1') and not (read_data1=read_data2)
	else '0';
	--assign control signals
	--jump <= Ops(0); -- Jump
	--memwrite <= Ops(1);
	--regwrite <= Ops(2);
	--memtoreg <= Ops(3);
	--alusrc <= Ops(4);
	--branch equal <= Ops(5);
	--regdest <= Ops(6);
	--ALUOp(0) <= Ops(7);
--	ALUOp(1) <= Ops(8); -- ALUOp(1)
	--bne <= Ops(9);
	--if more non-R instructions are added, add more aluOP signals
	--Ops(3)<=memtoreg;--should be fixed
	--perform signextension
	Signextended(15 downto 0) <=IFIDs(103 downto 88);
	Signextended(31 downto 16) <= (31 downto 16 => IFIDs(103));

	Signextended2(15 downto 0) <=IFIDs(71 downto 56);
	Signextended2(31 downto 16) <= (31 downto 16 => IFIDs(71));
	--assignments for alu controlsignals
	ALUControl.op0<=operation(0 );
	ALUControl.op1<=operation(1 );
	ALUControl.op2<=operation(2);
	ALUControl.op3<=operation(3 );--check all these signals
	ALUControl.op4<=operation(4 );
	--if more alufunctions are needed, add more signals when needed
	
	--mapping out of processor
	imem_address<=PC_OUTPUT;
	imem_address2<=(PC_OUTPUT+1);--using adder built into library
	dmem_address<=EXMEMs(68 downto 37);--aluresult
	dmem_address_wr<=EXMEMs(68 downto 37);
	dmem_data_out<=EXMEMs(36 downto 5);--read_data2;
	dmem_write_enable<=EXMEMs(135);--memwrite;

	--PCPath: controlpath
    --Port map ( PC_OUTPUT => IDEXs(137 downto 106),
		--	  Signextended =>IDEXs(41 downto 10),
        --   Instr_Mem_Concat =>IFIDs(25 downto 0),--!!!!!!!
          -- FinalPCAddress =>FinalPCAddress,
  --         jump =>jump,
--			  branch=>branch,
	--		  zero=>zero.zero);
			  
	ALUOpModule : ALUOPERATION Port map ( 
				aluop0 =>IDEXs(151),--ALUOp(0)
           aluop1 =>IDEXs(152),--ALUOp(1),
           funct =>IDEXs(15 downto 10),--we dont need 5 signals in, so we ignore them
           operation =>operation,
			  memtoreg2=>memtoreg2,
			  memtoreg=>memtoreg
			  );


	ALUTD : ALU generic map ( N=>32)  port map(
			  X => ForwardAout,--IDEXs(105 downto 74),
			  Y => ChosenALUInput,
			  ALU_IN	=> ALUControl,
			  R => ALU_Result,
			  FLAGS => ZERO
	);
	
		PATH2_ALU: Vliw_alu
	port map(
		X			=>IDEXs(258 downto 227),
		Y			=>IDEXs(226 downto 195),
		R_LO			=>LO_IN ,
		R_HI			=>HI_IN,
		vliw_aluOP=>IDEXs(260)--vliw_aluOP
	);

	
	REGISTER_F: REGISTER_FILE port map(
			  CLK => clk,			
			  RESET => reset,		
			  RS => read_data1,				
			  RT => read_data2,--the dataoutput which also go to the mux
			  RW =>  MEMWBs(69),
		  	  RS_ADDR => IFIDs(113 downto 109), --addresses for the register datas
			  RT_ADDR => IFIDs(108 downto 104), --addresses for the register datas
			  RD_ADDR => MEMWBs(4 downto 0),--ChosenWriteReg,
			  RS2 => Read_Data_vliw1,--				
			  RT2 => Read_Data_vliw2,
			  RS_ADDR2 => IFIDs(81 downto 77), 
			  RT_ADDR2 => IFIDs(76 downto 72), 
			  WRITE_DATA => ChosenWriteData --expand this by 1
);
	
	--TODO move LO 1 stage back in pipeline
		LO: regi generic map ( N=>32) port map(
		 Data_in =>EXMEMs(170 downto 139),
           data_out => LO_out,
           clock => clk,
           reset => reset,
			  write_enable=>memwbs(109)
	);
	
			HI: regi generic map ( N=>32) port map(
		 Data_in =>EXMEMs(209 downto 178),--MEMWBs(102 downto 71),--change this. this is output for LO and not HI
           data_out => HI_out,
           clock => clk,
           reset => reset,
	write_enable=>memwbs(109)
	);	--265 calculated
	
	
		Vliwcore2: Vliw_multipliercontrol 
    Port map( IFID_funct =>IFIDs(61 downto 56),
           LO_write =>LO_write,
           Vliw_aluOP=>Vliw_aluOP
           );
--		REGISTER_F2: REGISTER_FILE port map(
--					  CLK => clk,			
--			  RESET => reset,	
--			RS => Read_Data_vliw1,--				
--			  RT => Read_Data_vliw2,
--			  RW =>  MEMWBs(69),--fix this later
--		  	  RS_ADDR => IFIDs(81 downto 77), 
--			  RT_ADDR => IFIDs(76 downto 72), 
--			  RD_ADDR => MEMWBs(107 downto 103),--dont have rd_adress
--			  WRITE_DATA => MEMWBs(102 downto 71)--fix this later... no mux
--	);
		
		
	COUNTER: PC port map(
	 Data_in => FinalPCAddress,
           data_out => PC_Output,
           clock => clk,
           reset => reset,
           write_enable =>enablepcwrite
	
	);--WLIW 87 DOWNTO 56
	IFID: regi generic map ( N=>120) port map(
		 Data_in =>imem_data_in&imem_data2_in& stateread& prediction_address&pc_output(4 downto 0)&branch_taken&incremented,--change incremented?
           data_out => IFIDs,
           clock => clk,
           reset => IFIDreset,
			  write_enable=>IFIDwrite
	);								--265 calculated
	IDEX: regi generic map (N=>261) port map(--remove the 1bit memtoreg signal
																						--rd_vliw/158				--IDEX_RS		--controlsignals(153-145)			--ifid instructiontype	--jumpaddress163 dt138		--incremented														--idex_rt					idex_rd
			 Data_in =>vliw_aluOP&LO_write&Read_Data_vliw1&Read_Data_vliw2&signextended2&IFIDs(71 downto 67)&IFIDs(113 downto 109)&chosen_OP(8 downto 4)&memtoreg&chosen_OP(2 downto 0)&IFIDs(119 downto 114)&IFIDs(31 downto 0)&read_data1&read_data2&Signextended&IFIDs(108 downto 104)&IFIDs(103 downto 99),--138+25, perform signex later?
           data_out => IDEXs,
           clock => clk,
           reset => reset,
			  write_enable=>'1'
	);								--was 178
	EXMEM: regi generic map (N=>210)  port map(
			--con trrrollls																				-branchsignal --controlsignals
			 Data_in => HI_IN&IDEXs(259)&memtoreg2&IDEXs(163 downto 159)&LO_IN &IDEXs(149)&memtoreg&IDEXs(146 downto 144)&concat&branchadder&zero.zero&ALU_Result&ForwardBout&ChosenWriteReg,--134, not 161 bit
           data_out => EXMEMs,
           clock => clk,
           reset => reset,
			  write_enable=>'1'
	);									--was 71
	--109?
	MEMWB: regi generic map (N=>110) port map(
	--con trrrolls	--lowrite		chosen_register for wliw			--wlivaluresult
			 Data_in =>EXMEMs(177)&EXMEMs(176)&EXMEMs(175 downto 171)&EXMEMs(170 downto 139)& EXMEMs(137)&EXMEMs(136)&dmem_data_in&EXMEMs(68 downto 37)&EXMEMs(4 downto 0),--
           data_out => MEMWBs,
           clock => clk,
           reset => reset,
			  write_enable=>'1'
	);
	
	Forwardunit: Forwarding
    Port map ( ExmemregisterRD =>EXMEMs(4 downto 0),
           MEMWbregisterRD =>MEMWBs(4 downto 0),
			  MEMWBregwrite=>MEMWBs(69),
			  EXMEMregwrite=>EXMEMs(136),--ops
           RS =>IDEXs(158 downto 154),--check this is not crisscorssed
           RT =>IDEXs(9 downto 5),--verify this, updated in commit
           forwardA =>ctForwardA,
           forwardB =>ctForwardB);
			  
	CONTROL_UNIT: CONTROL Port map(
			  control_input =>IFIDS(119 downto 114),
           Ops => Ops,
			  clk => clk,
			  reset=> reset);
			  
	DETECTION_UNIT: Hazarddetection
    Port map ( IDEXCONTROL=>IDEXs(153 downto 148)&memtoreg&IDEXs(146 downto 145),--figures out if operation in idex register is read
           IDEXregisterRT=>IDEXs(9 downto 5),--IDEXs(73 downto 42),--RT register
			  IFIDregisterRS=>IFIDs(113 downto 109),
			  IFIDregisterRT=>IFIDs(108 downto 104),
			  IFIDInstructionType=>IFIDs(119 downto 114),
           PCWrite =>enablepcwrite,--enable PC write
			  IFIDwrite=>IFIDwrite,
           Controlenable=>control_enable,
			  processor_enable=> processor_enable
			  
			  
			  );
			  
	Branch_predicition_unit: branchprediction
	port map(
				IFIDInstructionType=>IFIDs(119 downto 114),
				buffer_write=>buffer_write,
			  State_in=>stateread,
			  IFID_state_in=>IFIDs(55 downto 54),
			  State=>State_writeback,
			  IFIDreset=>IFIDreset,
			  branch_ok=>branch_ok,
			  IFIDbranch_taken=>IFIDs(32), 
			  branch_taken=>branch_taken,
			  revert=>revert,
			  branch_address=> BranchAdder(15 downto 0),
			  predicted_address=>IFIDs(53 downto 38),
			  shift_register_write=>shift_register_write,
			  branched1=>branched1
	
	);
			  
		--!!!!!	  
	Concat <= IFIDs(31 downto 26)&IFIDs(113 downto 88);--IDEXs(169 downto 164) & IDEXs(163 downto 138);--32 bit
	
	-- Incrementer increases input from PC with 1 bit, since the MIPS processor will be
	-- addressing by words
	Addressincrementer: adder port map(
		x => pc_output,
		y => "00000000000000000000000000000010",
		R => incremented
	);
	
	
	-- ADRESSADDER is the second adder, which is used for calculation new PC based on branching
	ADDRESSADDER: adder port map(
		X	=>IFIDs(31 downto 0),
		Y	=>Signextended(30 downto 0)&'0',--must do this because of instructionsize with 64 bit and 32-bits dataalignment
		R	=> BranchAdder
	);
	
--		PREDICTOR_BUFF: predictorbuffer
--	port map(
--			CLK 	=>clk,			
--			RESET		=>reset,				
--			RW			=>buffer_write,			
--			RS_ADDR 		=>pc_output(4 downto 0),
--			RT_ADDR		=>IFIDs(69 downto 65),
--			RD_ADDR 		=>IFIDs(69 downto 65),
--			WRITE_DATA	=>state&BranchAdder(15 downto 0), --look on this
		--	RS				=>stateread,
	--		RT 			=>stateread2
--	);
	
	--send stateread gjennom IFID og f� stateread2 ut
	BRANCH_TARGET_BUFFER: predictorbuffer
	   -- generic (N :NATURAL :=15; M:NATURAL:=32; K:NATURAL:=4);
	port map(
			CLK 			=>clk,				
			RESET			=>reset,				
			RW				=>shift_register_write,		
			Read_address=>pc_output(4 downto 0), 
			Write_address=>IFIDs(37 downto 33),
			WRITE_DATA	=>BranchAdder(15 downto 0),
			Data_out		=>prediction_address
	);
	
	
		BRANCH_PREDICTION_BUFFER: predictorbuffer
	   generic map (N =>2, M=>32, K=>4)
	port map(
			CLK 			=>clk,				
			RESET			=>reset,				
			RW				=>shift_register_write,		
			Read_address=>global_prediction_out&pc_output(2 downto 0), --extend this shit
			Write_address=>global_prediction_out&IFIDs(35 downto 33),
			WRITE_DATA	=>state_writeback,
			Data_out		=>stateread
	);
	
		global_prediction: shift_register 
   Port map( data_in =>branched1,--fix this, everything branches
           data_out =>global_prediction_out,--2 bits index + branch instruction address forms index for prediction register
           clock =>clk,
           reset=>reset,
           write_enable=>shift_register_write);
	
	ForwardmuxA: TriputMux 
    Port map( A =>IDEXs(105 downto 74),--readdataB
           B =>EXMEMs(68 downto 37),--aluresult
           C =>ChosenWriteData,
           R =>ForwardAout,
           control =>ctForwardA);
			  
			  	ForwardmuxB: TriputMux 
    Port map( A =>IDEXs(73 downto 42),--ReaddataA
           B =>EXMEMs(68 downto 37),--aluresult
           C =>ChosenWriteData,
           R =>ForwardBout,
           control =>ctForwardB);

			  --mux for chosing write register
			  --need to redefine the generic by mapping it to a new value.
	MUX1: simple_multiplexer generic map ( N=>5) port map(

			  a => IDEXs(9 downto 5),
           b => IDEXs(4 downto 0),
           control_signal => IDEXs(150),--regdest,
           output => ChosenWriteReg);
			  
			  --mux for chosing alu input
	MUX2: simple_multiplexer port map( 
			  a => ForwardBout,--IDEXs(73 downto 42),
           b => IDEXs(41 downto 10),
           control_signal => IDEXs(148),--alusrc,
           output => ChosenALUInput);
			--mux for chosing input from DMEM
	MUX3: QuadputMux port map(	 
           b =>MEMWBs(68 downto 37),--dmem_data_in, 
			  a => MEMWBs(36 downto 5),--ALU_Result,
			  c =>LO_out,--MEMWBs(102 downto 71),--Make the move instruction on the first processor
			  D=>HI_out,--change to be in right pipeline
           control => MEMWBs(70)&MEMWBs(108),--memtoreg,--memtoreg2,
           R => ChosenWriteData);

	-- First multiplexor. It is used to choose between regular incremented PC value or PC value based on branching
	MUX4: simple_multiplexer port map( 
		a => mux2out,
      b =>BranchAdder,-- EXMEMs(101 downto 70),
		control_signal => branch_ok,
      output => branchcalc
	);
		
		--outputs pc counter if branch is taken and revert back to the old address if not taken
			BranchTAKEN:	simple_multiplexer port map( 
		a =>incremented,
		b => incremented(31 downto 16)&prediction_address,--the calculated branch destination, maybe pc_output instead of incremented signal
      control_signal =>branch_Taken,--must fix

      output =>mux1out
	);
	--output the result address from branchprediction
				REVERT_PREDICTION:	simple_multiplexer port map( 
		a =>mux1out,
      b => IFIDs(31 downto 0),
      control_signal =>revert,
      output =>mux2out
	);
	-- Second multiplexor. It is used to choose between the result from the first multiplexor, or PC value based on jump-instruction
	MUX5: simple_multiplexer port map( 
		a =>branchcalc,
      b => Concat,
      control_signal =>chosen_OP(0),--EXMEMs(134)
      output =>FinalPCAddress
	);
	
		CONTROL_OUTPUT: simple_multiplexer generic map ( N=>10) port map( 
		a =>"0000000000",
      b => OPs,
      control_signal =>control_enable,--jump,
      output =>chosen_OP
	);
end Behavioral;
