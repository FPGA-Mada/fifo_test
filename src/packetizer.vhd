packetizer_proc : process (clk)
begin
  if rising_edge(clk) then
    if rst = '1' then
      m_valid_sig        <= '0';
      m_data_sig         <= (others => '0');
      counter_data_send  <= 0;
      state              <= prefetch;
      in_ready_fifo      <= '0';
      prefetch_valid     <= '0';
    else
      -- Default signal behavior
      in_ready_fifo <= '0';

      -- Deassert m_valid if accepted
      if m_valid_sig = '1' and m_ready = '1' then
        m_valid_sig <= '0';
      end if;

      case state is

        -----------------------------------------
        -- Prefetch first FIFO word into buffer
        -----------------------------------------
        when prefetch =>
          if in_valid_fifo = '1' then
            in_ready_fifo <= '1';
            prefetch_data  <= in_data_fifo;
            prefetch_valid <= '1';
            state          <= send_head;
          end if;

        -----------------------------------------
        -- Send header only after prefetch
        -----------------------------------------
        when send_head =>
          if m_ready = '1' and prefetch_valid = '1' then
            m_data_sig  <= "01" & std_logic_vector(to_unsigned(999, 30));
            m_valid_sig <= '1';
            state       <= send_body;
          end if;

        -----------------------------------------
        -- Send body: first word from buffer, rest from FIFO
        -----------------------------------------
        when send_body =>
          if m_ready = '1' then
            if counter_data_send = 0 then
              -- Use prefetched data
              m_data_sig <= "00" & prefetch_data(DATA_WIDTH - 3 downto 0);
              prefetch_valid <= '0';
              m_valid_sig <= '1';
              counter_data_send <= counter_data_send + 1;
            elsif in_valid_fifo = '1' then
              in_ready_fifo <= '1';
              m_data_sig <= "00" & in_data_fifo(DATA_WIDTH - 3 downto 0);
              m_valid_sig <= '1';
              if counter_data_send = 4 then
                counter_data_send <= 0;
                state <= send_tail;
              else
                counter_data_send <= counter_data_send + 1;
              end if;
            end if;
          end if;

        -----------------------------------------
        -- Send tail
        -----------------------------------------
        when send_tail =>
          if m_ready = '1' then
            m_data_sig  <= "11" & std_logic_vector(to_unsigned(999, 30));
            m_valid_sig <= '1';
            state       <= prefetch;  -- restart
          end if;

      end case;
    end if;
  end if;
end process;
