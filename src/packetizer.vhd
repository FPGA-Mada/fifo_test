library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity packetization is
  generic (
    DATA_WIDTH     : positive := 32;  -- Data width, must be >= 2
    FIFO_DEPTH     : positive := 64;  -- FIFO depth
    PACKET_LENGTH  : natural  := 5;   -- Number of body words per packet
    SPECIAL_PAYLOAD: natural  := 999  -- Payload for header/tail
  );
  Port (
    clk     : in  std_logic;
    rst     : in  std_logic;
    -- AXI Stream Slave interface
    s_valid : in  std_logic;
    s_ready : out std_logic;
    s_data  : in  std_logic_vector (DATA_WIDTH - 1 downto 0);
    -- AXI Stream Master interface
    m_valid : out std_logic;
    m_ready : in  std_logic;
    m_data  : out std_logic_vector (DATA_WIDTH - 1 downto 0)
  );
end packetization;

architecture Behavioral of packetization is

  -- Packet prefix encoding constants
  constant HEAD_P : std_logic_vector (1 downto 0) := "01";
  constant BODY_P : std_logic_vector (1 downto 0) := "00";
  constant TAIL_P : std_logic_vector (1 downto 0) := "11";

  constant PAYLOAD_WIDTH : natural := DATA_WIDTH - 2;

  constant SPECIAL_DATA : std_logic_vector(PAYLOAD_WIDTH - 1 downto 0) := 
    std_logic_vector(to_unsigned(SPECIAL_PAYLOAD, PAYLOAD_WIDTH));

  -- State type
  type state_t is (SEND_HEAD, SEND_BODY, SEND_TAIL);

  -- Internal record to hold state and signals
  type TwoProcess_r is record
    counter : integer range 0 to PACKET_LENGTH;
    s_ready : std_logic;
    m_valid : std_logic;
    m_data  : std_logic_vector (DATA_WIDTH - 1 downto 0);
    state   : state_t;
  end record;

  constant RESET_R : TwoProcess_r := (
    counter => 0,
    s_ready => '0',
    m_valid => '0',
    m_data  => (others => '0'),
    state   => SEND_HEAD
  );

  signal r, r_next : TwoProcess_r;

  -- FIFO interface signals
  signal data_valid : std_logic;
  signal data_in    : std_logic_vector(DATA_WIDTH - 1 downto 0);

begin

  -- Output assignments
  m_valid <= r.m_valid;
  m_data  <= r.m_data;

  -- Sequential process
  p_seq : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        r <= RESET_R;
      else
        r <= r_next;
      end if;
    end if;
  end process p_seq;

  -- Combinational next-state logic
  p_comb : process(all)
    variable v : TwoProcess_r;
  begin
    v := r;
    v.s_ready := '0';

    -- Clear m_valid when downstream accepted data
    if (m_ready = '1' and r.m_valid = '1') then
      v.m_valid := '0';
    end if;

    case r.state is
      when SEND_HEAD =>
        v.counter := 0;  -- reset counter for packet body
        if (data_valid = '1' and m_ready = '1') then
          v.m_valid := '1';
          v.m_data  := HEAD_P & SPECIAL_DATA;
          v.state   := SEND_BODY;
        end if;

      when SEND_BODY =>
        if (data_valid = '1' and m_ready = '1') then
          v.m_valid := '1';
          v.m_data  := BODY_P & data_in(PAYLOAD_WIDTH - 1 downto 0);
          v.s_ready := '1'; -- acknowledge FIFO read

          if (r.counter = PACKET_LENGTH - 1) then
            v.counter := 0;
            v.state := SEND_TAIL;
          else
            v.counter := r.counter + 1;
          end if;
        end if;

      when SEND_TAIL =>
        if (m_ready = '1') then
          v.m_valid := '1';
          v.m_data  := TAIL_P & SPECIAL_DATA;
          v.state   := SEND_HEAD;
        end if;

      when others =>
        null; -- defensive programming, no other states expected
    end case;

    r_next <= v;
  end process p_comb;

  --------------------------------------------------------------------
  -- FIFO Instantiation
  --------------------------------------------------------------------
  fifo_inst : entity work.olo_base_fifo_sync
    generic map (
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
      Clk         => clk,
      Rst         => rst,
      In_Data     => s_data,
      In_Valid    => s_valid,
      In_Ready    => s_ready,
      In_Level    => open,
      Out_Data    => data_in,
      Out_Valid   => data_valid,
      Out_Ready   => r.s_ready,
      Out_Level   => open,
      Full        => open,
      AlmFull     => open,
      Empty       => open,
      AlmEmpty    => open
    );

  -- Assertion for DATA_WIDTH sanity
  assert DATA_WIDTH >= 2
    report "DATA_WIDTH must be at least 2 to accommodate prefix bits"
    severity FAILURE;

end Behavioral;
