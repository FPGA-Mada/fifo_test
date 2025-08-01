library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity packetization is
  generic (
       DATA_WIDTH : positive := 32;
       FIFO_DEPTH : positive := 64
  );
  Port (
        clk : in std_logic;
        rst : in std_logic;
        -- AXI Stream Slave
        s_valid : in std_logic;
        s_ready : out std_logic;
        s_data  : in std_logic_vector (DATA_WIDTH -1 downto 0);
        -- AXI Stream Master
        m_valid : out std_logic;
        m_ready : in std_logic;
        m_data  : out std_logic_vector (DATA_WIDTH -1 downto 0)        
   );
end packetization;

architecture Behavioral of packetization is

    -- FIFO output signals
    signal in_data_fifo  : std_logic_vector(DATA_WIDTH - 1 downto 0);      
    signal in_valid_fifo : std_logic;                                   
    signal in_ready_fifo : std_logic;  -- FIFO drives this, don't assign manually

    -- Internal output signals
    signal m_valid_sig : std_logic := '0';
    signal m_data_sig  : std_logic_vector(DATA_WIDTH -1 downto 0) := (others => '0');  

    -- State machine definition
    type state_t is (send_head, send_body, send_tail);
    signal state : state_t := send_head;     

    signal counter_data_send : integer range 0 to 4 := 0;  -- Changed range to 0-4

begin

    -- Output assignments
    m_valid <= m_valid_sig;
    m_data  <= m_data_sig;

    -- Packetizer Process
    packetizer_proc: process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                m_valid_sig        <= '0';
                m_data_sig         <= (others => '0');
                counter_data_send  <= 0;
                state              <= send_head;
                in_ready_fifo      <= '0';
            else
                -- Default assignments
                m_valid_sig <= '0';
                in_ready_fifo <= '0';

                case state is
                    when send_head =>
                        if in_valid_fifo = '1' and m_ready = '1' then
                            m_valid_sig <= '1';
                            m_data_sig  <= "01" & std_logic_vector(to_unsigned(999, 30));
                            state       <= send_body;
                        end if;

                    when send_body =>
                        if m_valid_sig = '0' then
                            if (in_valid_fifo = '1' and m_ready = '1' )then
                                m_data_sig  <= "00" & in_data_fifo(DATA_WIDTH - 3 downto 0);
                                m_valid_sig <= '1';
                                in_ready_fifo <= '1';  -- accept FIFO data
                            end if;
                        else
                            if m_ready = '1' then
                                m_valid_sig <= '0';
                                in_ready_fifo <= '0';
                                -- Check if this was the 5th body word (counter=4)
                                if counter_data_send = 4 then  -- Changed condition to 4
                                    counter_data_send <= 0;
                                    state <= send_tail;
                                else
                                    counter_data_send <= counter_data_send + 1;
                                end if;
                            else
                                m_valid_sig <= '1';
                                in_ready_fifo <= '0';
                            end if;
                        end if;

                    when send_tail =>
						if m_valid_sig = '0' then 
							if (m_ready = '1') then 
						       m_valid_sig <= '1';
                               m_data_sig  <= "11" & std_logic_vector(to_unsigned(999, 30));
							end if;
						else  
							if (m_ready = '1') then 
								m_valid_sig <= '0';
								state <= send_head;
							else 
								m_valid_sig <= '1';
							end if;
						end if;
   
                end case;
            end if;
        end if;
    end process packetizer_proc;

    -- FIFO Instantiation (unchanged)
    fifo_inst : entity work.olo_base_fifo_sync
    generic map(
        Width_g         => DATA_WIDTH,
        Depth_g         => FIFO_DEPTH,
        AlmFullOn_g     => false,
        AlmFullLevel_g  => 0,
        AlmEmptyOn_g    => false,
        AlmEmptyLevel_g => 0,
        RamStyle_g      => "auto",
        RamBehavior_g   => "RBW",
        ReadyRstState_g => '1'
    )
    port map (
        Clk           => clk,
        Rst           => rst,
        In_Data       => s_data,
        In_Valid      => s_valid,
        In_Ready      => s_ready,
        In_Level      => open,
        Out_Data      => in_data_fifo,
        Out_Valid     => in_valid_fifo,
        Out_Ready     => in_ready_fifo,
        Out_Level     => open,
        Full          => open,
        AlmFull       => open,
        Empty         => open,
        AlmEmpty      => open
    );

end Behavioral;
